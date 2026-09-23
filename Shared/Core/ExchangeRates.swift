import Foundation

private struct SingleRateResponse: Decodable, Sendable {
    let date: String
    let rate: Double
}

@MainActor
final class ExchangeRateStore: ObservableObject {
    @Published private(set) var ratesByDay: [String: Double] = [:] {
        didSet {
            lookup = nil
            calendarRates.removeAll(keepingCapacity: true)
        }
    }
    private var lookup: HistoricalRateLookup?
    private var calendarRates: [Date: Double?] = [:]
    private var calendarTimeZone = TimeZone.current.identifier
    @Published private(set) var latestDate: String?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSuccessfulCheck: Date?
    @Published private(set) var liveCheckFailed = false

    private let cacheKey = "Clockin.USDTRYRates.v1"
    private let updatedKey = "Clockin.USDTRYRatesUpdated.v1"
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            ratesByDay = decoded
            latestDate = decoded.keys.max()
        }
        lastSuccessfulCheck = UserDefaults.standard.object(forKey: updatedKey) as? Date
    }

    var latestRate: Double? {
        guard let latestDate else { return nil }
        return ratesByDay[latestDate]
    }

    func rate(on date: Date) -> Double? {
        let key = formatter.string(from: date)
        if lookup == nil { lookup = HistoricalRateLookup(rates: ratesByDay) }
        return lookup?.rate(on: key)
    }

    /// Grafikteki kutular yerel takvim gunune gore. Yerel gece yarisini
    /// oldugu gibi UTC'ye cevirmek, UTC'nin ilerisindeki saat dilimlerinde bir
    /// onceki gunun kurunu sormak demek: 12 Eylul 00:00 (UTC+3) aslinda
    /// 11 Eylul 21:00 UTC. Bu yuzden gunun ortasi sabitleniyor.
    nonisolated static func calendarRateDate(_ date: Date) -> Date {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = .current
        var parts = local.dateComponents([.year, .month, .day], from: date)
        parts.hour = 12
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        return utc.date(from: parts) ?? date
    }

    func rate(onCalendarDay date: Date) -> Double? {
        if calendarTimeZone != TimeZone.current.identifier {
            calendarRates.removeAll(keepingCapacity: true)
            calendarTimeZone = TimeZone.current.identifier
        }
        let day = Calendar.current.startOfDay(for: date)
        if let cached = calendarRates[day] { return cached }
        let result = rate(on: Self.calendarRateDate(day))
        calendarRates[day] = .some(result)
        return result
    }

    func refresh(sessionDates: [Date]) async {
        let requestedDays = Array(Set(sessionDates.map { formatter.string(from: $0) })).sorted()
        let missingDays = requestedDays.filter { ratesByDay[$0] == nil }
        let latestIsFresh = (UserDefaults.standard.object(forKey: updatedKey) as? Date)
            .map { Date().timeIntervalSince($0) < 3600 } ?? false
        if latestIsFresh, missingDays.isEmpty, !ratesByDay.isEmpty { return }
        isLoading = true
        defer { isLoading = false }

        var fetchedLatest = latestIsFresh
        liveCheckFailed = false
        if !latestIsFresh {
            if let latest = await Self.fetchRate(requestedDay: nil) {
                ratesByDay[latest.actualDay] = latest.rate
                fetchedLatest = true
                lastSuccessfulCheck = Date()
            } else if Task.isCancelled {
                // Iptal bir ag hatasi degil. Bu is `.task(id:)` icinde kosuyor
                // ve oturum sayisi her clock out veya ice aktarmada degistigi
                // icin iptal rutin bir olay; hata olarak raporlanmamali.
                return
            } else {
                liveCheckFailed = true
            }
        }

        // Only fetch days that actually contain earnings. Small concurrent
        // batches keep full-page imports quick without flooding the free API.
        for offset in stride(from: 0, to: missingDays.count, by: 6) {
            // Onbellek bostayken bu dongu yuzlerce gun icin onlarca tur doner;
            // iptal edildiginde devam etmesinin anlami yok.
            if Task.isCancelled { return }
            let batch = Array(missingDays[offset..<min(offset + 6, missingDays.count)])
            await withTaskGroup(of: (requestedDay: String, actualDay: String, rate: Double)?.self) { group in
                for day in batch {
                    group.addTask { await Self.fetchRate(requestedDay: day) }
                }
                for await result in group {
                    if let result {
                        ratesByDay[result.requestedDay] = result.rate
                        ratesByDay[result.actualDay] = result.rate
                    }
                }
            }
            persistCache()
        }
        if Task.isCancelled { return }
        latestDate = ratesByDay.keys.max()
        let stillMissing = requestedDays.contains { ratesByDay[$0] == nil }
        if ratesByDay.isEmpty {
            errorMessage = String(localized: "Exchange rate unavailable")
        } else if liveCheckFailed {
            errorMessage = String(localized: "Live check failed, showing cached rate")
        } else if stillMissing {
            errorMessage = String(localized: "Some historical rates are still updating")
        } else {
            errorMessage = nil
        }
        persistCache()
        if fetchedLatest {
            let checkedAt = lastSuccessfulCheck ?? (UserDefaults.standard.object(forKey: updatedKey) as? Date) ?? Date()
            UserDefaults.standard.set(checkedAt, forKey: updatedKey)
        }
    }

    private func persistCache() {
        if let encoded = try? JSONEncoder().encode(ratesByDay) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }

    private nonisolated static func fetchRate(requestedDay: String?) async -> (requestedDay: String, actualDay: String, rate: Double)? {
        var value = "https://api.frankfurter.dev/v2/rate/USD/TRY"
        if let requestedDay { value += "?date=\(requestedDay)" }
        guard let url = URL(string: value) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(SingleRateResponse.self, from: data)
            return (requestedDay ?? decoded.date, decoded.date, decoded.rate)
        } catch {
            return nil
        }
    }
}

struct HistoricalRateLookup {
    private let rates: [String: Double]
    private let days: [String]
    private var cached: [String: Double?] = [:]

    init(rates: [String: Double]) {
        self.rates = rates
        days = rates.keys.sorted()
    }

    mutating func rate(on day: String) -> Double? {
        if let result = cached[day] { return result }
        var lower = 0
        var upper = days.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if days[middle] <= day { lower = middle + 1 } else { upper = middle }
        }
        let result = lower > 0 ? rates[days[lower - 1]] : nil
        cached[day] = .some(result)
        return result
    }
}

import Foundation

@MainActor
final class ClockStore: ObservableObject {
    @Published private(set) var data: ClockinData {
        didSet {
            cachedSessions = nil
            cachedRateRules = nil
            cachedTotals = nil
            cachedByDay = nil
            cachedDailyDurations = nil
            cachedConflicts = nil
        }
    }
    @Published var statusMessage: String?

    private let fileURL: URL
    private let calendar = Calendar.autoupdatingCurrent
    private let backupDirectory: URL

    /// Siralanmis kopyalar. `data` her degistiginde bosaltilir; boylece
    /// her okumada yeniden siralama yapilmaz.
    private var cachedSessions: [WorkSession]?
    private var cachedConflicts: Set<UUID>?
    private var cachedRateRules: [RateRule]?
    /// Tamamlanmis oturumlarin toplamlari. Ekran saniyede bir yenileniyor ve
    /// bu degerler tek bir yenilemede alti kez isteniyordu; her biri butun
    /// oturumlari bastan tariyordu.
    private var cachedTotals: (duration: TimeInterval, earnings: Double)?
    /// Gun bazli toplamlar. Gunluk deger sormak icin butun oturumlari
    /// `isDate(_:inSameDayAs:)` ile suzmek gerekiyordu; takvim
    /// karsilastirmasi pahalidir ve oturum basina bir kez kosuyordu.
    private var cachedByDay: [Date: (duration: TimeInterval, earnings: Double)]?
    private var cachedDailyDurations: [Date: TimeInterval]?
    /// Yedek dizinini her sorguda taramamak icin.
    private var cachedBackupStats: (latest: Date?, count: Int)?
    private var lastAutomaticBackup: Date?

    /// Iki otomatik yedek arasindaki en kisa sure. Her kayitta yedek
    /// alindiginda 30 dosyalik gecmis birkac saati anca kapsiyordu.
    private static let automaticBackupInterval: TimeInterval = 86_400

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        self.backupDirectory = self.fileURL.deletingLastPathComponent().appending(path: "Backups", directoryHint: .isDirectory)
        var loadFailureMessage: String?
        var mustNotOverwrite = false
        if let content = try? Data(contentsOf: self.fileURL),
           let decoded = try? JSONDecoder().decode(ClockinData.self, from: content) {
            data = decoded
        } else {
            data = ClockinData()
            // Dosya hic yoksa ilk kurulumdur. Varsa ama okunamiyorsa, bos veriyle
            // devam etmeden once kopyasi kenara alinir: asagidaki ucret gecisi
            // hemen `save()` cagirip kullanicinin dosyasinin uzerine yaziyordu.
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                let stamp = Int(Date().timeIntervalSince1970 * 1000)
                let copy = self.fileURL.deletingLastPathComponent().appending(path: "clockin-unreadable-\(stamp).json")
                if (try? FileManager.default.copyItem(at: self.fileURL, to: copy)) != nil {
                    loadFailureMessage = "Your data could not be read. The original file was kept as \(copy.lastPathComponent). You can restore a backup from Settings."
                } else {
                    mustNotOverwrite = true
                    loadFailureMessage = "Your data could not be read and no safety copy could be made. Restore a backup from Settings before adding entries."
                }
            }
        }
        let needsRateMigration = data.rateRules == nil
        if needsRateMigration {
            let july2026 = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 1)) ?? .distantPast
            data.rateRules = [RateRule(effectiveFrom: july2026, hourlyRate: data.hourlyRate)]
        }
        // Kopya alinamadiysa okunamayan dosyanin uzerine hic yazilmaz.
        if needsRateMigration, !mustNotOverwrite { save() }
        else { createAutomaticBackupIfNeeded() }
        if let loadFailureMessage { statusMessage = loadFailureMessage }
    }

    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Clockin", directoryHint: .isDirectory).appending(path: "clockin.json")
    }

    var latestBackupDate: Date? { backupStats().latest }
    var backupCount: Int { backupStats().count }

    /// Dizin taramasi tek sefere iner; sonuc bir yedek olusturulana veya
    /// geri yuklenene kadar gecerli kalir.
    private func backupStats() -> (latest: Date?, count: Int) {
        if let cached = cachedBackupStats { return cached }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let latest = files.compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }.max()
        let stats = (latest: latest, count: files.count)
        cachedBackupStats = stats
        return stats
    }

    var running: RunningSession? { data.running }
    var hourlyRate: Double { data.hourlyRate }
    var currencyCode: String { data.currencyCode }
    var pinVisible: Bool { data.pinVisible }

    var sessions: [WorkSession] {
        if let cached = cachedSessions { return cached }
        let sorted = data.sessions.sorted { $0.start > $1.start }
        cachedSessions = sorted
        return sorted
    }

    /// Verilen araliga degen kayitlar. Elle giris ekrani bunu yazarken
    /// gosterir; kayit engellenmez, yalnizca gorunur kilinir.
    func overlappingSessions(start: Date, end: Date, excluding id: UUID? = nil) -> [WorkSession] {
        SessionOverlap.touching(start: start, end: end, in: sessions, excluding: id)
    }

    /// Baska bir kayitla cakisan her kaydin kimligi.
    ///
    /// Gecmis ekrani her ciziminde soruluyor, bu yuzden `data` degisene kadar
    /// saklanir; 600 kaydi her karede yeniden taramak gereksiz.
    var conflictingSessionIDs: Set<UUID> {
        if let cached = cachedConflicts { return cached }
        let found = SessionOverlap.conflicting(in: sessions)
        cachedConflicts = found
        return found
    }

    var rateRules: [RateRule] {
        if let cached = cachedRateRules { return cached }
        let sorted = (data.rateRules ?? []).sorted { $0.effectiveFrom < $1.effectiveFrom }
        cachedRateRules = sorted
        return sorted
    }
    var currentRateEffectiveFrom: Date? { effectiveRateRule(at: .now)?.effectiveFrom }

    func elapsed(at date: Date = .now) -> TimeInterval { data.running?.elapsed(at: date) ?? 0 }
    /// Calisan seans, kayda gectiginde olacagi gibi basladigi gunun ucretiyle
    /// kazanir. Onceden bugunun ucreti kullaniliyordu; ucret degisikligini
    /// asan bir seansin tutari clock out aninda birden degisiyordu.
    func currentEarnings(at date: Date = .now) -> Double {
        guard let running = data.running else { return 0 }
        return running.elapsed(at: date) / 3600 * currentRate(at: date)
    }

    /// Su an kazanilan saatlik ucret: calisan seans varsa onun basladigi
    /// gunun ucreti, yoksa bugunun. Saniyelik hiz gostergeleri bunu kullanir
    /// ki gosterilen hiz kazancin gercekten arttigi hizla ayni olsun.
    func currentRate(at date: Date = .now) -> Double {
        effectiveRate(at: data.running?.start ?? date, fallback: hourlyRate)
    }

    /// Her oturum icin cagrilir; ara dizi ayirmamak icin tek gecisde tarar.
    /// `max(by:)` gibi esitlikte ilk kurali korur.
    func effectiveRate(at date: Date, fallback: Double) -> Double {
        effectiveRateRule(at: date)?.hourlyRate ?? fallback
    }

    /// The schedule label and earnings must select the same rule, including
    /// legacy files containing multiple rules with the same start date.
    func effectiveRateRule(at date: Date) -> RateRule? {
        var best: RateRule?
        for rule in rateRules where rule.applies(to: date, calendar: calendar) {
            if let current = best, rule.effectiveFrom <= current.effectiveFrom { continue }
            best = rule
        }
        return best
    }

    func earnings(for session: WorkSession) -> Double {
        session.duration / 3600 * effectiveRate(at: session.start, fallback: session.hourlyRate)
    }

    func clockIn(elapsed: TimeInterval = 0, note: String = "", at date: Date = .now) {
        guard data.running == nil else { return }
        guard let safeElapsed = SessionDuration.clockInElapsed(elapsed),
              SessionDuration.isValidDate(date) else {
            statusMessage = "Invalid elapsed time or date."
            return
        }
        let running = RunningSession(
            start: date.addingTimeInterval(-safeElapsed),
            accumulated: safeElapsed,
            resumedAt: date,
            note: note
        )
        guard running.hasValidDuration(at: date) else {
            statusMessage = "Invalid elapsed time or date."
            return
        }
        data.running = running
        save()
    }

    func cancelRunning() {
        guard data.running != nil else { return }
        data.running = nil
        save()
        statusMessage = "Active session cancelled. No earnings were added."
    }

    func pause(at date: Date = .now) {
        guard var running = data.running, running.resumedAt != nil else { return }
        guard running.hasValidDuration(at: date) else {
            statusMessage = "Invalid elapsed time or date."
            return
        }
        running.accumulated = running.elapsed(at: date)
        running.resumedAt = nil
        data.running = running
        save()
    }

    func resume(at date: Date = .now) {
        guard var running = data.running, running.resumedAt == nil else { return }
        running.resumedAt = date
        guard running.hasValidDuration(at: date) else {
            statusMessage = "Invalid elapsed time or date."
            return
        }
        data.running = running
        save()
    }

    @discardableResult
    func clockOut(at date: Date = .now) -> WorkSession? {
        guard let running = data.running else { return nil }
        guard running.hasValidDuration(at: date), date >= running.start else {
            statusMessage = "Invalid elapsed time or date."
            return nil
        }
        let session = WorkSession(
            id: UUID(), start: running.start, end: date, duration: running.elapsed(at: date),
            note: running.note, hourlyRate: hourlyRate, source: "Clockin"
        )
        data.sessions.append(session)
        data.running = nil
        save()
        return session
    }

    /// Tamamlanmis bir oturumu elle ekler.
    ///
    /// Kaynak "Clockin" olarak yazilir: elle girilen sure de bir tahmindir ve
    /// sonradan gelen resmi CSV kaydinin onu duzeltebilmesi gerekir. Eslesme
    /// yalnizca bu kaynagi tasiyan kayitlara bakiyor.
    @discardableResult
    func addManualSession(start: Date, end: Date, note: String = "") -> Bool {
        guard end > start else {
            statusMessage = "End time must be after the start time."
            return false
        }
        let session = WorkSession(
            id: UUID(), start: start, end: end, duration: end.timeIntervalSince(start),
            note: note, hourlyRate: hourlyRate, source: "Clockin"
        )
        guard session.hasValidDuration else {
            statusMessage = "Invalid session duration or dates."
            return false
        }
        let key = Self.deduplicationKey(session)
        guard !data.sessions.contains(where: { Self.deduplicationKey($0) == key }) else {
            statusMessage = "An entry with these exact times already exists."
            return false
        }
        // Yazilamazsa kayit bellekte de kalmamali: ekranda gorunup diskte
        // olmayan bir kayit uygulama kapaninca sessizce kaybolur.
        let previous = data
        data.sessions.append(session)
        guard save() else { data = previous; return false }
        statusMessage = "Entry added."
        return true
    }

    func updateRate(_ value: Double) {
        guard value >= 0, value.isFinite else { return }
        data.hourlyRate = value
        if let index = data.rateRules?.indices
            .filter({ data.rateRules![$0].applies(to: Date(), calendar: calendar) })
            .max(by: { data.rateRules![$0].effectiveFrom < data.rateRules![$1].effectiveFrom }) {
            data.rateRules?[index].hourlyRate = value
        }
        save()
    }

    func addRateRule(effectiveFrom: Date, effectiveUntil: Date? = nil, hourlyRate: Double) {
        guard hourlyRate >= 0, hourlyRate.isFinite else { return }
        let day = calendar.startOfDay(for: effectiveFrom)
        let end = effectiveUntil.map { calendar.startOfDay(for: $0) }
        guard end == nil || end! >= day else {
            statusMessage = "Rate period end must be on or after its start."
            return
        }
        guard !(data.rateRules ?? []).contains(where: { calendar.isDate($0.effectiveFrom, inSameDayAs: day) }) else {
            statusMessage = "A rate already starts on this day. Edit that rate instead."
            return
        }
        guard !overlapsRatePeriod(start: day, end: end, excluding: nil) else {
            statusMessage = "Rate period overlaps an existing period."
            return
        }
        data.rateRules = (data.rateRules ?? []) + [RateRule(effectiveFrom: day, effectiveUntil: end, hourlyRate: hourlyRate)]
        syncCurrentRate()
        save()
    }

    func updateRateRule(id: UUID, effectiveFrom: Date, effectiveUntil: Date? = nil, hourlyRate: Double) {
        guard hourlyRate >= 0, hourlyRate.isFinite,
              let index = data.rateRules?.firstIndex(where: { $0.id == id }) else { return }
        let day = calendar.startOfDay(for: effectiveFrom)
        let end = effectiveUntil.map { calendar.startOfDay(for: $0) }
        guard end == nil || end! >= day else {
            statusMessage = "Rate period end must be on or after its start."
            return
        }
        guard !(data.rateRules ?? []).contains(where: { $0.id != id && calendar.isDate($0.effectiveFrom, inSameDayAs: day) }) else {
            statusMessage = "A rate already starts on this day. Edit that rate instead."
            return
        }
        guard !overlapsRatePeriod(start: day, end: end, excluding: id) else {
            statusMessage = "Rate period overlaps an existing period."
            return
        }
        data.rateRules?[index].effectiveFrom = day
        data.rateRules?[index].effectiveUntil = end
        data.rateRules?[index].hourlyRate = hourlyRate
        syncCurrentRate()
        save()
    }

    func deleteRateRule(id: UUID) {
        guard (data.rateRules?.count ?? 0) > 1 else { return }
        data.rateRules?.removeAll { $0.id == id }
        syncCurrentRate()
        save()
    }

    private func syncCurrentRate() {
        if let current = effectiveRateRule(at: .now) {
            data.hourlyRate = current.hourlyRate
        }
    }

    private func overlapsRatePeriod(start: Date, end: Date?, excluding id: UUID?) -> Bool {
        guard let newEnd = end else { return false }
        return (data.rateRules ?? []).contains { rule in
            guard rule.id != id else { return false }
            guard let oldEnd = rule.effectiveUntil else { return false }
            return start <= oldEnd && rule.effectiveFrom <= newEnd
        }
    }

    func updateCurrency(_ value: String) {
        data.currencyCode = value
        save()
    }

    func setPinned(_ value: Bool) {
        data.pinVisible = value
        save()
        // iPhone'da sabitlenmis pencere yok. Deger yine de yaziliyor ki ayni
        // veri dosyasi Mac'e donunce ayar kaybolmasin.
    }

    func importCSV(from url: URL) {
        do {
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let imported = try CSVImporter.parse(data: Data(contentsOf: url), hourlyRate: hourlyRate)
            importSessions(imported)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func importPastedText(_ text: String) {
        do {
            let imported = try PastedTextImporter.parse(text, hourlyRate: hourlyRate)
            importSessions(imported)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func exportBackup(to url: URL) {
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: .atomic)
            statusMessage = "Backup exported."
        } catch {
            statusMessage = "Could not export backup: \(error.localizedDescription)"
        }
    }

    /// Dosyadan geri yukleme. Ayarlardaki "Restore from backup" bunu cagirir.
    func importBackup(from url: URL) {
        restoreBackup(from: url)
    }

    func restoreLatestBackup() {
        guard let latest = Self.readBackups(in: backupDirectory).first else {
            statusMessage = "No automatic backup exists yet."
            return
        }
        restoreBackup(from: latest.url)
    }

    /// Butun veriyi bir yedekle degistirir; once mevcut veriyi kenara koyar.
    ///
    /// Eskiden dogrudan uzerine yaziyordu. Otomatik yedek gunde bir alindigi
    /// icin yanlislikla geri yukleyen biri son yedekten sonraki butun
    /// kayitlarini geri donussuz kaybediyordu; uyari da "geri alinamaz"
    /// diyordu. Simdi geri yukleme de bir yedektir: listeden "before restore"
    /// kopyasi secilerek geri alinir.
    ///
    /// Kopya alinamazsa geri yukleme hic yapilmaz. Veriyi korumadan
    /// degistirmektense hicbir sey yapmamak dogru.
    @discardableResult
    func restoreBackup(from url: URL) -> Bool {
        let decoded: ClockinData
        do {
            decoded = try JSONDecoder().decode(ClockinData.self, from: Data(contentsOf: url))
        } catch {
            statusMessage = "Could not restore backup: \(error.localizedDescription)"
            return false
        }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
                let stamp = Int(Date().timeIntervalSince1970 * 1000)
                let copy = backupDirectory.appending(path: "\(Self.safetyCopyPrefix)\(stamp)-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: fileURL, to: copy)
                // Kopya dosyanin eski degistirme tarihini tasir; listede en ustte,
                // "simdi alinmis" olarak gorunmesi icin tarihi guncellenir.
                try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: copy.path)
                cachedBackupStats = nil
            } catch {
                statusMessage = "Nothing was restored: your current data could not be kept aside first (\(error.localizedDescription))."
                return false
            }
        }
        let previous = data
        data = decoded
        guard save() else { data = previous; return false }
        cachedBackupStats = nil
        statusMessage = "Backup restored. Your previous data was kept as a backup."
        return true
    }

    nonisolated static let safetyCopyPrefix = "clockin-before-restore-"

    var backupDirectoryURL: URL { backupDirectory }

    /// Klasordeki yedekler, en yenisi basta. Her dosya acilip sayilir; ana
    /// is parcacigini tutmamak icin ekran bunu arka planda cagirir.
    nonisolated static func readBackups(in directory: URL) -> [AutomaticBackup] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]
        )) ?? []
        let decoder = JSONDecoder()
        return files.filter { $0.pathExtension == "json" }.compactMap { url -> AutomaticBackup? in
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            // Okunamayan bir yedek listede yine gorunur ama geri yuklenemez;
            // gizlemek, kullanicinin neden eksik oldugunu anlamamasina yol acar.
            guard let content = try? Data(contentsOf: url),
                  let decoded = try? decoder.decode(ClockinData.self, from: content) else {
                return AutomaticBackup(url: url, date: date, sessionCount: nil, totalDuration: 0,
                                       isSafetyCopy: url.lastPathComponent.hasPrefix(safetyCopyPrefix))
            }
            return AutomaticBackup(url: url, date: date, sessionCount: decoded.sessions.count,
                                   totalDuration: decoded.sessions.reduce(0) { $0 + $1.duration },
                                   isSafetyCopy: url.lastPathComponent.hasPrefix(safetyCopyPrefix))
        }
        .sorted { $0.date > $1.date }
    }

    func previewPastedText(_ text: String) -> [WorkSession] {
        (try? PastedTextImporter.parse(text, hourlyRate: hourlyRate)) ?? []
    }

    func compareImportedSessions(_ imported: [WorkSession],
                                 scope: ImportScope = .daysInFile) -> ImportComparisonSummary {
        var seenKeys = Set<String>()
        // Onizleme ile asil aktarma ayni sonucu vermeli: ikisi de dosya icindeki
        // ayni isin ikinci yazimini atlar.
        var seenSessions: [WorkSession] = []
        var claimedMatches = Set<Int>()
        var indexByKey: [String: Int] = [:]
        for (index, session) in data.sessions.enumerated() {
            let key = Self.deduplicationKey(session)
            if indexByKey[key] == nil { indexByKey[key] = index }
        }
        // Dosyanin dokundugu kayitlar artikta sayilmasin: bir satirla eslesen
        // ya da zaten ayni olan bir kayit zaten dosyanin karsiligidir.
        var touched = Set<Int>()
        let items = imported.map { session -> ImportComparisonItem in
            let key = Self.deduplicationKey(session)
            if let duplicateIndex = indexByKey[key] {
                touched.insert(duplicateIndex)
                return ImportComparisonItem(session: session, kind: .duplicate)
            }
            if seenKeys.contains(key) || seenSessions.contains(where: { sharedTime($0, session) != nil }) {
                return ImportComparisonItem(session: session, kind: .duplicate)
            }
            seenKeys.insert(key)
            seenSessions.append(session)
            if session.source != "Clockin", let index = findMatch(for: session, excluding: claimedMatches) {
                claimedMatches.insert(index)
                touched.insert(index)
                return ImportComparisonItem(session: session, kind: .matched, localMatch: data.sessions[index])
            }
            return ImportComparisonItem(session: session, kind: .new)
        }
        return ImportComparisonSummary(items: items,
                                       leftovers: leftoverSessions(imported, scope: scope, touched: touched))
    }

    /// Kapsama giren, dosyanin dokunmadigi kendi sayac kayitlarin.
    ///
    /// Yalnizca `source == "Clockin"` olanlar: daha once baska bir dosyadan
    /// gelmis kayitlar kullanicinin elle tuttugu kayit degil, onlari bir dokum
    /// eksik diye silmek veri kaybi olur.
    private func leftoverSessions(_ imported: [WorkSession],
                                  scope: ImportScope, touched: Set<Int>) -> [WorkSession] {
        let days = Set(imported.map { calendar.startOfDay(for: $0.start) })
        guard let first = days.min(), let last = days.max() else { return [] }
        // `data.sessions` yazilma sirasinda duruyor; liste gun gun okunacagi
        // icin tarihe gore siralanir.
        return data.sessions.enumerated().compactMap { index, session -> WorkSession? in
            guard !touched.contains(index),
                  session.source == "Clockin", session.matchedExternalSource == nil else { return nil }
            let day = calendar.startOfDay(for: session.start)
            switch scope {
            case .daysInFile: return days.contains(day) ? session : nil
            case .wholeRange: return (day >= first && day <= last) ? session : nil
            }
        }
        .sorted { $0.start > $1.start }
    }

    /// Var olan bir kaydin saatlerini ve notunu degistirir.
    ///
    /// Yanlis girilen bir kaydi duzeltmek icin tek yol silip yeniden eklemekti;
    /// o da kaydin kimligini ve ice aktarma isaretlerini kaybettiriyordu.
    @discardableResult
    func updateSession(id: UUID, start: Date, end: Date, note: String) -> Bool {
        let previous = data
        guard SessionDuration.isValidDate(start), SessionDuration.isValidDate(end) else {
            statusMessage = "Invalid session dates."
            return false
        }
        guard end > start else {
            statusMessage = "End time must be after the start time."
            return false
        }
        guard let index = data.sessions.firstIndex(where: { $0.id == id }) else { return false }
        let old = data.sessions[index]
        // Calisilan sure her zaman bitis - baslangic degil: duraklatilan seansta
        // mola, ice aktarilan kayitta dis kaynagin suresi fark yaratir. Yalnizca
        // not degistiyse sure aynen kalir; saatler degistiyse bu fark korunur.
        if start != old.start || end != old.end {
            let worked = EntryTimes.workedDuration(start: start, end: end, replacing: old)
            guard worked > 0 else {
                statusMessage = "The new times are shorter than this entry's break."
                return false
            }
            guard SessionDuration.isValid(worked) else {
                statusMessage = "Invalid session duration."
                return false
            }
            data.sessions[index].duration = worked
        }
        data.sessions[index].start = start
        data.sessions[index].end = end
        data.sessions[index].note = note
        guard save() else { data = previous; return false }
        statusMessage = "Entry updated."
        return true
    }

    func deleteSession(id: UUID) {
        guard let index = data.sessions.firstIndex(where: { $0.id == id }) else { return }
        let previous = data
        data.sessions.remove(at: index)
        guard save() else { data = previous; return }
        statusMessage = "Session deleted."
    }

    /// - Parameter removing: silinecek kendi kayitlarinin kimlikleri. Ice
    ///   aktarma kendiliginden hicbir sey silmez; bu kume yalnizca kullanici
    ///   onizlemede acikca sectiginde dolar.
    func importSessions(_ imported: [WorkSession], removing: Set<UUID> = []) {
        guard imported.allSatisfy(\.hasValidDuration) else {
            statusMessage = "Invalid session duration or dates."
            return
        }
        let previous = data
        // Silme once yapilir: aksi halde yeni kayitlar eklendikten sonra
        // indeksler kayiyor ve eslesme aramasi silinecek kayitlari da goruyor.
        var removed = 0
        if !removing.isEmpty {
            let before = data.sessions.count
            data.sessions.removeAll { removing.contains($0.id) }
            removed = before - data.sessions.count
        }
        var fresh: [WorkSession] = []
        var freshKeys = Set<String>()
        var claimedMatches = Set<Int>()
        var acceptedRows: [WorkSession] = []
        var matched = 0
        var corrected = 0
        // Anahtarlar bir kez cikarilir. Onceden her ice aktarilan kayit icin
        // butun oturumlar taranip her karsilastirmada yeni string uretiliyordu.
        var indexByKey: [String: Int] = [:]
        for (index, session) in data.sessions.enumerated() {
            let key = Self.deduplicationKey(session)
            if indexByKey[key] == nil { indexByKey[key] = index }
        }
        for session in imported {
            let key = Self.deduplicationKey(session)
            if let duplicateIndex = indexByKey[key] {
                if session.source != "Clockin", data.sessions[duplicateIndex].source == "Clockin",
                   data.sessions[duplicateIndex].matchedExternalSource == nil {
                    data.sessions[duplicateIndex].matchedExternalSource = session.source
                    matched += 1
                }
                continue
            }
            if freshKeys.contains(key) {
                continue
            }
            // Ayni dosyada ayni isin iki yazimi olabiliyor: birebir ayni
            // satirlar zaten ataniyordu, birkac dakika farkli bitisler
            // atlanmiyordu. Ikisi de dogru olamayacagi icin ilki kalir. Ilk
            // yazim bir kaydi duzeltmis de olabilir; o yuzden yalnizca yeni
            // eklenenlere degil, bu aktarmada kabul edilen butun satirlara
            // bakilir. Onizleme de ayni sirayla karar verir.
            if acceptedRows.contains(where: { sharedTime($0, session) != nil }) {
                continue
            }
            acceptedRows.append(session)
            freshKeys.insert(key)
            if session.source != "Clockin", let index = findMatch(for: session, excluding: claimedMatches) {
                claimedMatches.insert(index)
                // Dis kayit dogruluk kaynagidir. Sayacin yaklasik degerleri
                // resmi olanlarla degistirilir; kayit cogaltilmaz.
                if data.sessions[index].note.isEmpty { data.sessions[index].note = session.note }
                data.sessions[index].start = session.start
                data.sessions[index].end = session.end
                data.sessions[index].duration = session.duration
                data.sessions[index].matchedExternalSource = session.source
                corrected += 1
            } else {
                var authoritative = session
                // Ice aktarilan kayitlar isaretli kalir; boylece sonraki bir
                // dokum ayni satiri ikinci kez eklemek yerine gunceller.
                authoritative.matchedExternalSource = session.source
                fresh.append(authoritative)
            }
        }
        data.sessions.append(contentsOf: fresh)
        guard save() else { data = previous; return }
        if fresh.isEmpty, matched == 0, corrected == 0, removed == 0 {
            statusMessage = "All entries were already imported."
        } else {
            var parts = ["Imported \(fresh.count)"]
            if corrected > 0 { parts.append("corrected \(corrected) Clockin \(corrected == 1 ? "entry" : "entries")") }
            if matched > 0 { parts.append("matched \(matched)") }
            if removed > 0 { parts.append("deleted \(removed) Clockin \(removed == 1 ? "entry" : "entries")") }
            statusMessage = parts.joined(separator: ", ") + "."
        }
    }

    /// Iki kaydin ayni isi tarif ettigini kabul etmek icin gereken en az
    /// ortusme orani (kisa olanin yuzdesi).
    private static let matchOverlapRatio = 0.5

    /// Bir dis kayda karsilik gelen yerel kaydi bulur.
    ///
    /// Eskiden baslangic/bitis 90 saniye, sure 120 saniye icinde olmak
    /// zorundaydi. Elle baslatilip durdurulan bir sayac icin bu esik
    /// gercekci degil: birkac dakikalik kayma eslesmeyi kirar ve ayni is
    /// iki kez kaydedilir. Bunun yerine zaman ortusmesine bakilir; boylece
    /// durdurmayi unutup uzayan seanslar da dogru kayitla eslesir.
    ///
    /// Ilk uyan degil, en cok ortusen kayit secilir.
    ///
    /// Ayni kaynaktan gelmis yerel kayitlar da aranir. Once yalnizca sayac
    /// kayitlari ve `matchedExternalSource` tasiyanlar bakiliyordu; isareti
    /// olmayan, daha eski bir surumun ice aktardigi bir kayit hicbir satirla
    /// eslesemiyordu. Dokum birkac dakika duzeltilmis bitisle yeniden
    /// alindiginda ayni is ikinci kez ekleniyor ve gun iki katina cikiyordu.
    ///
    /// Bu aktarmada baska bir satirin duzelttigi kayitlar `excluding` ile
    /// atlanir ve siradaki en iyi kayit aranir. Onceden en iyi eslesme
    /// alinmissa onizleme satiri yeni sayiyor, aktarma ise ya satiri atliyor
    /// ya da duzeltilmis kayit artik ortusmedigi icin ikinci en iyi kayda
    /// yaziyordu; ekranda gorulen ile yapilan farkliydi.
    private func findMatch(for external: WorkSession, excluding claimed: Set<Int> = []) -> Int? {
        var best: (index: Int, overlap: TimeInterval)?
        for (index, local) in data.sessions.enumerated() where !claimed.contains(index) {
            guard local.source == "Clockin" || local.matchedExternalSource != nil
                    || local.source == external.source else { continue }
            guard let overlap = sharedTime(local, external) else { continue }
            if best == nil || overlap > best!.overlap { best = (index, overlap) }
        }
        return best?.index
    }

    /// Iki kaydin ayni isi tarif ettigi kabul ediliyorsa ortusen sure.
    ///
    /// Ayni gunde olmalari ve kisa olanin en az yarisinin ortusmesi gerekir.
    /// Ayni anda iki is yapilamayacagi icin bu kadar ortusen iki kayit
    /// pratikte ayni isin iki yazimidir.
    private func sharedTime(_ a: WorkSession, _ b: WorkSession) -> TimeInterval? {
        guard calendar.isDate(a.start, inSameDayAs: b.start) else { return nil }
        let overlap = min(a.end, b.end).timeIntervalSince(max(a.start, b.start))
        let shorter = min(a.duration, b.duration)
        guard overlap > 0, shorter > 0, overlap >= shorter * Self.matchOverlapRatio else { return nil }
        return overlap
    }

    /// Calisan seans bugune sayilmiyorsa, yazildigi gun.
    ///
    /// Gece yarisini asan bir oturum bastan sona basladigi gune ait sayilir.
    /// Dogru olan bu: gece vardiyasi basladigi gunun isidir. Ama 02:00'de
    /// "3 saat calistim" deyip sayaci baslatan biri "Today 0m" gorunce
    /// uygulama bozulmus saniyor. Ekranlar bu gunu yazip sebebini soylesin.
    func runningDayIfNotToday(at date: Date = .now) -> Date? {
        guard let running = data.running,
              !calendar.isDate(running.start, inSameDayAs: date) else { return nil }
        return calendar.startOfDay(for: running.start)
    }

    func todayDuration(at date: Date = .now) -> TimeInterval {
        duration(on: date)
    }

    func todayEarnings(at date: Date = .now) -> Double {
        earnings(on: date)
    }

    /// Gun -> (sure, kazanc). Tek gecisde kurulur, `data` degisene kadar durur.
    private func totalsByDay() -> [Date: (duration: TimeInterval, earnings: Double)] {
        if let cached = cachedByDay { return cached }
        var result: [Date: (duration: TimeInterval, earnings: Double)] = [:]
        for session in data.sessions {
            let day = calendar.startOfDay(for: session.start)
            let old = result[day] ?? (0, 0)
            result[day] = (old.duration + session.duration, old.earnings + earnings(for: session))
        }
        cachedByDay = result
        return result
    }

    /// Gun -> tamamlanmis sure. Calisan seans dahil degildir; onu ekleyecek
    /// olan cagiran taraftir, cunku degeri her saniye degisir.
    ///
    /// Ekranlar bunu kendileri kuruyordu ve tek bir yenilemede yirmiden fazla
    /// kez; her seferinde butun oturumlar taranip her biri icin takvim islemi
    /// yapiliyordu.
    var dailyDurations: [Date: TimeInterval] {
        if let cached = cachedDailyDurations { return cached }
        let result = totalsByDay().mapValues(\.duration)
        cachedDailyDurations = result
        return result
    }

    func duration(on date: Date) -> TimeInterval {
        let day = calendar.startOfDay(for: date)
        let completed = totalsByDay()[day]?.duration ?? 0
        let active = data.running.map { calendar.isDate($0.start, inSameDayAs: day) ? $0.elapsed(at: .now) : 0 } ?? 0
        return completed + active
    }

    func earnings(on date: Date) -> Double {
        let day = calendar.startOfDay(for: date)
        let completed = totalsByDay()[day]?.earnings ?? 0
        let active = data.running.map { calendar.isDate($0.start, inSameDayAs: day) ? currentEarnings(at: .now) : 0 } ?? 0
        return completed + active
    }

    func monthEarnings(at date: Date = .now) -> Double {
        let completed = data.sessions.filter { calendar.isDate($0.start, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + earnings(for: $1) }
        let active = data.running.map { calendar.isDate($0.start, equalTo: date, toGranularity: .month) ? currentEarnings(at: date) : 0 } ?? 0
        return completed + active
    }

    func monthDuration(at date: Date = .now) -> TimeInterval {
        let completed = data.sessions.filter { calendar.isDate($0.start, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + $1.duration }
        let active = data.running.map { calendar.isDate($0.start, equalTo: date, toGranularity: .month) ? $0.elapsed(at: date) : 0 } ?? 0
        return completed + active
    }

    private func totals() -> (duration: TimeInterval, earnings: Double) {
        if let cached = cachedTotals { return cached }
        var duration: TimeInterval = 0
        var earned: Double = 0
        for session in data.sessions {
            duration += session.duration
            earned += earnings(for: session)
        }
        let result = (duration, earned)
        cachedTotals = result
        return result
    }

    var totalDuration: TimeInterval { totals().duration }
    var totalEarnings: Double { totals().earnings }
    func allDuration(at date: Date = .now) -> TimeInterval { totalDuration + elapsed(at: date) }
    func allEarnings(at date: Date = .now) -> Double { totalEarnings + currentEarnings(at: date) }

    private static func deduplicationKey(_ session: WorkSession) -> String {
        "\(Int(session.start.timeIntervalSince1970))|\(Int(session.end.timeIntervalSince1970))|\(Int(session.duration))"
    }

    /// Yazimin tutup tutmadigini doner.
    ///
    /// Once hatayi `statusMessage`'a yazip hicbir sey donmuyordu; cagiran hemen
    /// ardindan "Entry updated." yazip hatanin uzerini ortuyordu. Kullanici
    /// kaydedildi saniyor, disk eski halde kaliyordu. Mac'te ayni hata PR #9 ile
    /// kapandi, bu kopyaya tasinmamisti.
    @discardableResult
    private func save() -> Bool {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            createAutomaticBackupIfNeeded()
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
            return true
        } catch {
            statusMessage = "Could not save: \(error.localizedDescription)"
            return false
        }
    }

    private func createAutomaticBackupIfNeeded() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let now = Date()
        // Ilk cagrida diskteki en yeni yedegi referans al, sonra bellekten yurut.
        if lastAutomaticBackup == nil { lastAutomaticBackup = latestBackupDate }
        if let last = lastAutomaticBackup, now.timeIntervalSince(last) < Self.automaticBackupInterval { return }
        do {
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            let stamp = Int(now.timeIntervalSince1970 * 1000)
            let destination = backupDirectory.appending(path: "clockin-\(stamp)-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: fileURL, to: destination)
            let backups = try FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
                .sorted {
                    let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return left > right
                }
            for old in backups.dropFirst(30) { try? FileManager.default.removeItem(at: old) }
            lastAutomaticBackup = now
            cachedBackupStats = nil
        } catch {
            // A failed backup must never block the primary save.
        }
    }
}

/// Yedek klasorundeki bir dosyanin ozeti.
struct AutomaticBackup: Identifiable, Sendable {
    let url: URL
    let date: Date
    /// `nil`: dosya okunamadi.
    let sessionCount: Int?
    let totalDuration: TimeInterval
    /// Bir geri yuklemeden hemen once alinan kopya.
    let isSafetyCopy: Bool

    var id: URL { url }
    var isReadable: Bool { sessionCount != nil }
}

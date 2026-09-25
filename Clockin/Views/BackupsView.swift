import SwiftUI

/// Otomatik yedekler ve geri yukleme.
///
/// Yedekler zaten aliniyordu ama uygulamada gorunmuyordu: geri donmek icin
/// dosyayi bulup elle secmek gerekiyordu. Mac'te yalnizca "en son yedegi geri
/// yukle" var; telefonda listeden secilebiliyor, cunku en son yedek hatayi
/// zaten iceriyor olabilir.
struct BackupsView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var backups: [AutomaticBackup]?
    @State private var pending: AutomaticBackup?
    @State private var message: String?
    @State private var restored = false

    var body: some View {
        NavigationStack {
            List {
                if let backups {
                    if backups.isEmpty {
                        ContentUnavailableView("No backups yet", systemImage: "clock.arrow.circlepath",
                            description: Text("A copy of your data is saved automatically once a day while you use Clockin."))
                    } else {
                        Section {
                            ForEach(backups) { backup in
                                row(backup)
                            }
                            .animation(.smooth, value: backups.map(\.id))
                        } footer: {
                            Text("Restoring keeps your current data as a backup first, so a restore can be undone from this list.")
                        }
                        .listRowBackground(palette.surface)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Automatic backups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let message {
                    Label(message, systemImage: restored ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(restored ? palette.accent : Color.orange)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.3), value: message)
            .hapticFeedback(.destructiveConfirmation, trigger: pending?.id) { _, new in new != nil }
            .task { await reload() }
            .celebrationBlocked(by: pending != nil)
            .confirmationDialog(pending.map(title) ?? "", isPresented: Binding(
                get: { pending != nil }, set: { if !$0 { pending = nil } }
            ), titleVisibility: .visible, presenting: pending) { backup in
                Button("Restore this backup", role: .destructive) { restore(backup) }
                Button("Cancel", role: .cancel) {}
            } message: { backup in
                Text("Your current \(store.sessions.count) entries are replaced with this backup's \(backup.sessionCount ?? 0). Your current data is kept as a backup first.")
            }
        }
    }

    private func row(_ backup: AutomaticBackup) -> some View {
        Button { if backup.isReadable { pending = backup } } label: {
            HStack(spacing: 12) {
                Image(systemName: backup.isSafetyCopy ? "arrow.uturn.backward.circle.fill" : "clock.arrow.circlepath")
                    .foregroundStyle(backup.isSafetyCopy ? .orange : palette.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(backup.date.formatted(.dateTime.locale(AppLanguage.formatLocale).weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                        .font(.subheadline.weight(.medium))
                    Text(detail(backup))
                        .font(.caption)
                        .foregroundStyle(backup.isReadable ? .secondary : Color.red)
                }
                Spacer()
                Text(backup.date.formatted(.relative(presentation: .named).locale(AppLanguage.formatLocale)))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!backup.isReadable)
        .accessibilityHint(backup.isReadable ? "Restores this backup after confirmation" : "")
    }

    private func detail(_ backup: AutomaticBackup) -> String {
        guard let count = backup.sessionCount else { return String(localized: "This file cannot be read", bundle: .app) }
        let summary = String(localized: "\(count) entries", bundle: .app) + " · " + DurationText.compact(backup.totalDuration)
        return backup.isSafetyCopy ? String(localized: "Before restore · \(summary)", bundle: .app) : summary
    }

    private func title(_ backup: AutomaticBackup) -> String {
        String(localized: "Restore the backup from \(backup.date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: AppLanguage.formatLocale)))?", bundle: .app)
    }

    private func restore(_ backup: AutomaticBackup) {
        restored = store.restoreBackup(from: backup.url)
        Haptics.play(restored ? .backupRestored : .validationFailed)
        // Ortak mesaj baska bir islemle degisebilir; bu geri yuklemenin sonucu tutulur.
        message = store.statusMessage
        Task { await reload() }
    }

    /// Her yedek acilip sayiliyor; otuz dosyayi ana is parcaciginda okumamak icin.
    private func reload() async {
        let directory = store.backupDirectoryURL
        backups = await Task.detached(priority: .userInitiated) {
            ClockStore.readBackups(in: directory)
        }.value
    }
}

import Foundation

/// Persists AppSettings as a single JSON file in Application Support (parity with the
/// Android DataStore JSON blob). Synchronous load/save — the payload is tiny.
final class ReminderStore {

    private let url: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("buzzlie_settings.json")
    }

    func load() -> AppSettings {
        guard let data = try? Data(contentsOf: url),
              let settings = try? decoder.decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    func save(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

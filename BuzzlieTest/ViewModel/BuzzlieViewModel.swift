import Foundation
import Combine
import CoreBluetooth

@MainActor
final class BuzzlieViewModel: ObservableObject {

    private let manager = BuzzlieBleManager()
    private let store = ReminderStore()
    private var cancellables = Set<AnyCancellable>()

    // Mirrored device state
    @Published private(set) var status: StatusFrame?
    @Published private(set) var battery: Int?
    @Published private(set) var connState: ConnState = .disconnected
    @Published private(set) var centralState: CBManagerState = .unknown

    // Scanning
    @Published private(set) var scanResults: [ScanDevice] = []
    @Published private(set) var scanning = false

    // Log (newest first, capped 250)
    @Published private(set) var log: [LogEntry] = []

    // Last encoded/sent draft (debug/preview)
    @Published private(set) var draft = ConfigDraft()

    // Local source of truth (the device config is write-only)
    @Published private(set) var settings = AppSettings()

    /// True once the current settings have been written to the connected device.
    @Published private(set) var configSynced = false

    /// Count of alarms imported from the bracelet on the last connection (one-time banner).
    @Published private(set) var importedFromDevice = 0

    private var pendingAutoConnect = false
    private var pushTask: Task<Void, Never>?

    init() {
        settings = pruneExpired(store.load())
        #if DEBUG
        seedPreviewIfRequested()
        #endif
        bind()
        startPruneLoop()
    }

    #if DEBUG
    /// In-memory sample data for UI screenshots (not persisted). Enabled with `-uiSeed`.
    private func seedPreviewIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-uiSeed") else { return }
        var medMatin = ReminderUi(); medMatin.label = "Médoc matin"; medMatin.mode = .ABSOLUTE
        medMatin.hour = 8; medMatin.minute = 0; medMatin.dayMask = ALL_DAYS
        var medSemaine = ReminderUi(); medSemaine.label = "Médoc midi"; medSemaine.mode = .ABSOLUTE
        medSemaine.hour = 12; medSemaine.minute = 30; medSemaine.dayMask = 0x1F
        var patch = ReminderUi(); patch.label = "Patch Cassie"; patch.mode = .RELATIVE
        patch.delayMinutes = 210; patch.anchorEpoch = Time.nowSeconds()
        settings.reminders = [medMatin, medSemaine, patch]
    }
    #endif

    private func bind() {
        manager.$status.assign(to: &$status)
        manager.$battery.assign(to: &$battery)
        manager.$centralState.assign(to: &$centralState)

        manager.events
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.addLog($0) }
            .store(in: &cancellables)

        manager.$connState
            .receive(on: RunLoop.main)
            .sink { [weak self] cs in
                guard let self else { return }
                self.connState = cs
                if cs == .ready { self.onConnected() } else { self.configSynced = false }
            }
            .store(in: &cancellables)
    }

    func dismissImportedBanner() { importedFromDevice = 0 }

    // MARK: - Prune expired one-shots while the app is open

    private func startPruneLoop() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard let self else { return }
                self.settings = self.pruneExpired(self.settings)
            }
        }
    }

    /// Prunes expired one-shots and persists if the list changed. No BLE push: those
    /// reminders are already excluded from the device config (toConfigDraft).
    private func pruneExpired(_ s: AppSettings) -> AppSettings {
        let kept = withoutExpired(s.reminders, Time.nowSeconds())
        if kept.count == s.reminders.count { return s }
        var pruned = s
        pruned.reminders = kept
        store.save(pruned)
        return pruned
    }

    private func addLog(_ entry: LogEntry) { log = Array(([entry] + log).prefix(250)) }
    private func logMsg(_ level: LogLevel, _ msg: String) {
        addLog(LogEntry(timeMs: Int64(Date().timeIntervalSince1970 * 1000), level: level, message: msg))
    }

    // MARK: - Scanning

    // V1: never two bracelets advertising at once → connect directly to the first found.
    func startScan() {
        guard !scanning else { return }
        scanResults = []
        pendingAutoConnect = true
        logMsg(.op, "Scan demarre… (connexion auto au 1er bracelet)")
        manager.onDeviceFound = { [weak self] device, _ in
            guard let self else { return }
            var others = self.scanResults.filter { $0.address != device.address }
            others.append(device)
            self.scanResults = others.sorted { $0.rssi > $1.rssi }
            if self.pendingAutoConnect {
                self.pendingAutoConnect = false
                self.logMsg(.op, "Bracelet trouve (\(device.name)) — connexion directe")
                self.connect(device.address)
            }
        }
        manager.startScan()
        scanning = manager.isScanning
    }

    func stopScan() {
        pendingAutoConnect = false
        guard scanning else { return }
        manager.stopScan()
        scanning = false
    }

    // MARK: - Connection

    func connect(_ address: String) {
        stopScan()
        logMsg(.op, "Connexion \(address)…")
        manager.connect(address: address)
    }

    func disconnect() { manager.disconnect() }

    // MARK: - GATT debug actions

    func syncTimeNow() { launchOp("Sync time") { try await self.manager.syncTime(Time.nowSeconds()) } }

    func sendConfig() {
        launchOp("Config") {
            let blob = try ConfigCodec.encodeConfig(self.draft)
            try await self.manager.writeConfig(blob)
        }
    }

    /// Syncs time then sends the TEST_DK §6 preset (alarm +120 s).
    func sendTestPreset() {
        launchOp("Test preset") {
            try await self.manager.syncTime(Time.nowSeconds())
            let preset = ConfigCodec.testPreset(Time.nowSeconds())
            self.draft = preset
            try await self.manager.writeConfig(try ConfigCodec.encodeConfig(preset))
        }
    }

    func allowNewBond() { launchOp("Allow new bond") { try await self.manager.sendControl(BuzzlieGatt.ctrlAllowNewBond) } }
    func forgetBonds() { launchOp("Forget bonds") { try await self.manager.sendControl(BuzzlieGatt.ctrlForgetBond) } }

    private func launchOp(_ name: String, _ block: @escaping () async throws -> Void) {
        Task {
            do { try await block() }
            catch { logMsg(.error, "\(name): \(error)") }
        }
    }

    // MARK: - Reminders + vibration

    func addReminder(_ r: ReminderUi) {
        if settings.reminders.count >= BuzzlieGatt.maxEntries {
            logMsg(.error, "Maximum \(BuzzlieGatt.maxEntries) rappels")
            return
        }
        mutateSettings { $0.reminders.append(r) }
    }

    func updateReminder(_ r: ReminderUi) {
        mutateSettings { s in
            s.reminders = s.reminders.map { $0.id == r.id ? r : $0 }
        }
    }

    func deleteReminder(_ id: String) {
        mutateSettings { s in s.reminders.removeAll { $0.id == id } }
    }

    func setVibration(_ intensity: VibrationPreset, _ continuous: Bool) {
        mutateSettings { $0.intensity = intensity; $0.continuous = continuous }
    }

    func setAlarmDuration(_ sec: Int) {
        let clamped = min(max(sec, BuzzlieGatt.alarmDurationSRange.lowerBound), BuzzlieGatt.alarmDurationSRange.upperBound)
        mutateSettings { $0.alarmDurationSec = clamped }
    }

    func reminderById(_ id: String?) -> ReminderUi? { settings.reminders.first { $0.id == id } }

    private func mutateSettings(_ transform: (inout AppSettings) -> Void) {
        var next = settings
        transform(&next)
        if next == settings { return } // no-op (e.g. re-tap same intensity) → no write
        settings = next
        configSynced = false
        store.save(next)
        pushConfigIfConnected()
    }

    /// Debounce: rapid changes (intensity tweaks) coalesce into ONE BLE write → flash.
    /// Each call cancels the pending push.
    private func pushConfigIfConnected() {
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self, !Task.isCancelled else { return }
            guard self.connState == .ready else { return }
            do {
                let d = self.settings.toConfigDraft(Time.nowSeconds())
                self.draft = d
                try await self.manager.writeConfig(try ConfigCodec.encodeConfig(d))
                self.configSynced = true
            } catch {
                self.configSynced = false
                self.logMsg(.error, "Config: \(error)")
            }
        }
    }

    /// On connection: read the alarms already on the bracelet, MERGE them into the local
    /// list (union — bracelet preserved), persist, then sync time and push the union.
    private func onConnected() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let now = Time.nowSeconds()
                let device = await self.manager.readSchedule()
                let merged = mergeSchedule(self.settings.reminders, device, now)
                let imported = merged.count - self.settings.reminders.count
                if imported > 0 {
                    var next = self.settings
                    next.reminders = merged
                    self.settings = next
                    self.store.save(next)
                    self.importedFromDevice = imported
                    self.logMsg(.op, "\(imported) alarme(s) recuperee(s) du bracelet")
                }
                try await self.manager.syncTime(now)
                let d = self.settings.toConfigDraft(Time.nowSeconds())
                self.draft = d
                try await self.manager.writeConfig(try ConfigCodec.encodeConfig(d))
                self.configSynced = true
            } catch {
                self.configSynced = false
                self.logMsg(.error, "Auto-sync/config: \(error)")
            }
        }
    }

    /// Play the current haptic pattern on the bracelet via a Control opcode — no flash
    /// write, no alarm scheduling. The firmware plays its stored pattern (kept in sync).
    func testVibration() { launchOp("Test vibration") { try await self.manager.sendControl(BuzzlieGatt.ctrlTestHaptic) } }

    // MARK: - Debug preview

    func encodedPreview() -> (String, Int) {
        do {
            let blob = try ConfigCodec.encodeConfig(draft)
            return (ConfigCodec.toHex(blob), blob.count)
        } catch {
            return ("(invalide: \(error))", -1)
        }
    }

    func clearLog() { log = [] }
}

import Foundation
import CoreBluetooth
import Combine

/// BLE manager for the BUZZLIE bracelet, built on CoreBluetooth.
///
/// CoreBluetooth already serializes GATT operations per peripheral and handles the ATT
/// MTU negotiation + long writes transparently, so we just await each operation's
/// delegate callback via continuations. Mirrors the Android `BuzzlieBleManager`
/// (Nordic BLE) surface: status/battery/schedule publishers, an events log, and the
/// suspend ops syncTime / writeConfig / readSchedule / sendControl.
@MainActor
final class BuzzlieBleManager: NSObject, ObservableObject {

    // Reactive state (mirrors the Android StateFlows)
    @Published private(set) var status: StatusFrame?
    @Published private(set) var schedule: ConfigDraft?
    @Published private(set) var supportsScheduleReadback = false
    @Published private(set) var battery: Int?
    @Published private(set) var connState: ConnState = .disconnected
    /// CoreBluetooth adapter/authorization state, drives the connect sheet UI.
    @Published private(set) var centralState: CBManagerState = .unknown

    /// Human-readable log of GATT operations and decoded notifications.
    let events = PassthroughSubject<LogEntry, Never>()

    /// Called for each matching bracelet discovered during a scan.
    var onDeviceFound: ((ScanDevice, CBPeripheral) -> Void)?

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var discovered: [String: CBPeripheral] = [:]

    private var configChar: CBCharacteristic?
    private var timeSyncChar: CBCharacteristic?
    private var statusChar: CBCharacteristic?
    private var controlChar: CBCharacteristic?
    private var scheduleChar: CBCharacteristic?
    private var batteryChar: CBCharacteristic?

    private(set) var isScanning = false

    // Pending continuations keyed by characteristic UUID.
    private var writeContinuations: [CBUUID: CheckedContinuation<Void, Error>] = [:]
    private var readContinuations: [CBUUID: CheckedContinuation<[UInt8]?, Never>] = [:]

    private func emit(_ level: LogLevel, _ message: String) {
        events.send(LogEntry(timeMs: Int64(Date().timeIntervalSince1970 * 1000), level: level, message: message))
    }

    /// Lazily create the central manager — this triggers the system Bluetooth
    /// authorization prompt, so we defer it until the user opens the connect sheet
    /// (parity with Android's "permission only when connecting").
    private func ensureCentral() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    // MARK: - Scanning

    func startScan() {
        ensureCentral()
        guard let central, central.state == .poweredOn, !isScanning else { return }
        discovered.removeAll()
        isScanning = true
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScan() {
        isScanning = false
        central?.stopScan()
    }

    // MARK: - Connection

    func connect(address: String) {
        guard let central, let p = discovered[address] else { return }
        stopScan()
        peripheral = p
        p.delegate = self
        connState = .connecting
        central.connect(p, options: nil)
    }

    func disconnect() {
        guard let central, let p = peripheral else { return }
        central.cancelPeripheralConnection(p)
    }

    // MARK: - Operations (await each; CoreBluetooth queues them per peripheral)

    func syncTime(_ epochSeconds: Int64) async throws {
        guard let timeSyncChar else { throw BleError.notReady }
        try await write(ConfigCodec.encodeTimeSync(epochSeconds), to: timeSyncChar)
        emit(.op, "Sync time epoch=\(epochSeconds)")
    }

    /// Writes the Config blob with response. CoreBluetooth negotiates a large ATT MTU at
    /// connection start, so the whole blob (≤ 100 B) fits a single Write Request; if a peer
    /// ever caps the MTU, the stack falls back to a Long Write the firmware QWR handles —
    /// so always `.withResponse`, never `.withoutResponse`.
    func writeConfig(_ blob: [UInt8]) async throws {
        guard let configChar else { throw BleError.notReady }
        try await write(blob, to: configChar)
        emit(.op, "Config envoye (\(blob.count) B): \(ConfigCodec.toHex(blob))")
    }

    /// Reads the Schedule (B005) read-back, or nil if the firmware predates B005 / read failed.
    func readSchedule() async -> ConfigDraft? {
        guard let scheduleChar, let peripheral else { return nil }
        let bytes = await withCheckedContinuation { (cont: CheckedContinuation<[UInt8]?, Never>) in
            readContinuations[scheduleChar.uuid] = cont
            peripheral.readValue(for: scheduleChar)
        }
        guard let bytes, let decoded = ConfigCodec.decodeConfig(bytes) else { return nil }
        schedule = decoded
        emit(.op, "Schedule lu : \(decoded.reminders.count) rappel(s) sur le bracelet")
        return decoded
    }

    func sendControl(_ opcode: Int, param: Int? = nil) async throws {
        guard let controlChar else { throw BleError.notReady }
        try await write(ConfigCodec.encodeControl(opcode, param: param), to: controlChar)
        emit(.op, String(format: "Control opcode=0x%02X param=\(param ?? 0)", opcode))
    }

    private func write(_ bytes: [UInt8], to characteristic: CBCharacteristic) async throws {
        guard let peripheral else { throw BleError.notReady }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            writeContinuations[characteristic.uuid] = cont
            peripheral.writeValue(Data(bytes), for: characteristic, type: .withResponse)
        }
    }

    enum BleError: Error { case notReady, disconnected }

    // MARK: - decode helpers

    fileprivate func handleStatus(_ bytes: [UInt8], fromNotify: Bool) {
        guard let s = ConfigCodec.decodeStatus(bytes) else { return }
        status = s
        let tag = fromNotify ? "notify" : "read"
        emit(.notify, String(format: "Status[\(tag)] \(s.vbatMv)mV \(s.percent)%% fw\(s.fwVersion) bonds=\(s.bondCount) flags=0x%02X", s.flags))
    }

    fileprivate func handleBattery(_ bytes: [UInt8]) {
        guard let pct = ConfigCodec.decodeBattery(bytes) else { return }
        battery = pct
        emit(.notify, "Battery \(pct)%")
    }

    fileprivate func handleScheduleNotify(_ bytes: [UInt8]) {
        guard let draft = ConfigCodec.decodeConfig(bytes) else { return }
        schedule = draft
        emit(.notify, "Schedule[notify] \(draft.reminders.count) rappel(s) sur le bracelet")
    }

    fileprivate func resetChars() {
        configChar = nil; timeSyncChar = nil; statusChar = nil
        controlChar = nil; scheduleChar = nil; batteryChar = nil
    }

    fileprivate func failPending(_ error: Error) {
        writeContinuations.values.forEach { $0.resume(throwing: error) }
        writeContinuations.removeAll()
        readContinuations.values.forEach { $0.resume(returning: nil) }
        readContinuations.removeAll()
    }
}

// MARK: - CBCentralManagerDelegate

extension BuzzlieBleManager: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor in
            self.centralState = state
            if state != .poweredOn { self.isScanning = false }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let hasService = services.contains(BuzzlieGatt.service)
        let nameMatch = advName?.hasPrefix(BuzzlieGatt.namePrefix) ?? false
        guard hasService || nameMatch else { return }
        let address = peripheral.identifier.uuidString
        let name = advName ?? address
        let rssi = RSSI.intValue
        Task { @MainActor in
            self.discovered[address] = peripheral
            self.onDeviceFound?(ScanDevice(name: name, address: address, rssi: rssi), peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.connState = .connecting
            peripheral.discoverServices([BuzzlieGatt.service, BuzzlieGatt.batteryService])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.connState = .failed
            self.emit(.error, "Connexion echouee: \(error?.localizedDescription ?? "?")")
            self.failPending(BleError.disconnected)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.resetChars()
            self.failPending(BleError.disconnected)
            self.connState = .disconnected
            self.status = nil
            self.battery = nil
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BuzzlieBleManager: CBPeripheralDelegate {

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            for service in peripheral.services ?? [] {
                if service.uuid == BuzzlieGatt.service {
                    peripheral.discoverCharacteristics(
                        [BuzzlieGatt.config, BuzzlieGatt.timeSync, BuzzlieGatt.status,
                         BuzzlieGatt.control, BuzzlieGatt.schedule], for: service)
                } else if service.uuid == BuzzlieGatt.batteryService {
                    peripheral.discoverCharacteristics([BuzzlieGatt.batteryLevel], for: service)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if service.uuid == BuzzlieGatt.batteryService {
                if let bc = service.characteristics?.first(where: { $0.uuid == BuzzlieGatt.batteryLevel }) {
                    self.batteryChar = bc
                    peripheral.setNotifyValue(true, for: bc)
                    peripheral.readValue(for: bc)
                }
                return
            }
            guard service.uuid == BuzzlieGatt.service else { return }
            for c in service.characteristics ?? [] {
                switch c.uuid {
                case BuzzlieGatt.config: self.configChar = c
                case BuzzlieGatt.timeSync: self.timeSyncChar = c
                case BuzzlieGatt.status: self.statusChar = c
                case BuzzlieGatt.control: self.controlChar = c
                case BuzzlieGatt.schedule: self.scheduleChar = c
                default: break
                }
            }
            self.supportsScheduleReadback = self.scheduleChar != nil

            let ok = self.configChar != nil && self.timeSyncChar != nil
                && self.statusChar != nil && self.controlChar != nil
            guard ok else {
                self.emit(.error, "Caracteristiques custom manquantes")
                self.connState = .failed
                return
            }

            // initialize(): enable notifications + initial read of status
            if let sc = self.statusChar {
                peripheral.setNotifyValue(true, for: sc)
                peripheral.readValue(for: sc)
            }
            if let sched = self.scheduleChar {
                peripheral.setNotifyValue(true, for: sched)
            }
            self.connState = .ready
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let bytes = characteristic.value.map { [UInt8]($0) } ?? []
        let uuid = characteristic.uuid
        Task { @MainActor in
            // A pending explicit read (readSchedule) takes priority over notify routing.
            if let cont = self.readContinuations.removeValue(forKey: uuid) {
                cont.resume(returning: bytes)
                return
            }
            switch uuid {
            case BuzzlieGatt.status: self.handleStatus(bytes, fromNotify: true)
            case BuzzlieGatt.batteryLevel: self.handleBattery(bytes)
            case BuzzlieGatt.schedule: self.handleScheduleNotify(bytes)
            default: break
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let uuid = characteristic.uuid
        Task { @MainActor in
            guard let cont = self.writeContinuations.removeValue(forKey: uuid) else { return }
            if let error { cont.resume(throwing: error) } else { cont.resume(returning: ()) }
        }
    }
}

import Foundation

/// Global vibration intensity (the firmware shares one pattern across all reminders).
enum VibrationPreset: String, Codable, CaseIterable {
    case DOUCE, STANDARD, FORTE

    var label: String {
        switch self {
        case .DOUCE: return "Douce"
        case .STANDARD: return "Standard"
        case .FORTE: return "Forte"
        }
    }
}

/// Resolve intensity + continuity + duration into the firmware's haptic step list.
/// off_ms == 0 means continuous; otherwise saccadé. Duration is the global alarm duration
/// (seconds, independent of intensity). All values clamped to firmware ranges.
func resolveSteps(_ intensity: VibrationPreset, _ continuous: Bool, _ durationSec: Int) -> [HapticStep] {
    let duration = min(max(durationSec * 1000, BuzzlieGatt.durationMsRange.lowerBound),
                       BuzzlieGatt.durationMsRange.upperBound)

    let step: HapticStep
    if continuous {
        step = HapticStep(onMs: 1000, offMs: 0, effectId: 0, totalDurationMs: duration)
    } else {
        let on: Int, off: Int
        switch intensity {
        case .DOUCE: (on, off) = (300, 700)
        case .STANDARD: (on, off) = (500, 500)
        case .FORTE: (on, off) = (700, 300)
        }
        step = HapticStep(onMs: on, offMs: off, effectId: 0, totalDurationMs: duration)
    }
    return [step]
}

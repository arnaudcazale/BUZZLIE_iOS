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
        // ON >= 500 ms obligatoire : sous ~300 ms le spin-up du LRA (re-verrouillage
        // auto-resonance) mange le burst, ressenti quasi nul (constate au poignet
        // 2026-07-24). La douceur vient de l'espacement (OFF long), pas de ON courts.
        let on: Int, off: Int
        switch intensity {
        case .DOUCE: (on, off) = (500, 1200)
        case .STANDARD: (on, off) = (500, 500)
        case .FORTE: (on, off) = (700, 300)
        }
        step = HapticStep(onMs: on, offMs: off, effectId: 0, totalDurationMs: duration)
    }
    return [step]
}

/// Inverse de resolveSteps : re-derive (intensite?, continu, duree s) depuis le step
/// lu sur le bracelet (blob 0xB005). Intensite nil = motif inconnu, on garde alors
/// celle de l'app (mais on adopte quand meme continuite et duree).
func vibrationFromStep(_ step: HapticStep) -> (VibrationPreset?, Bool, Int) {
    let durationSec = min(max(step.totalDurationMs / 1000,
                              BuzzlieGatt.alarmDurationSRange.lowerBound),
                          BuzzlieGatt.alarmDurationSRange.upperBound)
    if step.offMs == 0 { return (nil, true, durationSec) }
    let preset: VibrationPreset?
    switch (step.onMs, step.offMs) {
    case (500, 1200): preset = .DOUCE
    case (500, 500):  preset = .STANDARD
    case (700, 300):  preset = .FORTE
    default:          preset = nil
    }
    return (preset, false, durationSec)
}

import Foundation

/// An analog-style display of the existing 300 ms RMS measurement.
/// This is a visual reference, not a calibrated hardware VU meter.
public enum AnalogMeterScale {
    public static let referenceDBFS: Float = -18

    public static func needleFraction(rmsDB: Float) -> Double {
        guard rmsDB.isFinite, rmsDB > -89 else { return 0 }
        return fraction(vu: Double(rmsDB - referenceDBFS))
    }

    /// A traditional VU face is linear in voltage, so its dB markings are uneven.
    /// The needle rests at zero voltage and reaches the end stop at +3 VU.
    public static func fraction(vu: Double) -> Double {
        guard !vu.isNaN else { return 0 }
        return min(1, max(0, pow(10, (vu - 3) / 20)))
    }
}

import Foundation

/// Dedicated sample-rate-independent quasi-peak envelope, separate from RMS and
/// sample-peak hold. Approximate 10 ms integration and 24 dB return in 2.8 s.
/// Inspired by historical EBU Tech 3205; not a certified IEC meter or true peak.
public struct QuasiPeakMeter {
    private let attack: Float
    private let release: Float
    private var envelope: Float = 0

    public init(sampleRate: Double) {
        precondition(sampleRate.isFinite && sampleRate >= 8000)
        attack = Float(1 - exp(-1 / (sampleRate * 0.0023)))
        release = Float(pow(10, -24 / (20 * 2.8 * sampleRate)))
    }

    public mutating func process(_ sample: Float) {
        let magnitude = sample.isFinite ? abs(sample) : 0
        if magnitude > envelope { envelope += attack * (magnitude - envelope) }
        else { envelope *= release }
        if envelope < 1e-9 { envelope = 0 }
    }

    public var decibels: Float { AudioAnalyzer.dbAmplitude(envelope) }
}

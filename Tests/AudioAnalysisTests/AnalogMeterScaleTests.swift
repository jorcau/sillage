import Testing
import Foundation
@testable import AudioAnalysis

@Test func analogReferenceAndEndStops() {
    #expect(abs(AnalogMeterScale.needleFraction(rmsDB: -18) - pow(10, -3.0 / 20)) < 0.000001)
    #expect(AnalogMeterScale.needleFraction(rmsDB: -15) == 1)
    #expect(AnalogMeterScale.needleFraction(rmsDB: 0) == 1)
    #expect(AnalogMeterScale.needleFraction(rmsDB: -90) == 0)
    #expect(AnalogMeterScale.needleFraction(rmsDB: .nan) == 0)
    #expect(AnalogMeterScale.needleFraction(rmsDB: -.infinity) == 0)
}

@Test func analogScaleTracksVoltageAcrossTheDial() {
    let marks = [-20.0, -10, -7, -5, -3, -2, -1, 0, 1, 2, 3]
    let positions = marks.map { AnalogMeterScale.fraction(vu: $0) }
    for i in 1..<positions.count { #expect(positions[i] > positions[i - 1]) }
    // A 6.02 dB increase doubles the needle's voltage-based displacement.
    #expect(abs(AnalogMeterScale.fraction(vu: -6.020599913) * 2 - AnalogMeterScale.fraction(vu: 0)) < 0.000001)
    for vu in marks {
        #expect(abs(AnalogMeterScale.needleFraction(rmsDB: Float(vu) - 18) - AnalogMeterScale.fraction(vu: vu)) < 0.000001)
    }
}

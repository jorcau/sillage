import CoreAudio
import Foundation
import CRealtime

public struct CaptureInfo: Sendable {
    public let sampleRate: Double
    public let outputDevice: AudioObjectID
    public let outputName: String
}
public enum CaptureError: LocalizedError {
    case osStatus(String, OSStatus)
    case unsupportedFormat
    public var errorDescription: String? {
        switch self {
        case let .osStatus(operation, code):
            return "\(operation): Core Audio error \(code). Check audio capture permission in System Settings → Privacy & Security."
        case .unsupportedFormat: return "Unsupported capture format: stereo Float32 PCM is required."
        }
    }
}

// All HAL lifecycle operations run on one control queue. AudioDeviceStart can wait for audio.
public final class SystemAudioCapture: @unchecked Sendable {
    private let control = DispatchQueue(label: "audio.sillage.capture-control", qos: .userInitiated)
    private var tap: AudioObjectID = 0
    private var aggregate: AudioObjectID = 0
    private var ioProc: AudioDeviceIOProcID?
    private var listeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private let onChange: @Sendable () -> Void
    public init(onConfigurationChange: @escaping @Sendable () -> Void) { onChange = onConfigurationChange }

    // Caller retains the ring until stop() completes. Callback context has no Swift objects.
    public func start(ringAddress: UInt) async throws -> CaptureInfo {
        try await withCheckedThrowingContinuation { continuation in
            control.async {
                do { continuation.resume(returning: try self.startOnQueue(ringAddress: ringAddress)) }
                catch { self.stopOnQueue(); continuation.resume(throwing: error) }
            }
        }
    }
    public func stop() async {
        await withCheckedContinuation { continuation in
            control.async { self.stopOnQueue(); continuation.resume() }
        }
    }
    private func checked(_ code: OSStatus, _ operation: String) throws {
        if code != noErr { throw CaptureError.osStatus(operation, code) }
    }
    private func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }
    private func startOnQueue(ringAddress: UInt) throws -> CaptureInfo {
        stopOnQueue()
        var outputID = AudioObjectID(0)
        var outputAddress = address(kAudioHardwarePropertyDefaultOutputDevice)
        var bytes = UInt32(MemoryLayout<AudioObjectID>.size)
        try checked(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &outputAddress, 0, nil, &bytes, &outputID), "Reading audio output")

        // Exclude our process if Core Audio has registered it; this app never produces audio.
        var pid = getpid(), processID = AudioObjectID(0)
        var pidAddress = address(kAudioHardwarePropertyTranslatePIDToProcessObject)
        bytes = UInt32(MemoryLayout<AudioObjectID>.size)
        let translated = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &pidAddress, UInt32(MemoryLayout<pid_t>.size), &pid, &bytes, &processID)
        let excluded = translated == noErr && processID != 0 ? [processID] : []
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: excluded)
        description.name = "Sillage · System audio"
        description.isPrivate = true
        description.muteBehavior = .unmuted
        try checked(AudioHardwareCreateProcessTap(description, &tap), "Creating capture tap")

        var format = AudioStreamBasicDescription()
        var formatAddress = address(kAudioTapPropertyFormat)
        bytes = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try checked(AudioObjectGetPropertyData(tap, &formatAddress, 0, nil, &bytes, &format), "Reading audio format")
        guard format.mFormatID == kAudioFormatLinearPCM,
              format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              format.mFormatFlags & kAudioFormatFlagIsBigEndian == 0,
              format.mBitsPerChannel == 32, format.mChannelsPerFrame == 2,
              format.mSampleRate >= 8000, format.mSampleRate.isFinite else { throw CaptureError.unsupportedFormat }

        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Sillage Private Capture",
            kAudioAggregateDeviceUIDKey: "audio.sillage.capture.\(UUID().uuidString)",
            kAudioAggregateDeviceIsPrivateKey: true,
            // Avoid waiting for a playing process in AudioDeviceStart; silence is a valid state.
            kAudioAggregateDeviceTapAutoStartKey: false,
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: description.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true
            ]]
        ]
        try checked(AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &aggregate), "Creating private capture device")
        try checked(AudioDeviceCreateIOProcID(aggregate, nt_audio_callback, UnsafeMutableRawPointer(bitPattern: ringAddress), &ioProc), "Connecting audio stream")
        try checked(AudioDeviceStart(aggregate, ioProc), "Starting capture")
        addListener(object: AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDefaultOutputDevice)
        addListener(object: tap, selector: kAudioTapPropertyFormat)
        return CaptureInfo(sampleRate: format.mSampleRate, outputDevice: outputID, outputName: Self.deviceName(outputID))
    }
    private func addListener(object: AudioObjectID, selector: AudioObjectPropertySelector) {
        var property = address(selector)
        let callback: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.onChange() }
        if AudioObjectAddPropertyListenerBlock(object, &property, control, callback) == noErr {
            listeners.append((object, property, callback))
        }
    }
    private func stopOnQueue() {
        for (object, var property, callback) in listeners { AudioObjectRemovePropertyListenerBlock(object, &property, control, callback) }
        listeners.removeAll()
        if let ioProc, aggregate != 0 {
            AudioDeviceStop(aggregate, ioProc)
            AudioDeviceDestroyIOProcID(aggregate, ioProc)
        }
        ioProc = nil
        if aggregate != 0 { AudioHardwareDestroyAggregateDevice(aggregate); aggregate = 0 }
        if tap != 0 { AudioHardwareDestroyProcessTap(tap); tap = 0 }
    }
    private static func deviceName(_ id: AudioObjectID) -> String {
        var property = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value: CFString = "System output" as CFString
        var bytes = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(id, &property, 0, nil, &bytes, pointer)
        }
        if status == noErr { return value as String }
        return "System output"
    }
}

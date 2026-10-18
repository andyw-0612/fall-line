import Foundation
import IOKit
import IOKit.hid

/// Local SPU accelerometer access. Calls and callbacks use the main run loop.
/// Format and wake properties: olvvier/apple-silicon-accelerometer (MIT).
// HID reports, Timer callbacks, and all host access are confined to the main run loop.
final class TapSensor: @unchecked Sendable {
    var onTap: ((Double, Double) -> Void)?
    var onTelemetry: ((Double, Double, Double, Double) -> Void)?
    var onStatus: ((String) -> Void)?
    var threshold: Double {
        get { detector.threshold }
        set { detector.threshold = newValue; detector.reset() }
    }
    private let detector = TapDetector()
    private var device: IOHIDDevice?
    private let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
    private var savedProperties: [(io_service_t, String, CFTypeRef?)] = []
    private var watchdog: Timer?
    private var lastArrival = 0.0
    private var lastTelemetry = 0.0
    private var windowCount = 0
    private var windowStart = 0.0
    private var peak = 0.0
    private var peakWindowStart = 0.0
    private var secondsPerTick: Double = 0
    private(set) var totalSamples = 0
    private(set) var latestSampleAge: Double?

    init() {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        secondsPerTick = Double(info.numer) / Double(info.denom) * 1e-9
    }

    deinit { stop(); buffer.deallocate() }

    private func matches(_ service: io_service_t) -> Bool {
        func number(_ key: String) -> Int? {
            (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber)?.intValue
        }
        return number("PrimaryUsagePage") == 0xFF00 && number("PrimaryUsage") == 3
    }

    private func services(_ name: String) -> [io_service_t] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(name), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var found: [io_service_t] = []
        while case let service = IOIteratorNext(iterator), service != 0 { found.append(service) }
        return found
    }

    func start() {
        guard device == nil else { return }
        detector.reset(); totalSamples = 0; windowCount = 0; peak = 0; latestSampleAge = nil
        let now = ProcessInfo.processInfo.systemUptime
        lastArrival = now; windowStart = now; lastTelemetry = now; peakWindowStart = now
        var failure = "No compatible MacBook accelerometer"
        for service in services("AppleSPUHIDDevice") {
            defer { IOObjectRelease(service) }
            guard matches(service), let hid = IOHIDDeviceCreate(kCFAllocatorDefault, service) else { continue }
            let result = IOHIDDeviceOpen(hid, IOOptionBits(kIOHIDOptionsTypeNone))
            guard result == kIOReturnSuccess else {
                failure = String(format: "Tap sensor access denied (0x%08x)", UInt32(bitPattern: result))
                continue
            }
            device = hid
            IOHIDDeviceRegisterInputReportWithTimeStampCallback(hid, buffer, 4096, { context, result, _, _, _, report, length, timestamp in
                guard result == kIOReturnSuccess, let context else { return }
                let sensor = Unmanaged<TapSensor>.fromOpaque(context).takeUnretainedValue()
                guard let sample = AccelerationSample.decode(UnsafeBufferPointer(start: report, count: length),
                    timestamp: Double(timestamp) * sensor.secondsPerTick) else { return }
                sensor.receive(sample)
            }, Unmanaged.passUnretained(self).toOpaque())
            IOHIDDeviceScheduleWithRunLoop(hid, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            break
        }
        guard device != nil else { onStatus?(failure); return }
        // Wake only this accelerometer's driver, not unrelated SPU sensors.
        for driver in services("AppleSPUHIDDriver") {
            defer { IOObjectRelease(driver) }
            guard matches(driver) else { continue }
            for (key, value) in [("SensorPropertyReportingState", 1), ("SensorPropertyPowerState", 1), ("ReportInterval", 1000)] {
                let old = IORegistryEntryCreateCFProperty(driver, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
                if IORegistryEntrySetCFProperty(driver, key as CFString, NSNumber(value: value)) == KERN_SUCCESS {
                    IOObjectRetain(driver)
                    savedProperties.append((driver, key, old))
                }
            }
        }
        onStatus?("Tap sensor warming up…")
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            if ProcessInfo.processInfo.systemUptime - self.lastArrival > 1.5 {
                self.stop()
                self.onStatus?("Tap sensor not delivering data · restart camera to retry")
            }
        }
    }

    private func receive(_ sample: AccelerationSample) {
        let now = ProcessInfo.processInfo.systemUptime
        lastArrival = now; totalSamples += 1
        latestSampleAge = now - sample.timestamp
        let hit = detector.update(sample)
        peak = max(peak, detector.magnitude)
        // Never start input from an old batch delivered after a UI stall.
        if hit && abs(now - sample.timestamp) < 0.2 { onTap?(sample.timestamp, detector.magnitude) }
        if now - lastTelemetry >= 0.2 {
            let hz = Double(totalSamples - windowCount) / max(0.001, now - windowStart)
            onTelemetry?(detector.magnitude, detector.effectiveThreshold, peak, hz)
            onStatus?(String(format: "%.3fg · peak %.3fg · %.0f Hz", threshold, peak, hz))
            lastTelemetry = now; windowStart = now; windowCount = totalSamples
            if now - peakWindowStart >= 1 { peak = 0; peakWindowStart = now }
        }
    }

    func stop() {
        watchdog?.invalidate(); watchdog = nil
        if let device {
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDDeviceRegisterInputReportWithTimeStampCallback(device, buffer, 4096, nil, nil)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            self.device = nil
        }
        for (driver, key, old) in savedProperties.reversed() {
            if let old { IORegistryEntrySetCFProperty(driver, key as CFString, old) }
            IOObjectRelease(driver)
        }
        savedProperties.removeAll(); detector.reset()
    }
}

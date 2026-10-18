import Foundation

struct InputSettings {
    var pointDistance = 70.0
    var tapThreshold = 0.025
    var motionGain = 700.0

    static func load(from defaults: UserDefaults = .standard) -> Self {
        func value(_ key: String, fallback: Double, range: ClosedRange<Double>) -> Double {
            guard defaults.object(forKey: key) != nil else { return fallback }
            let number = defaults.double(forKey: key)
            return number.isFinite ? min(range.upperBound, max(range.lowerBound, number)) : fallback
        }
        return Self(pointDistance: value("palm.pointDistance", fallback: 70, range: 40...160),
                    tapThreshold: value("palm.tapThreshold", fallback: 0.025, range: 0.005...0.15),
                    motionGain: value("palm.motionGain", fallback: 700, range: 300...1800))
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(pointDistance, forKey: "palm.pointDistance")
        defaults.set(tapThreshold, forKey: "palm.tapThreshold")
        defaults.set(motionGain, forKey: "palm.motionGain")
        if defaults === UserDefaults.standard {
            NotificationCenter.default.post(name: .inputSettingsSaved, object: nil)
        }
    }
}

extension Notification.Name {
    static let inputSettingsSaved = Notification.Name("FallLine.inputSettingsSaved")
}

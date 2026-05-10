import AppKit

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    var fontSize: CGFloat {
        get {
            let v = defaults.double(forKey: "fontSize")
            return v > 0 ? CGFloat(v) : 13
        }
        set { defaults.set(Double(newValue), forKey: "fontSize") }
    }

    var textColor: NSColor {
        get { color(forKey: "textColor") ?? .black }
        set { save(color: newValue, forKey: "textColor") }
    }

    var backgroundColor: NSColor {
        get { color(forKey: "backgroundColor") ?? NSColor(red: 1.0, green: 0.98, blue: 0.6, alpha: 0.95) }
        set { save(color: newValue, forKey: "backgroundColor") }
    }

    private init() {}

    private func color(forKey key: String) -> NSColor? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    }

    private func save(color: NSColor, forKey key: String) {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
        defaults.set(data, forKey: key)
    }
}

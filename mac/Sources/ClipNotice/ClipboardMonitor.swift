import AppKit

final class ClipboardMonitor {
    private var lastChangeCount: Int
    private var timer: Timer?

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func start(onChange: @escaping (String) -> Void) {
        lastChangeCount = NSPasteboard.general.changeCount
        let t = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let pb = NSPasteboard.general
            let count = pb.changeCount
            guard count != self.lastChangeCount else { return }
            self.lastChangeCount = count
            guard let text = pb.string(forType: .string), !text.isEmpty else { return }
            onChange(text)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

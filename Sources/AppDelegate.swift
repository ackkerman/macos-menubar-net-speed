import Cocoa
import Foundation
import os.log
import Darwin

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private let interfaceName = "en0"

    private var statusItem: NSStatusItem!
    private var timer: DispatchSourceTimer?

    private var lastRx: UInt64 = 0
    private var lastTx: UInt64 = 0

    private var maxResult: (down: Double, up: Double)?
    private var downloadObservation: NSKeyValueObservation?
    private var uploadObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        writeDebugLog("MenubarNetSpeed launch start")
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        startTrafficMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.cancel()
        downloadObservation = nil
        uploadObservation = nil
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "↓ 0 ↑ 0"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Measure Max Speed",
            action: #selector(measureMaxSpeed),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(
            title: "Open Network Monitor (top)",
            action: #selector(openNetworkTop),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
    }

    // MARK: - Real-time Traffic

    private func startTrafficMonitor() {
        timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer?.schedule(deadline: .now(), repeating: 1.0)
        timer?.setEventHandler { [weak self] in
            self?.updateTraffic()
        }
        timer?.resume()
    }

    private func updateTraffic() {
        guard maxResult == nil else { return }

        let (rx, tx) = getWiFiBytes(interface: interfaceName)

        defer {
            lastRx = rx
            lastTx = tx
        }

        guard lastRx > 0 else {
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.button?.title = "↓ 0 ↑ 0"
            }
            return
        }

        let downKB = Double(rx &- lastRx) / 1024.0
        let upKB = Double(tx &- lastTx) / 1024.0

        DispatchQueue.main.async { [weak self] in
            self?.statusItem.button?.title =
                String(format: "↓ %.1fMB ↑ %.1fMB", downKB / 1024, upKB / 1024)
        }
    }

    // MARK: - Max Speed

    @objc private func measureMaxSpeed() {
        maxResult = nil
        statusItem.button?.title = "Measuring..."

        measureDownload { [weak self] down in
            self?.measureUpload { up in
                self?.maxResult = (down, up)
                DispatchQueue.main.async { [weak self] in
                    self?.statusItem.button?.title =
                        String(format: "Max ↓ %.0f ↑ %.0f Mbps", down, up)
                }
            }
        }
    }

    private func measureDownload(completion: @escaping (Double) -> Void) {
        let url = URL(string: "https://speed.cloudflare.com/__down?bytes=100000000")!
        let session = URLSession(configuration: .ephemeral)
        let start = Date()
        var latestBytes: Int64 = 0

        let task = session.dataTask(with: url) { [weak self] _, _, _ in
            let elapsed = max(Date().timeIntervalSince(start), 0.001)
            let mbps = (Double(latestBytes) * 8) / elapsed / 1_000_000
            DispatchQueue.main.async {
                completion(mbps)
            }
            self?.downloadObservation = nil
        }

        downloadObservation = task.progress.observe(\.completedUnitCount) { [weak task] progress, _ in
            latestBytes = progress.completedUnitCount
            if Date().timeIntervalSince(start) >= 3 {
                task?.cancel()
            }
        }

        task.resume()
    }

    private func measureUpload(completion: @escaping (Double) -> Void) {
        let url = URL(string: "https://speed.cloudflare.com/__up")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        let payload = Data(repeating: 0x41, count: 5_000_000)
        let session = URLSession(configuration: .ephemeral)
        let start = Date()
        var latestBytes: Int64 = 0

        let task = session.uploadTask(with: req, from: payload) { [weak self] _, _, _ in
            let elapsed = max(Date().timeIntervalSince(start), 0.001)
            let sent = latestBytes > 0 ? latestBytes : Int64(payload.count)
            let mbps = (Double(sent) * 8) / elapsed / 1_000_000
            DispatchQueue.main.async {
                completion(mbps)
            }
            self?.uploadObservation = nil
        }

        uploadObservation = task.progress.observe(\.completedUnitCount) { progress, _ in
            latestBytes = progress.completedUnitCount
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            task.cancel()
        }

        task.resume()
    }

    // MARK: - nettop

    @objc private func openNetworkTop() {
        let script = """
        tell application \"Terminal\"
            activate
            do script \"nettop -I en0 -s 1\"
        end tell
        """
        NSAppleScript(source: script)?.executeAndReturnError(nil)
    }

    // MARK: - Utils

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Debug

    private func writeDebugLog(_ message: String) {
        let line = message + "\n"
        if let data = line.data(using: .utf8) {
            let url = URL(fileURLWithPath: "/tmp/menubarnetspeed.log")
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: url)
            }
        }
        os_log("%@", message)
    }
}

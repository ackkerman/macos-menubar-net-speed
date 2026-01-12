import Cocoa
import Foundation
import os.log
import Darwin

class AppDelegate: NSObject, NSApplicationDelegate {
    private var selectedInterface = "en0"

    private var statusItem: NSStatusItem!
    private var timer: DispatchSourceTimer?
    private var interfaceMenu: NSMenu?
    private var interfaceRootItem: NSMenuItem?

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

        let ifaceRoot = NSMenuItem(title: "Interface: \(selectedInterface)", action: nil, keyEquivalent: "")
        let ifaceSub = NSMenu()
        interfaceMenu = ifaceSub
        interfaceRootItem = ifaceRoot
        menu.setSubmenu(ifaceSub, for: ifaceRoot)
        menu.addItem(ifaceRoot)
        populateInterfacesMenu()

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

        let (rx, tx) = getInterfaceBytes(interface: selectedInterface)

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

    // MARK: - Traffic monitor (iftop)

    @objc private func openNetworkTop() {
        // Create a temporary .command script and open it with Terminal to avoid AppleEvents.
        let scriptPath = "/tmp/menubarnetspeed-iftop.command"
        let script = "#!/bin/bash\nsudo iftop -i \(selectedInterface) -N -P -B -m 100M\n"
        let fm = FileManager.default
        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Terminal", scriptPath]
            try process.run()
            writeDebugLog("Terminal iftop launch requested via \(scriptPath)")
        } catch {
            writeDebugLog("Terminal iftop launch failed: \(error)")
        }
    }

    // MARK: - Utils

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Interface selection

    private func populateInterfacesMenu() {
        let interfaces = listNetworkInterfaces()
        interfaceMenu?.removeAllItems()
        if interfaces.isEmpty {
            let item = NSMenuItem(title: "No interfaces", action: nil, keyEquivalent: "")
            item.isEnabled = false
            interfaceMenu?.addItem(item)
            return
        }
        for name in interfaces {
            let item = NSMenuItem(title: name, action: #selector(selectInterface(_:)), keyEquivalent: "")
            item.target = self
            item.state = (name == selectedInterface) ? .on : .off
            interfaceMenu?.addItem(item)
        }
    }

    @objc private func selectInterface(_ sender: NSMenuItem) {
        let name = sender.title
        selectedInterface = name
        lastRx = 0
        lastTx = 0
        maxResult = nil
        statusItem.button?.title = "↓ 0 ↑ 0"
        populateInterfacesMenu()
        writeDebugLog("Interface selected: \(name)")
        interfaceRootItem?.title = "Interface: \(name)"
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

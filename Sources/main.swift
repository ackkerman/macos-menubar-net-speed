import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

if let data = "MenubarNetSpeed main start\n".data(using: .utf8) {
    if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/tmp/menubarnetspeed.log")) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? data.write(to: URL(fileURLWithPath: "/tmp/menubarnetspeed.log"))
    }
}

app.run()

import Foundation
import Darwin

func getWiFiBytes(interface: String) -> (UInt64, UInt64) {
    var addrs: UnsafeMutablePointer<ifaddrs>?
    var rx: UInt64 = 0
    var tx: UInt64 = 0

    guard getifaddrs(&addrs) == 0, let first = addrs else {
        return (0, 0)
    }

    for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
        let ifa = ptr.pointee

        guard
            let addr = ifa.ifa_addr,
            addr.pointee.sa_family == UInt8(AF_LINK),
            let data = ifa.ifa_data
        else { continue }

        let name = String(cString: ifa.ifa_name)
        let ifdata = data.assumingMemoryBound(to: if_data.self).pointee

        // Filter only target interface name (en0) to avoid VPN / others.
        if name == interface {
            rx &+= UInt64(ifdata.ifi_ibytes)
            tx &+= UInt64(ifdata.ifi_obytes)
        }
    }

    freeifaddrs(addrs)
    return (rx, tx)
}

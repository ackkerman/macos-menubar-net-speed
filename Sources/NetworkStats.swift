import Foundation
import Darwin

func getInterfaceBytes(interface: String) -> (UInt64, UInt64) {
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

        if name == interface {
            rx &+= UInt64(ifdata.ifi_ibytes)
            tx &+= UInt64(ifdata.ifi_obytes)
        }
    }

    freeifaddrs(addrs)
    return (rx, tx)
}

func listNetworkInterfaces() -> [String] {
    var addrs: UnsafeMutablePointer<ifaddrs>?
    var names: Set<String> = []

    guard getifaddrs(&addrs) == 0, let first = addrs else {
        return []
    }

    for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
        let ifa = ptr.pointee
        guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) else {
            continue
        }
        let name = String(cString: ifa.ifa_name)
        // Skip loopback to reduceノイズ
        if name == "lo0" { continue }
        names.insert(name)
    }

    freeifaddrs(addrs)
    // 優先順: en系 -> utun系 -> その他
    return names.sorted { lhs, rhs in
        let order: (String) -> Int = { n in
            if n.hasPrefix("en") { return 0 }
            if n.hasPrefix("utun") { return 1 }
            return 2
        }
        let lo = order(lhs)
        let ro = order(rhs)
        if lo == ro { return lhs < rhs }
        return lo < ro
    }
}

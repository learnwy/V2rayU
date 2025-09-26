# 工具文件详解

## 📋 概述

本文档详细解析V2rayU应用的工具文件，包括网络工具、系统工具、数据处理工具、UI工具等辅助功能的实现。这些工具文件为应用的各个模块提供了基础支持和通用功能。

---

## 🏗️ 文件结构

```
V2rayU/Utilities/
├── Network/
│   ├── NetworkUtils.swift            # 网络工具
│   ├── PingUtils.swift               # 延迟测试工具
│   ├── SpeedTestUtils.swift          # 速度测试工具
│   ├── DNSUtils.swift                # DNS工具
│   ├── ProxyUtils.swift              # 代理工具
│   └── GeoIPUtils.swift              # GeoIP工具
├── System/
│   ├── SystemUtils.swift             # 系统工具
│   ├── FileUtils.swift               # 文件工具
│   ├── ProcessUtils.swift            # 进程工具
│   ├── MenuBarUtils.swift            # 菜单栏工具
│   ├── NotificationUtils.swift       # 通知工具
│   └── KeychainUtils.swift           # 钥匙串工具
├── Data/
│   ├── JSONUtils.swift               # JSON工具
│   ├── Base64Utils.swift             # Base64工具
│   ├── CryptoUtils.swift             # 加密工具
│   ├── CompressionUtils.swift        # 压缩工具
│   ├── ValidationUtils.swift         # 验证工具
│   └── ParsingUtils.swift            # 解析工具
├── UI/
│   ├── ColorUtils.swift              # 颜色工具
│   ├── ImageUtils.swift              # 图像工具
│   ├── AnimationUtils.swift          # 动画工具
│   ├── LayoutUtils.swift             # 布局工具
│   └── ThemeUtils.swift              # 主题工具
├── Extensions/
│   ├── String+Extensions.swift       # 字符串扩展
│   ├── Data+Extensions.swift         # 数据扩展
│   ├── Date+Extensions.swift         # 日期扩展
│   ├── URL+Extensions.swift          # URL扩展
│   ├── Color+Extensions.swift        # 颜色扩展
│   └── View+Extensions.swift         # 视图扩展
└── Constants/
    ├── AppConstants.swift            # 应用常量
    ├── NetworkConstants.swift        # 网络常量
    ├── UIConstants.swift             # UI常量
    └── ConfigConstants.swift         # 配置常量
```

---

## 🌐 网络工具

### NetworkUtils.swift

**作用**：提供网络相关的通用工具函数。

```swift
import Foundation
import Network
import SystemConfiguration

class NetworkUtils {
    
    // MARK: - Network Connectivity
    static func isNetworkAvailable() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        guard let reachability = defaultRouteReachability else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(reachability, &flags) {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        return isReachable && !needsConnection
    }
    
    static func getNetworkType() -> NetworkType {
        let monitor = NWPathMonitor()
        var networkType: NetworkType = .unknown
        
        let semaphore = DispatchSemaphore(value: 0)
        
        monitor.pathUpdateHandler = { path in
            if path.usesInterfaceType(.wifi) {
                networkType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                networkType = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                networkType = .ethernet
            } else {
                networkType = .unknown
            }
            semaphore.signal()
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
        
        _ = semaphore.wait(timeout: .now() + 1.0)
        monitor.cancel()
        
        return networkType
    }
    
    // MARK: - IP Address
    static func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    let name = String(cString: interface.ifa_name)
                    
                    if name == "en0" || name == "en1" || name == "pdp_ip0" || name == "pdp_ip1" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        
                        getnameinfo(interface.ifa_addr,
                                  socklen_t(interface.ifa_addr.pointee.sa_len),
                                  &hostname,
                                  socklen_t(hostname.count),
                                  nil,
                                  socklen_t(0),
                                  NI_NUMERICHOST)
                        
                        address = String(cString: hostname)
                        break
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
    
    static func getPublicIPAddress() async -> String? {
        let urls = [
            "https://api.ipify.org",
            "https://icanhazip.com",
            "https://ipinfo.io/ip",
            "https://checkip.amazonaws.com"
        ]
        
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    if isValidIPAddress(ip) {
                        return ip
                    }
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
    
    // MARK: - IP Validation
    static func isValidIPAddress(_ ip: String) -> Bool {
        return isValidIPv4(ip) || isValidIPv6(ip)
    }
    
    static func isValidIPv4(_ ip: String) -> Bool {
        let parts = ip.components(separatedBy: ".")
        guard parts.count == 4 else { return false }
        
        for part in parts {
            guard let num = Int(part), num >= 0 && num <= 255 else {
                return false
            }
        }
        
        return true
    }
    
    static func isValidIPv6(_ ip: String) -> Bool {
        var addr = sockaddr_in6()
        return inet_pton(AF_INET6, ip, &addr.sin6_addr) == 1
    }
    
    // MARK: - Domain Validation
    static func isValidDomain(_ domain: String) -> Bool {
        let domainRegex = "^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)+(xn--[a-zA-Z0-9]+|[a-zA-Z]{2,})$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", domainRegex)
        return predicate.evaluate(with: domain)
    }
    
    // MARK: - URL Validation
    static func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    // MARK: - Port Validation
    static func isValidPort(_ port: Int) -> Bool {
        return port > 0 && port <= 65535
    }
    
    // MARK: - Network Interface
    static func getNetworkInterfaces() -> [NetworkInterface] {
        var interfaces: [NetworkInterface] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                let name = String(cString: interface.ifa_name)
                let flags = interface.ifa_flags
                
                if flags & UInt32(IFF_UP) != 0 && flags & UInt32(IFF_LOOPBACK) == 0 {
                    let addrFamily = interface.ifa_addr.pointee.sa_family
                    
                    if addrFamily == UInt8(AF_INET) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        
                        getnameinfo(interface.ifa_addr,
                                  socklen_t(interface.ifa_addr.pointee.sa_len),
                                  &hostname,
                                  socklen_t(hostname.count),
                                  nil,
                                  socklen_t(0),
                                  NI_NUMERICHOST)
                        
                        let address = String(cString: hostname)
                        
                        let networkInterface = NetworkInterface(
                            name: name,
                            address: address,
                            isActive: flags & UInt32(IFF_RUNNING) != 0
                        )
                        
                        interfaces.append(networkInterface)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return interfaces
    }
    
    // MARK: - Bandwidth Calculation
    static func formatBandwidth(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond
        var unitIndex = 0
        
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.2f %@", value, units[unitIndex])
    }
    
    static func formatDataSize(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0
        
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.2f %@", value, units[unitIndex])
    }
}

// MARK: - Supporting Types
enum NetworkType {
    case wifi
    case cellular
    case ethernet
    case unknown
    
    var displayName: String {
        switch self {
        case .wifi: return "Wi-Fi"
        case .cellular: return "蜂窝网络"
        case .ethernet: return "以太网"
        case .unknown: return "未知"
        }
    }
}

struct NetworkInterface {
    let name: String
    let address: String
    let isActive: Bool
}
```

### PingUtils.swift

**作用**：提供网络延迟测试功能。

```swift
import Foundation
import Network

class PingUtils {
    
    // MARK: - Ping Test
    static func ping(host: String, timeout: TimeInterval = 5.0) async -> PingResult {
        let startTime = Date()
        
        do {
            let result = try await performPing(host: host, timeout: timeout)
            let latency = Date().timeIntervalSince(startTime) * 1000 // 转换为毫秒
            
            return PingResult(
                host: host,
                latency: latency,
                isSuccess: result,
                timestamp: startTime,
                error: nil
            )
        } catch {
            return PingResult(
                host: host,
                latency: -1,
                isSuccess: false,
                timestamp: startTime,
                error: error
            )
        }
    }
    
    private static func performPing(host: String, timeout: TimeInterval) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: 80,
                using: .tcp
            )
            
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                connection.cancel()
                continuation.resume(throwing: PingError.timeout)
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    timeoutTimer.invalidate()
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed(let error):
                    timeoutTimer.invalidate()
                    connection.cancel()
                    continuation.resume(throwing: error)
                case .cancelled:
                    timeoutTimer.invalidate()
                    break
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
        }
    }
    
    // MARK: - Batch Ping
    static func batchPing(hosts: [String], timeout: TimeInterval = 5.0) async -> [PingResult] {
        await withTaskGroup(of: PingResult.self) { group in
            for host in hosts {
                group.addTask {
                    await ping(host: host, timeout: timeout)
                }
            }
            
            var results: [PingResult] = []
            for await result in group {
                results.append(result)
            }
            
            return results.sorted { $0.host < $1.host }
        }
    }
    
    // MARK: - Continuous Ping
    static func continuousPing(host: String, interval: TimeInterval = 1.0, count: Int = 10) -> AsyncStream<PingResult> {
        return AsyncStream { continuation in
            Task {
                for i in 0..<count {
                    let result = await ping(host: host)
                    continuation.yield(result)
                    
                    if i < count - 1 {
                        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    }
                }
                continuation.finish()
            }
        }
    }
    
    // MARK: - Ping Statistics
    static func calculatePingStatistics(_ results: [PingResult]) -> PingStatistics {
        let successfulPings = results.filter { $0.isSuccess }
        let latencies = successfulPings.map { $0.latency }
        
        guard !latencies.isEmpty else {
            return PingStatistics(
                totalCount: results.count,
                successCount: 0,
                failureCount: results.count,
                successRate: 0.0,
                averageLatency: -1,
                minLatency: -1,
                maxLatency: -1,
                standardDeviation: -1
            )
        }
        
        let average = latencies.reduce(0, +) / Double(latencies.count)
        let min = latencies.min() ?? -1
        let max = latencies.max() ?? -1
        
        // 计算标准差
        let variance = latencies.map { pow($0 - average, 2) }.reduce(0, +) / Double(latencies.count)
        let standardDeviation = sqrt(variance)
        
        return PingStatistics(
            totalCount: results.count,
            successCount: successfulPings.count,
            failureCount: results.count - successfulPings.count,
            successRate: Double(successfulPings.count) / Double(results.count) * 100,
            averageLatency: average,
            minLatency: min,
            maxLatency: max,
            standardDeviation: standardDeviation
        )
    }
}

// MARK: - Supporting Types
struct PingResult {
    let host: String
    let latency: Double // 毫秒
    let isSuccess: Bool
    let timestamp: Date
    let error: Error?
    
    var formattedLatency: String {
        if isSuccess {
            return String(format: "%.0f ms", latency)
        } else {
            return "超时"
        }
    }
    
    var qualityLevel: PingQuality {
        guard isSuccess else { return .poor }
        
        switch latency {
        case 0..<50:
            return .excellent
        case 50..<100:
            return .good
        case 100..<200:
            return .fair
        default:
            return .poor
        }
    }
}

struct PingStatistics {
    let totalCount: Int
    let successCount: Int
    let failureCount: Int
    let successRate: Double
    let averageLatency: Double
    let minLatency: Double
    let maxLatency: Double
    let standardDeviation: Double
    
    var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate)
    }
    
    var formattedAverageLatency: String {
        return averageLatency > 0 ? String(format: "%.0f ms", averageLatency) : "N/A"
    }
}

enum PingQuality {
    case excellent
    case good
    case fair
    case poor
    
    var displayName: String {
        switch self {
        case .excellent: return "优秀"
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "较差"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
}

enum PingError: LocalizedError {
    case timeout
    case networkUnavailable
    case invalidHost
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "连接超时"
        case .networkUnavailable:
            return "网络不可用"
        case .invalidHost:
            return "无效的主机地址"
        }
    }
}
```

---

## 🖥️ 系统工具

### SystemUtils.swift

**作用**：提供系统相关的工具函数。

```swift
import Foundation
import AppKit
import SystemConfiguration

class SystemUtils {
    
    // MARK: - System Information
    static func getSystemVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    static func getSystemName() -> String {
        return ProcessInfo.processInfo.operatingSystemVersionString
    }
    
    static func getMachineName() -> String {
        return Host.current().localizedName ?? "Unknown"
    }
    
    static func getArchitecture() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
    
    static func getCPUInfo() -> CPUInfo {
        var size = 0
        
        // CPU 品牌
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        
        // CPU 核心数
        var coreCount: Int32 = 0
        size = MemoryLayout<Int32>.size
        sysctlbyname("hw.ncpu", &coreCount, &size, nil, 0)
        
        // CPU 频率
        var frequency: Int64 = 0
        size = MemoryLayout<Int64>.size
        sysctlbyname("hw.cpufrequency_max", &frequency, &size, nil, 0)
        
        return CPUInfo(
            brand: String(cString: brand),
            coreCount: Int(coreCount),
            frequency: frequency
        )
    }
    
    static func getMemoryInfo() -> MemoryInfo {
        var size = 0
        
        // 总内存
        var totalMemory: Int64 = 0
        size = MemoryLayout<Int64>.size
        sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)
        
        // 可用内存
        let pageSize = vm_kernel_page_size
        var vmStat = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        var availableMemory: Int64 = 0
        if result == KERN_SUCCESS {
            availableMemory = Int64(vmStat.free_count + vmStat.inactive_count) * Int64(pageSize)
        }
        
        return MemoryInfo(
            totalMemory: totalMemory,
            availableMemory: availableMemory,
            usedMemory: totalMemory - availableMemory
        )
    }
    
    // MARK: - Application Information
    static func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    static func getBuildNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    static func getAppName() -> String {
        return Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "V2rayU"
    }
    
    static func getBundleIdentifier() -> String {
        return Bundle.main.bundleIdentifier ?? "com.yanue.V2rayU"
    }
    
    // MARK: - System Proxy
    static func getSystemProxySettings() -> SystemProxySettings? {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        
        let httpEnabled = proxySettings[kCFNetworkProxiesHTTPEnable as String] as? Bool ?? false
        let httpHost = proxySettings[kCFNetworkProxiesHTTPProxy as String] as? String
        let httpPort = proxySettings[kCFNetworkProxiesHTTPPort as String] as? Int
        
        let httpsEnabled = proxySettings[kCFNetworkProxiesHTTPSEnable as String] as? Bool ?? false
        let httpsHost = proxySettings[kCFNetworkProxiesHTTPSProxy as String] as? String
        let httpsPort = proxySettings[kCFNetworkProxiesHTTPSPort as String] as? Int
        
        let socksEnabled = proxySettings[kCFNetworkProxiesSOCKSEnable as String] as? Bool ?? false
        let socksHost = proxySettings[kCFNetworkProxiesSOCKSProxy as String] as? String
        let socksPort = proxySettings[kCFNetworkProxiesSOCKSPort as String] as? Int
        
        return SystemProxySettings(
            httpEnabled: httpEnabled,
            httpHost: httpHost,
            httpPort: httpPort,
            httpsEnabled: httpsEnabled,
            httpsHost: httpsHost,
            httpsPort: httpsPort,
            socksEnabled: socksEnabled,
            socksHost: socksHost,
            socksPort: socksPort
        )
    }
    
    // MARK: - Launch at Login
    static func isLaunchAtLoginEnabled() -> Bool {
        let bundleIdentifier = getBundleIdentifier()
        let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems, nil)
        
        guard let loginItemsRef = loginItems?.takeRetainedValue() else {
            return false
        }
        
        let loginItemsArray = LSSharedFileListCopySnapshot(loginItemsRef, nil)
        guard let loginItemsArrayRef = loginItemsArray?.takeRetainedValue() as? [LSSharedFileListItem] else {
            return false
        }
        
        for item in loginItemsArrayRef {
            var resolutionFlags: UInt32 = 0
            let url = LSSharedFileListItemCopyResolvedURL(item, resolutionFlags, nil)
            
            if let urlRef = url?.takeRetainedValue(),
               let bundle = Bundle(url: urlRef as URL),
               bundle.bundleIdentifier == bundleIdentifier {
                return true
            }
        }
        
        return false
    }
    
    static func setLaunchAtLogin(_ enabled: Bool) {
        let bundleIdentifier = getBundleIdentifier()
        let appURL = Bundle.main.bundleURL
        
        let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems, nil)
        guard let loginItemsRef = loginItems?.takeRetainedValue() else {
            return
        }
        
        if enabled {
            // 添加到登录项
            LSSharedFileListInsertItemURL(
                loginItemsRef,
                kLSSharedFileListItemBeforeFirst,
                nil,
                nil,
                appURL as CFURL,
                nil,
                nil
            )
        } else {
            // 从登录项移除
            let loginItemsArray = LSSharedFileListCopySnapshot(loginItemsRef, nil)
            guard let loginItemsArrayRef = loginItemsArray?.takeRetainedValue() as? [LSSharedFileListItem] else {
                return
            }
            
            for item in loginItemsArrayRef {
                var resolutionFlags: UInt32 = 0
                let url = LSSharedFileListItemCopyResolvedURL(item, resolutionFlags, nil)
                
                if let urlRef = url?.takeRetainedValue(),
                   let bundle = Bundle(url: urlRef as URL),
                   bundle.bundleIdentifier == bundleIdentifier {
                    LSSharedFileListItemRemove(loginItemsRef, item)
                    break
                }
            }
        }
    }
    
    // MARK: - Permissions
    static func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    static func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    // MARK: - System Events
    static func openSystemPreferences(pane: String? = nil) {
        if let pane = pane {
            let url = URL(string: "x-apple.systempreferences:\(pane)")
            NSWorkspace.shared.open(url!)
        } else {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
        }
    }
    
    static func openNetworkPreferences() {
        openSystemPreferences(pane: "com.apple.preference.network")
    }
    
    static func openSecurityPreferences() {
        openSystemPreferences(pane: "com.apple.preference.security")
    }
}

// MARK: - Supporting Types
struct CPUInfo {
    let brand: String
    let coreCount: Int
    let frequency: Int64
    
    var formattedFrequency: String {
        let ghz = Double(frequency) / 1_000_000_000
        return String(format: "%.2f GHz", ghz)
    }
}

struct MemoryInfo {
    let totalMemory: Int64
    let availableMemory: Int64
    let usedMemory: Int64
    
    var usagePercentage: Double {
        return Double(usedMemory) / Double(totalMemory) * 100
    }
    
    var formattedTotalMemory: String {
        return NetworkUtils.formatDataSize(totalMemory)
    }
    
    var formattedAvailableMemory: String {
        return NetworkUtils.formatDataSize(availableMemory)
    }
    
    var formattedUsedMemory: String {
        return NetworkUtils.formatDataSize(usedMemory)
    }
}

struct SystemProxySettings {
    let httpEnabled: Bool
    let httpHost: String?
    let httpPort: Int?
    let httpsEnabled: Bool
    let httpsHost: String?
    let httpsPort: Int?
    let socksEnabled: Bool
    let socksHost: String?
    let socksPort: Int?
    
    var hasProxyEnabled: Bool {
        return httpEnabled || httpsEnabled || socksEnabled
    }
}
```

### FileUtils.swift

**作用**：提供文件操作相关的工具函数。

```swift
import Foundation

class FileUtils {
    
    // MARK: - File Operations
    static func fileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    static func createDirectory(at path: String) throws {
        try FileManager.default.createDirectory(
            atPath: path,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    static func deleteFile(at path: String) throws {
        try FileManager.default.removeItem(atPath: path)
    }
    
    static func copyFile(from sourcePath: String, to destinationPath: String) throws {
        try FileManager.default.copyItem(atPath: sourcePath, toPath: destinationPath)
    }
    
    static func moveFile(from sourcePath: String, to destinationPath: String) throws {
        try FileManager.default.moveItem(atPath: sourcePath, toPath: destinationPath)
    }
    
    // MARK: - File Reading/Writing
    static func readString(from path: String, encoding: String.Encoding = .utf8) throws -> String {
        return try String(contentsOfFile: path, encoding: encoding)
    }
    
    static func writeString(_ content: String, to path: String, encoding: String.Encoding = .utf8) throws {
        try content.write(toFile: path, atomically: true, encoding: encoding)
    }
    
    static func readData(from path: String) throws -> Data {
        return try Data(contentsOf: URL(fileURLWithPath: path))
    }
    
    static func writeData(_ data: Data, to path: String) throws {
        try data.write(to: URL(fileURLWithPath: path))
    }
    
    // MARK: - JSON Operations
    static func readJSON<T: Codable>(from path: String, as type: T.Type) throws -> T {
        let data = try readData(from: path)
        return try JSONDecoder().decode(type, from: data)
    }
    
    static func writeJSON<T: Codable>(_ object: T, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(object)
        try writeData(data, to: path)
    }
    
    // MARK: - File Information
    static func getFileSize(at path: String) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
    
    static func getCreationDate(at path: String) -> Date? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.creationDate] as? Date
    }
    
    static func getModificationDate(at path: String) -> Date? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }
    
    // MARK: - Directory Operations
    static func listFiles(in directory: String, withExtension ext: String? = nil) -> [String] {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            return []
        }
        
        if let ext = ext {
            return contents.filter { $0.hasSuffix(".\(ext)") }
        } else {
            return contents
        }
    }
    
    static func getDirectorySize(at path: String) -> Int64 {
        var totalSize: Int64 = 0
        
        guard let enumerator = FileManager.default.enumerator(atPath: path) else {
            return 0
        }
        
        for case let fileName as String in enumerator {
            let filePath = (path as NSString).appendingPathComponent(fileName)
            if let size = getFileSize(at: filePath) {
                totalSize += size
            }
        }
        
        return totalSize
    }
    
    // MARK: - Application Support Directory
    static func getApplicationSupportDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        let appSupportPath = paths.first!
        let appDirectory = (appSupportPath as NSString).appendingPathComponent("V2rayU")
        
        if !fileExists(at: appDirectory) {
            try? createDirectory(at: appDirectory)
        }
        
        return appDirectory
    }
    
    static func getConfigDirectory() -> String {
        let appSupportDir = getApplicationSupportDirectory()
        let configDir = (appSupportDir as NSString).appendingPathComponent("configs")
        
        if !fileExists(at: configDir) {
            try? createDirectory(at: configDir)
        }
        
        return configDir
    }
    
    static func getLogDirectory() -> String {
        let appSupportDir = getApplicationSupportDirectory()
        let logDir = (appSupportDir as NSString).appendingPathComponent("logs")
        
        if !fileExists(at: logDir) {
            try? createDirectory(at: logDir)
        }
        
        return logDir
    }
    
    static func getBackupDirectory() -> String {
        let appSupportDir = getApplicationSupportDirectory()
        let backupDir = (appSupportDir as NSString).appendingPathComponent("backups")
        
        if !fileExists(at: backupDir) {
            try? createDirectory(at: backupDir)
        }
        
        return backupDir
    }
    
    // MARK: - Backup Operations
    static func createBackup(of filePath: String, to backupDirectory: String? = nil) throws -> String {
        let backupDir = backupDirectory ?? getBackupDirectory()
        let fileName = (filePath as NSString).lastPathComponent
        let timestamp = DateFormatter.backupFormatter.string(from: Date())
        let backupFileName = "\(timestamp)_\(fileName)"
        let backupPath = (backupDir as NSString).appendingPathComponent(backupFileName)
        
        try copyFile(from: filePath, to: backupPath)
        return backupPath
    }
    
    static func cleanupOldBackups(in directory: String, keepCount: Int = 10) {
        let files = listFiles(in: directory)
        let sortedFiles = files.compactMap { fileName -> (String, Date)? in
            let filePath = (directory as NSString).appendingPathComponent(fileName)
            guard let date = getCreationDate(at: filePath) else { return nil }
            return (filePath, date)
        }.sorted { $0.1 > $1.1 } // 按日期降序排列
        
        // 删除超出保留数量的文件
        for (filePath, _) in sortedFiles.dropFirst(keepCount) {
            try? deleteFile(at: filePath)
        }
    }
    
    // MARK: - File Validation
    static func isValidJSON(at path: String) -> Bool {
        guard let data = try? readData(from: path) else { return false }
        
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return true
        } catch {
            return false
        }
    }
    
    static func validateFileIntegrity(at path: String, expectedChecksum: String) -> Bool {
        guard let data = try? readData(from: path) else { return false }
        let actualChecksum = CryptoUtils.sha256(data: data)
        return actualChecksum.lowercased() == expectedChecksum.lowercased()
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let backupFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
```

---

## 🔗 相关文档

- [基础工具模块](../modules/base-utilities.md)
- [核心文件详解](core-files.md)
- [处理器文件详解](handler-files.md)
- [应用架构模块](../modules/app-architecture.md)

---

## 📝 总结

工具文件是V2rayU应用的基础支撑，提供了网络、系统、数据处理、UI等各个方面的通用功能。通过模块化的设计和丰富的工具函数，为应用的各个模块提供了强大的基础支持。

### 设计特点

1. **功能完整**：覆盖网络、系统、文件、数据等各个方面
2. **模块化设计**：按功能分类，便于维护和使用
3. **类型安全**：使用Swift的类型系统确保安全性
4. **异步支持**：支持现代Swift的异步编程模式
5. **错误处理**：完善的错误处理和异常管理机制

这些工具文件共同构成了V2rayU应用的基础设施，为应用的稳定运行和功能实现提供了可靠的支撑。
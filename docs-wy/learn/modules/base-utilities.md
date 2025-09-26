# 基础工具模块详解

## 📋 概述

V2rayU的基础工具模块提供了应用程序运行所需的各种工具类和扩展，包括网络服务、系统代理管理、流量监控、延迟测试、配置解析、日志管理等核心功能。这些工具类为上层业务逻辑提供了稳定可靠的基础服务。

## 🏗️ 架构设计

### 1. 工具类分层结构

```swift
// MARK: - 基础工具协议
protocol UtilityProtocol {
    associatedtype Configuration
    associatedtype Result
    
    func configure(_ config: Configuration)
    func execute() async throws -> Result
    func cleanup()
}

// MARK: - 基础工具类
class BaseUtility: UtilityProtocol {
    typealias Configuration = [String: Any]
    typealias Result = Any
    
    private var isConfigured = false
    private var logger: Logger
    
    init(logger: Logger = Logger.shared) {
        self.logger = logger
    }
    
    func configure(_ config: Configuration) {
        // 基础配置逻辑
        isConfigured = true
        logger.info("\(type(of: self)) configured")
    }
    
    func execute() async throws -> Result {
        guard isConfigured else {
            throw UtilityError.notConfigured
        }
        // 基础执行逻辑
        return ()
    }
    
    func cleanup() {
        isConfigured = false
        logger.info("\(type(of: self)) cleaned up")
    }
}

// MARK: - 工具错误类型
enum UtilityError: LocalizedError {
    case notConfigured
    case invalidConfiguration
    case executionFailed(String)
    case networkError(Error)
    case systemError(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "工具未配置"
        case .invalidConfiguration:
            return "配置无效"
        case .executionFailed(let message):
            return "执行失败: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .systemError(let message):
            return "系统错误: \(message)"
        }
    }
}
```

## 🌐 网络服务工具

### 1. 网络服务实现

```swift
// MARK: - 网络服务协议
protocol NetworkServiceProtocol {
    func testConnection(to host: String, port: Int, timeout: TimeInterval) async throws -> Bool
    func downloadSubscription(from url: String) async throws -> String
    func measureLatency(to host: String, port: Int) async throws -> Int
    func checkInternetConnectivity() async throws -> Bool
}

// MARK: - 网络服务实现
class NetworkServiceImpl: NetworkServiceProtocol {
    private let session: URLSession
    private let logger = Logger.shared
    
    init(configuration: URLSessionConfiguration = .default) {
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - 测试连接
    func testConnection(to host: String, port: Int, timeout: TimeInterval = 5.0) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue.global(qos: .userInitiated)
            
            queue.async {
                var hints = addrinfo(
                    ai_flags: AI_NUMERICSERV,
                    ai_family: AF_UNSPEC,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: 0,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )
                
                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(host, String(port), &hints, &result)
                
                guard status == 0, let addr = result else {
                    freeaddrinfo(result)
                    continuation.resume(returning: false)
                    return
                }
                
                defer { freeaddrinfo(result) }
                
                let sock = socket(addr.pointee.ai_family, addr.pointee.ai_socktype, addr.pointee.ai_protocol)
                guard sock >= 0 else {
                    continuation.resume(returning: false)
                    return
                }
                
                defer { close(sock) }
                
                // 设置非阻塞模式
                var flags = fcntl(sock, F_GETFL, 0)
                fcntl(sock, F_SETFL, flags | O_NONBLOCK)
                
                // 尝试连接
                let connectResult = connect(sock, addr.pointee.ai_addr, addr.pointee.ai_addrlen)
                
                if connectResult == 0 {
                    continuation.resume(returning: true)
                    return
                }
                
                if errno == EINPROGRESS {
                    // 使用select等待连接完成
                    var writeSet = fd_set()
                    FD_ZERO(&writeSet)
                    FD_SET(sock, &writeSet)
                    
                    var timeout = timeval(
                        tv_sec: Int(timeout),
                        tv_usec: Int((timeout.truncatingRemainder(dividingBy: 1)) * 1_000_000)
                    )
                    
                    let selectResult = select(sock + 1, nil, &writeSet, nil, &timeout)
                    
                    if selectResult > 0 && FD_ISSET(sock, &writeSet) {
                        var error: Int32 = 0
                        var errorSize = socklen_t(MemoryLayout<Int32>.size)
                        
                        if getsockopt(sock, SOL_SOCKET, SO_ERROR, &error, &errorSize) == 0 && error == 0 {
                            continuation.resume(returning: true)
                        } else {
                            continuation.resume(returning: false)
                        }
                    } else {
                        continuation.resume(returning: false)
                    }
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    // MARK: - 下载订阅
    func downloadSubscription(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw UtilityError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        request.setValue("V2rayU/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UtilityError.networkError(URLError(.badServerResponse))
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw UtilityError.networkError(URLError(.badServerResponse))
            }
            
            guard let content = String(data: data, encoding: .utf8) else {
                throw UtilityError.executionFailed("无法解码响应数据")
            }
            
            logger.info("订阅下载成功: \(urlString)")
            return content
            
        } catch {
            logger.error("订阅下载失败: \(error)")
            throw UtilityError.networkError(error)
        }
    }
    
    // MARK: - 测量延迟
    func measureLatency(to host: String, port: Int) async throws -> Int {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let isConnected = try await testConnection(to: host, port: port, timeout: 3.0)
        
        guard isConnected else {
            throw UtilityError.executionFailed("连接失败")
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let latency = Int((endTime - startTime) * 1000)
        
        logger.debug("延迟测试: \(host):\(port) = \(latency)ms")
        return latency
    }
    
    // MARK: - 检查网络连接
    func checkInternetConnectivity() async throws -> Bool {
        let testHosts = [
            ("8.8.8.8", 53),
            ("1.1.1.1", 53),
            ("114.114.114.114", 53)
        ]
        
        for (host, port) in testHosts {
            do {
                if try await testConnection(to: host, port: port, timeout: 2.0) {
                    return true
                }
            } catch {
                continue
            }
        }
        
        return false
    }
}
```

### 2. 延迟测试工具

```swift
// MARK: - 延迟测试器
class PingTester {
    private let networkService: NetworkServiceProtocol
    private let logger = Logger.shared
    
    init(networkService: NetworkServiceProtocol = NetworkServiceImpl()) {
        self.networkService = networkService
    }
    
    // MARK: - 单个代理测试
    func testProxy(_ proxy: ProxyConfig) async throws -> Int {
        logger.info("开始测试代理延迟: \(proxy.name)")
        
        do {
            let latency = try await networkService.measureLatency(
                to: proxy.serverAddress,
                port: proxy.serverPort
            )
            
            logger.info("代理延迟测试完成: \(proxy.name) = \(latency)ms")
            return latency
            
        } catch {
            logger.error("代理延迟测试失败: \(proxy.name) - \(error)")
            throw error
        }
    }
    
    // MARK: - 批量测试
    func testProxies(_ proxies: [ProxyConfig]) async throws -> [ProxyConfig.ID: Int] {
        logger.info("开始批量测试代理延迟，共 \(proxies.count) 个")
        
        var results: [ProxyConfig.ID: Int] = [:]
        
        // 使用TaskGroup进行并发测试
        await withTaskGroup(of: (ProxyConfig.ID, Result<Int, Error>).self) { group in
            for proxy in proxies {
                group.addTask {
                    let result = await Result {
                        try await self.testProxy(proxy)
                    }
                    return (proxy.id, result)
                }
            }
            
            for await (proxyId, result) in group {
                switch result {
                case .success(let latency):
                    results[proxyId] = latency
                case .failure(let error):
                    logger.error("代理测试失败: \(proxyId) - \(error)")
                }
            }
        }
        
        logger.info("批量延迟测试完成，成功 \(results.count)/\(proxies.count) 个")
        return results
    }
    
    // MARK: - 连续测试
    func continuousTest(
        _ proxy: ProxyConfig,
        interval: TimeInterval = 5.0,
        maxTests: Int = 10
    ) -> AsyncStream<Int> {
        return AsyncStream { continuation in
            Task {
                var testCount = 0
                
                while testCount < maxTests {
                    do {
                        let latency = try await testProxy(proxy)
                        continuation.yield(latency)
                        testCount += 1
                        
                        if testCount < maxTests {
                            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                        }
                    } catch {
                        logger.error("连续测试失败: \(error)")
                        break
                    }
                }
                
                continuation.finish()
            }
        }
    }
}
```

## 🔧 系统代理管理

### 1. 系统代理服务

```swift
// MARK: - 系统代理协议
protocol SystemProxyServiceProtocol {
    func enableSystemProxy(host: String, port: Int) async throws
    func disableSystemProxy() async throws
    func getSystemProxyStatus() async throws -> SystemProxyStatus
    func updateProxySettings(_ settings: ProxySettings) async throws
}

// MARK: - 系统代理状态
struct SystemProxyStatus {
    let isEnabled: Bool
    let httpProxy: ProxyInfo?
    let httpsProxy: ProxyInfo?
    let socksProxy: ProxyInfo?
    let excludeList: [String]
    
    struct ProxyInfo {
        let host: String
        let port: Int
        let isEnabled: Bool
    }
}

// MARK: - 代理设置
struct ProxySettings {
    let httpProxy: ProxyInfo?
    let httpsProxy: ProxyInfo?
    let socksProxy: ProxyInfo?
    let excludeList: [String]
    let autoConfigURL: String?
    
    struct ProxyInfo {
        let host: String
        let port: Int
        let username: String?
        let password: String?
    }
}

// MARK: - 系统代理服务实现
class SystemProxyServiceImpl: SystemProxyServiceProtocol {
    private let logger = Logger.shared
    private var currentSettings: ProxySettings?
    
    // MARK: - 启用系统代理
    func enableSystemProxy(host: String, port: Int) async throws {
        logger.info("启用系统代理: \(host):\(port)")
        
        let script = """
        tell application "System Events"
            tell network preferences
                set activeServices to (current location's services whose active is true)
                repeat with aService in activeServices
                    tell aService
                        set proxies to proxies
                        tell proxies
                            set HTTP enabled to true
                            set HTTP server to "\(host)"
                            set HTTP port to \(port)
                            set HTTPS enabled to true
                            set HTTPS server to "\(host)"
                            set HTTPS port to \(port)
                            set SOCKS enabled to true
                            set SOCKS server to "\(host)"
                            set SOCKS port to \(port)
                        end tell
                    end tell
                end repeat
            end tell
        end tell
        """
        
        try await executeAppleScript(script)
        
        currentSettings = ProxySettings(
            httpProxy: ProxySettings.ProxyInfo(host: host, port: port, username: nil, password: nil),
            httpsProxy: ProxySettings.ProxyInfo(host: host, port: port, username: nil, password: nil),
            socksProxy: ProxySettings.ProxyInfo(host: host, port: port, username: nil, password: nil),
            excludeList: ["127.0.0.1", "localhost", "*.local"],
            autoConfigURL: nil
        )
        
        logger.info("系统代理启用成功")
    }
    
    // MARK: - 禁用系统代理
    func disableSystemProxy() async throws {
        logger.info("禁用系统代理")
        
        let script = """
        tell application "System Events"
            tell network preferences
                set activeServices to (current location's services whose active is true)
                repeat with aService in activeServices
                    tell aService
                        set proxies to proxies
                        tell proxies
                            set HTTP enabled to false
                            set HTTPS enabled to false
                            set SOCKS enabled to false
                        end tell
                    end tell
                end repeat
            end tell
        end tell
        """
        
        try await executeAppleScript(script)
        currentSettings = nil
        
        logger.info("系统代理禁用成功")
    }
    
    // MARK: - 获取系统代理状态
    func getSystemProxyStatus() async throws -> SystemProxyStatus {
        let script = """
        tell application "System Events"
            tell network preferences
                set activeService to (first service whose active is true)
                tell activeService
                    set proxies to proxies
                    tell proxies
                        set httpEnabled to HTTP enabled
                        set httpServer to HTTP server
                        set httpPort to HTTP port
                        set httpsEnabled to HTTPS enabled
                        set httpsServer to HTTPS server
                        set httpsPort to HTTPS port
                        set socksEnabled to SOCKS enabled
                        set socksServer to SOCKS server
                        set socksPort to SOCKS port
                        
                        return {httpEnabled, httpServer, httpPort, httpsEnabled, httpsServer, httpsPort, socksEnabled, socksServer, socksPort}
                    end tell
                end tell
            end tell
        end tell
        """
        
        let result = try await executeAppleScript(script)
        return parseProxyStatus(result)
    }
    
    // MARK: - 更新代理设置
    func updateProxySettings(_ settings: ProxySettings) async throws {
        logger.info("更新代理设置")
        
        // 构建AppleScript
        var script = """
        tell application "System Events"
            tell network preferences
                set activeServices to (current location's services whose active is true)
                repeat with aService in activeServices
                    tell aService
                        set proxies to proxies
                        tell proxies
        """
        
        if let httpProxy = settings.httpProxy {
            script += """
                            set HTTP enabled to true
                            set HTTP server to "\(httpProxy.host)"
                            set HTTP port to \(httpProxy.port)
            """
        } else {
            script += "                            set HTTP enabled to false\n"
        }
        
        if let httpsProxy = settings.httpsProxy {
            script += """
                            set HTTPS enabled to true
                            set HTTPS server to "\(httpsProxy.host)"
                            set HTTPS port to \(httpsProxy.port)
            """
        } else {
            script += "                            set HTTPS enabled to false\n"
        }
        
        if let socksProxy = settings.socksProxy {
            script += """
                            set SOCKS enabled to true
                            set SOCKS server to "\(socksProxy.host)"
                            set SOCKS port to \(socksProxy.port)
            """
        } else {
            script += "                            set SOCKS enabled to false\n"
        }
        
        script += """
                        end tell
                    end tell
                end repeat
            end tell
        end tell
        """
        
        try await executeAppleScript(script)
        currentSettings = settings
        
        logger.info("代理设置更新成功")
    }
    
    // MARK: - 执行AppleScript
    private func executeAppleScript(_ script: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let result = appleScript?.executeAndReturnError(&error)
                
                if let error = error {
                    continuation.resume(throwing: UtilityError.systemError(error.description))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    // MARK: - 解析代理状态
    private func parseProxyStatus(_ result: String) -> SystemProxyStatus {
        // 解析AppleScript返回的结果
        // 这里简化处理，实际需要解析具体的返回值
        return SystemProxyStatus(
            isEnabled: currentSettings != nil,
            httpProxy: currentSettings?.httpProxy.map {
                SystemProxyStatus.ProxyInfo(host: $0.host, port: $0.port, isEnabled: true)
            },
            httpsProxy: currentSettings?.httpsProxy.map {
                SystemProxyStatus.ProxyInfo(host: $0.host, port: $0.port, isEnabled: true)
            },
            socksProxy: currentSettings?.socksProxy.map {
                SystemProxyStatus.ProxyInfo(host: $0.host, port: $0.port, isEnabled: true)
            },
            excludeList: currentSettings?.excludeList ?? []
        )
    }
}
```

## 📊 流量监控工具

### 1. 流量监控器

```swift
// MARK: - 流量监控协议
protocol TrafficMonitorProtocol {
    func startMonitoring()
    func stopMonitoring()
    func getCurrentStats() -> TrafficStats
    func resetStats()
    var statsPublisher: AnyPublisher<TrafficStats, Never> { get }
}

// MARK: - 流量统计数据
struct TrafficStats {
    let uploadBytes: Int64
    let downloadBytes: Int64
    let uploadSpeed: Int64  // bytes per second
    let downloadSpeed: Int64  // bytes per second
    let sessionStartTime: Date
    let lastUpdateTime: Date
    
    var totalBytes: Int64 {
        return uploadBytes + downloadBytes
    }
    
    var sessionDuration: TimeInterval {
        return lastUpdateTime.timeIntervalSince(sessionStartTime)
    }
}

// MARK: - 流量监控器实现
class TrafficMonitor: TrafficMonitorProtocol {
    private let logger = Logger.shared
    private var isMonitoring = false
    private var monitoringTimer: Timer?
    private var lastUploadBytes: Int64 = 0
    private var lastDownloadBytes: Int64 = 0
    private var sessionStartTime = Date()
    
    private let statsSubject = CurrentValueSubject<TrafficStats, Never>(
        TrafficStats(
            uploadBytes: 0,
            downloadBytes: 0,
            uploadSpeed: 0,
            downloadSpeed: 0,
            sessionStartTime: Date(),
            lastUpdateTime: Date()
        )
    )
    
    var statsPublisher: AnyPublisher<TrafficStats, Never> {
        return statsSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 开始监控
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        logger.info("开始流量监控")
        isMonitoring = true
        sessionStartTime = Date()
        
        // 重置初始值
        let initialStats = getSystemNetworkStats()
        lastUploadBytes = initialStats.upload
        lastDownloadBytes = initialStats.download
        
        // 启动定时器，每秒更新一次
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    // MARK: - 停止监控
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        logger.info("停止流量监控")
        isMonitoring = false
        
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    // MARK: - 获取当前统计
    func getCurrentStats() -> TrafficStats {
        return statsSubject.value
    }
    
    // MARK: - 重置统计
    func resetStats() {
        logger.info("重置流量统计")
        sessionStartTime = Date()
        
        let initialStats = getSystemNetworkStats()
        lastUploadBytes = initialStats.upload
        lastDownloadBytes = initialStats.download
        
        let resetStats = TrafficStats(
            uploadBytes: 0,
            downloadBytes: 0,
            uploadSpeed: 0,
            downloadSpeed: 0,
            sessionStartTime: sessionStartTime,
            lastUpdateTime: Date()
        )
        
        statsSubject.send(resetStats)
    }
    
    // MARK: - 更新统计数据
    private func updateStats() {
        let currentStats = getSystemNetworkStats()
        let currentTime = Date()
        
        let uploadDiff = currentStats.upload - lastUploadBytes
        let downloadDiff = currentStats.download - lastDownloadBytes
        
        let currentTrafficStats = statsSubject.value
        
        let newStats = TrafficStats(
            uploadBytes: currentTrafficStats.uploadBytes + uploadDiff,
            downloadBytes: currentTrafficStats.downloadBytes + downloadDiff,
            uploadSpeed: uploadDiff,  // 每秒字节数
            downloadSpeed: downloadDiff,  // 每秒字节数
            sessionStartTime: sessionStartTime,
            lastUpdateTime: currentTime
        )
        
        lastUploadBytes = currentStats.upload
        lastDownloadBytes = currentStats.download
        
        statsSubject.send(newStats)
    }
    
    // MARK: - 获取系统网络统计
    private func getSystemNetworkStats() -> (upload: Int64, download: Int64) {
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        var upload: Int64 = 0
        var download: Int64 = 0
        
        guard getifaddrs(&ifaddrs) == 0 else {
            return (0, 0)
        }
        
        defer { freeifaddrs(ifaddrs) }
        
        var ptr = ifaddrs
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let addr = ptr?.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            
            let name = String(cString: ptr!.pointee.ifa_name)
            
            // 只统计活跃的网络接口
            if name.hasPrefix("en") || name.hasPrefix("pdp_ip") {
                let data = unsafeBitCast(addr, to: UnsafeMutablePointer<sockaddr_dl>.self)
                
                if let stats = ptr?.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    upload += Int64(stats.pointee.ifi_obytes)
                    download += Int64(stats.pointee.ifi_ibytes)
                }
            }
        }
        
        return (upload, download)
    }
}
```

## 📝 配置解析工具

### 1. 配置解析器

```swift
// MARK: - 配置解析协议
protocol ConfigParserProtocol {
    func parseSubscriptionContent(_ content: String) throws -> [ProxyConfig]
    func parseProxyURL(_ url: String) throws -> ProxyConfig
    func exportProxies(_ proxies: [ProxyConfig]) throws -> String
    func parseClashConfig(_ content: String) throws -> [ProxyConfig]
    func exportClashConfig(_ proxies: [ProxyConfig]) throws -> String
}

// MARK: - 配置解析器实现
class ConfigParser: ConfigParserProtocol {
    private let logger = Logger.shared
    private let protocolManager = ProtocolManager.shared
    
    // MARK: - 解析订阅内容
    func parseSubscriptionContent(_ content: String) throws -> [ProxyConfig] {
        logger.info("开始解析订阅内容")
        
        var proxies: [ProxyConfig] = []
        
        // 尝试Base64解码
        let decodedContent: String
        if let data = Data(base64Encoded: content),
           let decoded = String(data: data, encoding: .utf8) {
            decodedContent = decoded
        } else {
            decodedContent = content
        }
        
        // 按行分割
        let lines = decodedContent.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        for line in lines {
            do {
                let proxy = try parseProxyURL(line)
                proxies.append(proxy)
            } catch {
                logger.warning("解析代理URL失败: \(line) - \(error)")
                continue
            }
        }
        
        logger.info("订阅解析完成，共解析 \(proxies.count) 个代理")
        return proxies
    }
    
    // MARK: - 解析代理URL
    func parseProxyURL(_ url: String) throws -> ProxyConfig {
        guard let urlComponents = URLComponents(string: url) else {
            throw ConfigParserError.invalidURL
        }
        
        guard let scheme = urlComponents.scheme else {
            throw ConfigParserError.unsupportedProtocol
        }
        
        switch scheme.lowercased() {
        case "vmess":
            return try parseVMessURL(url)
        case "vless":
            return try parseVLessURL(url)
        case "ss":
            return try parseShadowsocksURL(url)
        case "trojan":
            return try parseTrojanURL(url)
        default:
            throw ConfigParserError.unsupportedProtocol
        }
    }
    
    // MARK: - 导出代理配置
    func exportProxies(_ proxies: [ProxyConfig]) throws -> String {
        logger.info("导出 \(proxies.count) 个代理配置")
        
        var urls: [String] = []
        
        for proxy in proxies {
            do {
                let url = try protocolManager.generateShareURL(proxy)
                urls.append(url)
            } catch {
                logger.warning("导出代理失败: \(proxy.name) - \(error)")
                continue
            }
        }
        
        let content = urls.joined(separator: "\n")
        let base64Content = Data(content.utf8).base64EncodedString()
        
        logger.info("代理配置导出完成")
        return base64Content
    }
    
    // MARK: - 解析Clash配置
    func parseClashConfig(_ content: String) throws -> [ProxyConfig] {
        logger.info("开始解析Clash配置")
        
        guard let data = content.data(using: .utf8) else {
            throw ConfigParserError.invalidFormat
        }
        
        do {
            let yaml = try Yams.load(yaml: content) as? [String: Any]
            guard let proxiesData = yaml?["proxies"] as? [[String: Any]] else {
                throw ConfigParserError.invalidFormat
            }
            
            var proxies: [ProxyConfig] = []
            
            for proxyData in proxiesData {
                do {
                    let proxy = try parseClashProxy(proxyData)
                    proxies.append(proxy)
                } catch {
                    logger.warning("解析Clash代理失败: \(error)")
                    continue
                }
            }
            
            logger.info("Clash配置解析完成，共解析 \(proxies.count) 个代理")
            return proxies
            
        } catch {
            logger.error("Clash配置解析失败: \(error)")
            throw ConfigParserError.parseError(error)
        }
    }
    
    // MARK: - 导出Clash配置
    func exportClashConfig(_ proxies: [ProxyConfig]) throws -> String {
        logger.info("导出Clash配置，共 \(proxies.count) 个代理")
        
        var clashProxies: [[String: Any]] = []
        
        for proxy in proxies {
            let clashProxy = convertToClashProxy(proxy)
            clashProxies.append(clashProxy)
        }
        
        let clashConfig: [String: Any] = [
            "port": 7890,
            "socks-port": 7891,
            "allow-lan": false,
            "mode": "rule",
            "log-level": "info",
            "external-controller": "127.0.0.1:9090",
            "proxies": clashProxies,
            "proxy-groups": [
                [
                    "name": "Proxy",
                    "type": "select",
                    "proxies": proxies.map { $0.name }
                ]
            ],
            "rules": [
                "MATCH,Proxy"
            ]
        ]
        
        do {
            let yamlString = try Yams.dump(object: clashConfig)
            logger.info("Clash配置导出完成")
            return yamlString
        } catch {
            logger.error("Clash配置导出失败: \(error)")
            throw ConfigParserError.exportError(error)
        }
    }
    
    // MARK: - 私有方法
    private func parseVMessURL(_ url: String) throws -> ProxyConfig {
        // VMess URL解析实现
        return try VMessProtocol().parseURL(url)
    }
    
    private func parseVLessURL(_ url: String) throws -> ProxyConfig {
        // VLess URL解析实现
        return try VLessProtocol().parseURL(url)
    }
    
    private func parseShadowsocksURL(_ url: String) throws -> ProxyConfig {
        // Shadowsocks URL解析实现
        return try ShadowsocksProtocol().parseURL(url)
    }
    
    private func parseTrojanURL(_ url: String) throws -> ProxyConfig {
        // Trojan URL解析实现
        return try TrojanProtocol().parseURL(url)
    }
    
    private func parseClashProxy(_ data: [String: Any]) throws -> ProxyConfig {
        // Clash代理解析实现
        guard let name = data["name"] as? String,
              let type = data["type"] as? String,
              let server = data["server"] as? String,
              let port = data["port"] as? Int else {
            throw ConfigParserError.invalidFormat
        }
        
        // 根据类型创建相应的代理配置
        switch type.lowercased() {
        case "vmess":
            return try createVMessFromClash(data)
        case "vless":
            return try createVLessFromClash(data)
        case "ss":
            return try createShadowsocksFromClash(data)
        case "trojan":
            return try createTrojanFromClash(data)
        default:
            throw ConfigParserError.unsupportedProtocol
        }
    }
    
    private func convertToClashProxy(_ proxy: ProxyConfig) -> [String: Any] {
        // 转换为Clash格式的代理配置
        var clashProxy: [String: Any] = [
            "name": proxy.name,
            "server": proxy.serverAddress,
            "port": proxy.serverPort
        ]
        
        switch proxy.protocolType {
        case .vmess:
            clashProxy["type"] = "vmess"
            clashProxy["uuid"] = proxy.userId
            clashProxy["alterId"] = proxy.alterId
            clashProxy["cipher"] = proxy.security
            
        case .vless:
            clashProxy["type"] = "vless"
            clashProxy["uuid"] = proxy.userId
            clashProxy["flow"] = proxy.flow
            
        case .shadowsocks:
            clashProxy["type"] = "ss"
            clashProxy["cipher"] = proxy.method
            clashProxy["password"] = proxy.password
            
        case .trojan:
            clashProxy["type"] = "trojan"
            clashProxy["password"] = proxy.password
            
        default:
            break
        }
        
        return clashProxy
    }
    
    // 其他私有方法实现...
}

// MARK: - 配置解析错误
enum ConfigParserError: LocalizedError {
    case invalidURL
    case invalidFormat
    case unsupportedProtocol
    case parseError(Error)
    case exportError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL格式"
        case .invalidFormat:
            return "无效的配置格式"
        case .unsupportedProtocol:
            return "不支持的协议类型"
        case .parseError(let error):
            return "解析错误: \(error.localizedDescription)"
        case .exportError(let error):
            return "导出错误: \(error.localizedDescription)"
        }
    }
}
```

## 📚 相关文档

- [应用架构模块](app-architecture.md)
- [数据库层模块](database-layer.md)
- [处理器层模块](handler-layer.md)
- [协议层模块](protocol-layer.md)
- [视图层模块](view-layer.md)

---

*本文档详细介绍了V2rayU基础工具模块的设计与实现，为开发者提供了完整的工具类开发解决方案。*U基础工具模块的设计与实现，为开发者提供了完整的工具类开发解决方案。*
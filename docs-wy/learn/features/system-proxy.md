# 系统代理功能详解

## 📋 概述

系统代理功能是V2rayU的核心特性之一，允许应用程序自动配置macOS系统的网络代理设置，实现全局代理或特定应用的代理转发。该功能通过与系统网络配置的深度集成，为用户提供无缝的代理体验。

## 🎯 功能特性

### 1. 支持的代理类型
- **HTTP代理**: 标准HTTP代理协议
- **HTTPS代理**: 加密的HTTPS代理协议
- **SOCKS5代理**: 更灵活的SOCKS5代理协议
- **PAC代理**: 基于PAC脚本的自动代理配置
- **自动代理**: 根据规则自动选择代理方式

### 2. 核心功能
- ✅ 启用/禁用系统代理
- ✅ 自动检测网络接口
- ✅ 支持多网络服务配置
- ✅ PAC脚本生成和管理
- ✅ 代理规则配置
- ✅ 绕过代理列表管理
- ✅ 代理状态监控
- ✅ 自动恢复原始设置

## 🏗️ 架构设计

### 1. 组件关系图

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ SystemProxyView │────│SystemProxyHandler│──│SystemProxyService│
│   (UI Layer)    │    │ (Business Logic)│    │  (System API)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ ProxyStatusView │    │ PACGenerator    │    │ NetworkService  │
│ ProxyRulesView  │    │ RuleManager     │    │ AppleScript     │
│ BypassListView  │    │ StatusMonitor   │    │ SystemConfig    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 2. 数据流向

```
User Action → SystemProxyHandler → SystemProxyService → macOS Network Settings
     ↓               ↓                    ↓                    ↓
UI Update ← Status Monitor ← Network Events ← System Notifications
```

## 💻 核心实现

### 1. 系统代理配置模型

```swift
// MARK: - 系统代理配置
struct SystemProxyConfig: Codable, Equatable {
    var isEnabled: Bool
    var proxyType: ProxyType
    var httpProxy: ProxySettings?
    var httpsProxy: ProxySettings?
    var socksProxy: ProxySettings?
    var pacURL: String?
    var pacScript: String?
    var bypassList: [String]
    var autoConfigEnabled: Bool
    
    init() {
        self.isEnabled = false
        self.proxyType = .http
        self.bypassList = [
            "127.0.0.1",
            "localhost",
            "*.local",
            "169.254/16",
            "224.0.0.0/4",
            "240.0.0.0/4"
        ]
        self.autoConfigEnabled = false
    }
}

// MARK: - 代理设置
struct ProxySettings: Codable, Equatable {
    let host: String
    let port: Int
    let username: String?
    let password: String?
    let enabled: Bool
    
    init(host: String, port: Int, username: String? = nil, password: String? = nil, enabled: Bool = true) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.enabled = enabled
    }
}

// MARK: - 代理类型
enum ProxyType: String, CaseIterable, Codable {
    case http = "HTTP"
    case https = "HTTPS"
    case socks5 = "SOCKS5"
    case pac = "PAC"
    case auto = "AUTO"
    
    var displayName: String {
        switch self {
        case .http: return "HTTP代理"
        case .https: return "HTTPS代理"
        case .socks5: return "SOCKS5代理"
        case .pac: return "PAC代理"
        case .auto: return "自动代理"
        }
    }
    
    var defaultPort: Int {
        switch self {
        case .http, .https: return 8080
        case .socks5: return 1080
        case .pac, .auto: return 0
        }
    }
}

// MARK: - 网络服务信息
struct NetworkService: Identifiable, Equatable {
    let id: String
    let name: String
    let type: String
    let isActive: Bool
    let hardwarePort: String?
    
    init(id: String, name: String, type: String, isActive: Bool, hardwarePort: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.isActive = isActive
        self.hardwarePort = hardwarePort
    }
}

// MARK: - 代理状态
enum ProxyStatus {
    case disabled
    case enabled(ProxyType)
    case error(Error)
    case unknown
    
    var isEnabled: Bool {
        if case .enabled = self {
            return true
        }
        return false
    }
    
    var displayText: String {
        switch self {
        case .disabled:
            return "已禁用"
        case .enabled(let type):
            return "已启用 (\(type.displayName))"
        case .error(let error):
            return "错误: \(error.localizedDescription)"
        case .unknown:
            return "未知状态"
        }
    }
}
```

### 2. 系统代理服务实现

```swift
// MARK: - 系统代理服务协议
protocol SystemProxyServiceProtocol {
    func enableProxy(_ config: SystemProxyConfig) async throws
    func disableProxy() async throws
    func getCurrentStatus() async throws -> ProxyStatus
    func getNetworkServices() async throws -> [NetworkService]
    func testProxyConnection(_ settings: ProxySettings) async throws -> Bool
    func generatePACScript(_ rules: [ProxyRule]) -> String
}

// MARK: - 系统代理服务实现
class SystemProxyService: SystemProxyServiceProtocol {
    private let logger = Logger(subsystem: "V2rayU", category: "SystemProxy")
    private let queue = DispatchQueue(label: "system.proxy", qos: .userInitiated)
    
    // MARK: - 公共方法
    
    /// 启用系统代理
    func enableProxy(_ config: SystemProxyConfig) async throws {
        logger.info("启用系统代理: \(config.proxyType.rawValue)")
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    // 获取网络服务列表
                    let services = try self.getActiveNetworkServices()
                    
                    for service in services {
                        try self.configureProxyForService(service, config: config)
                    }
                    
                    self.logger.info("系统代理启用成功")
                    continuation.resume()
                } catch {
                    self.logger.error("启用系统代理失败: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 禁用系统代理
    func disableProxy() async throws {
        logger.info("禁用系统代理")
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let services = try self.getActiveNetworkServices()
                    
                    for service in services {
                        try self.disableProxyForService(service)
                    }
                    
                    self.logger.info("系统代理禁用成功")
                    continuation.resume()
                } catch {
                    self.logger.error("禁用系统代理失败: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 获取当前代理状态
    func getCurrentStatus() async throws -> ProxyStatus {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let status = try self.checkCurrentProxyStatus()
                    continuation.resume(returning: status)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 获取网络服务列表
    func getNetworkServices() async throws -> [NetworkService] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let services = try self.getAllNetworkServices()
                    continuation.resume(returning: services)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 测试代理连接
    func testProxyConnection(_ settings: ProxySettings) async throws -> Bool {
        let testURL = URL(string: "http://www.google.com")!
        var request = URLRequest(url: testURL)
        request.timeoutInterval = 10
        
        // 配置代理
        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable: true,
            kCFNetworkProxiesHTTPProxy: settings.host,
            kCFNetworkProxiesHTTPPort: settings.port
        ]
        
        let session = URLSession(configuration: config)
        
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            logger.error("代理连接测试失败: \(error)")
            return false
        }
    }
    
    /// 生成PAC脚本
    func generatePACScript(_ rules: [ProxyRule]) -> String {
        var script = """
        function FindProxyForURL(url, host) {
            // 本地地址直连
            if (isPlainHostName(host) ||
                shExpMatch(host, "*.local") ||
                isInNet(dnsResolve(host), "10.0.0.0", "255.0.0.0") ||
                isInNet(dnsResolve(host), "172.16.0.0", "255.240.0.0") ||
                isInNet(dnsResolve(host), "192.168.0.0", "255.255.0.0") ||
                isInNet(dnsResolve(host), "127.0.0.0", "255.255.255.0")) {
                return "DIRECT";
            }
            
        """
        
        // 添加自定义规则
        for rule in rules {
            switch rule.type {
            case .domain:
                script += """
                    // 域名规则: \(rule.pattern)
                    if (shExpMatch(host, "\(rule.pattern)")) {
                        return "\(rule.action.pacAction)";
                    }
                    
                """
            case .domainSuffix:
                script += """
                    // 域名后缀规则: \(rule.pattern)
                    if (dnsDomainIs(host, "\(rule.pattern)")) {
                        return "\(rule.action.pacAction)";
                    }
                    
                """
            case .domainKeyword:
                script += """
                    // 域名关键词规则: \(rule.pattern)
                    if (host.indexOf("\(rule.pattern)") >= 0) {
                        return "\(rule.action.pacAction)";
                    }
                    
                """
            case .ipCidr:
                let components = rule.pattern.split(separator: "/")
                if components.count == 2 {
                    let ip = String(components[0])
                    let mask = String(components[1])
                    script += """
                        // IP CIDR规则: \(rule.pattern)
                        if (isInNet(dnsResolve(host), "\(ip)", "\(cidrToMask(mask))")) {
                            return "\(rule.action.pacAction)";
                        }
                        
                    """
                }
            }
        }
        
        script += """
            // 默认规则
            return "DIRECT";
        }
        
        function cidrToMask(cidr) {
            var mask = parseInt(cidr);
            var result = [];
            for (var i = 0; i < 4; i++) {
                if (mask >= 8) {
                    result.push(255);
                    mask -= 8;
                } else if (mask > 0) {
                    result.push(256 - Math.pow(2, 8 - mask));
                    mask = 0;
                } else {
                    result.push(0);
                }
            }
            return result.join(".");
        }
        """
        
        return script
    }
    
    // MARK: - 私有方法
    
    private func getActiveNetworkServices() throws -> [NetworkService] {
        let script = """
        tell application "System Events"
            tell network preferences
                set activeServices to {}
                repeat with aService in services
                    if active of aService is true then
                        set end of activeServices to (id of aService & "|" & name of aService)
                    end if
                end repeat
                return activeServices
            end tell
        end tell
        """
        
        let result = try executeAppleScript(script)
        let serviceStrings = result.components(separatedBy: ", ")
        
        return serviceStrings.compactMap { serviceString in
            let components = serviceString.components(separatedBy: "|")
            guard components.count == 2 else { return nil }
            
            return NetworkService(
                id: components[0],
                name: components[1],
                type: "Unknown",
                isActive: true
            )
        }
    }
    
    private func getAllNetworkServices() throws -> [NetworkService] {
        let script = """
        tell application "System Events"
            tell network preferences
                set allServices to {}
                repeat with aService in services
                    set serviceInfo to (id of aService & "|" & name of aService & "|" & (active of aService as string))
                    set end of allServices to serviceInfo
                end repeat
                return allServices
            end tell
        end tell
        """
        
        let result = try executeAppleScript(script)
        let serviceStrings = result.components(separatedBy: ", ")
        
        return serviceStrings.compactMap { serviceString in
            let components = serviceString.components(separatedBy: "|")
            guard components.count == 3 else { return nil }
            
            return NetworkService(
                id: components[0],
                name: components[1],
                type: "Unknown",
                isActive: components[2] == "true"
            )
        }
    }
    
    private func configureProxyForService(_ service: NetworkService, config: SystemProxyConfig) throws {
        switch config.proxyType {
        case .http:
            if let httpProxy = config.httpProxy {
                try setHTTPProxy(service: service, proxy: httpProxy, bypassList: config.bypassList)
            }
            
        case .https:
            if let httpsProxy = config.httpsProxy {
                try setHTTPSProxy(service: service, proxy: httpsProxy, bypassList: config.bypassList)
            }
            
        case .socks5:
            if let socksProxy = config.socksProxy {
                try setSOCKSProxy(service: service, proxy: socksProxy, bypassList: config.bypassList)
            }
            
        case .pac:
            if let pacURL = config.pacURL {
                try setPACProxy(service: service, pacURL: pacURL)
            }
            
        case .auto:
            // 自动配置逻辑
            try setAutoProxy(service: service, config: config)
        }
    }
    
    private func setHTTPProxy(service: NetworkService, proxy: ProxySettings, bypassList: [String]) throws {
        let bypassString = bypassList.joined(separator: ", ")
        
        let script = """
        tell application "System Events"
            tell network preferences
                tell service "\(service.name)"
                    tell proxies
                        set HTTP enabled to true
                        set HTTP server to "\(proxy.host)"
                        set HTTP port to \(proxy.port)
                        set exceptions list to {\(bypassString.split(separator: ", ").map { "\"\($0)\"" }.joined(separator: ", "))}
                    end tell
                end tell
            end tell
        end tell
        """
        
        try executeAppleScript(script)
        logger.info("HTTP代理配置成功: \(proxy.host):\(proxy.port)")
    }
    
    private func setHTTPSProxy(service: NetworkService, proxy: ProxySettings, bypassList: [String]) throws {
        let bypassString = bypassList.joined(separator: ", ")
        
        let script = """
        tell application "System Events"
            tell network preferences
                tell service "\(service.name)"
                    tell proxies
                        set HTTPS enabled to true
                        set HTTPS server to "\(proxy.host)"
                        set HTTPS port to \(proxy.port)
                        set exceptions list to {\(bypassString.split(separator: ", ").map { "\"\($0)\"" }.joined(separator: ", "))}
                    end tell
                end tell
            end tell
        end tell
        """
        
        try executeAppleScript(script)
        logger.info("HTTPS代理配置成功: \(proxy.host):\(proxy.port)")
    }
    
    private func setSOCKSProxy(service: NetworkService, proxy: ProxySettings, bypassList: [String]) throws {
        let bypassString = bypassList.joined(separator: ", ")
        
        let script = """
        tell application "System Events"
            tell network preferences
                tell service "\(service.name)"
                    tell proxies
                        set SOCKS firewall enabled to true
                        set SOCKS firewall server to "\(proxy.host)"
                        set SOCKS firewall port to \(proxy.port)
                        set exceptions list to {\(bypassString.split(separator: ", ").map { "\"\($0)\"" }.joined(separator: ", "))}
                    end tell
                end tell
            end tell
        end tell
        """
        
        try executeAppleScript(script)
        logger.info("SOCKS5代理配置成功: \(proxy.host):\(proxy.port)")
    }
    
    private func setPACProxy(service: NetworkService, pacURL: String) throws {
        let script = """
        tell application "System Events"
            tell network preferences
                tell service "\(service.name)"
                    tell proxies
                        set auto config enabled to true
                        set auto config URL to "\(pacURL)"
                    end tell
                end tell
            end tell
        end tell
        """
        
        try executeAppleScript(script)
        logger.info("PAC代理配置成功: \(pacURL)")
    }
    
    private func setAutoProxy(service: NetworkService, config: SystemProxyConfig) throws {
        // 根据配置自动选择最佳代理方式
        if let socksProxy = config.socksProxy {
            try setSOCKSProxy(service: service, proxy: socksProxy, bypassList: config.bypassList)
        } else if let httpProxy = config.httpProxy {
            try setHTTPProxy(service: service, proxy: httpProxy, bypassList: config.bypassList)
        }
    }
    
    private func disableProxyForService(_ service: NetworkService) throws {
        let script = """
        tell application "System Events"
            tell network preferences
                tell service "\(service.name)"
                    tell proxies
                        set HTTP enabled to false
                        set HTTPS enabled to false
                        set SOCKS firewall enabled to false
                        set auto config enabled to false
                    end tell
                end tell
            end tell
        end tell
        """
        
        try executeAppleScript(script)
        logger.info("代理已禁用: \(service.name)")
    }
    
    private func checkCurrentProxyStatus() throws -> ProxyStatus {
        let script = """
        tell application "System Events"
            tell network preferences
                tell service 1
                    tell proxies
                        set httpEnabled to HTTP enabled
                        set httpsEnabled to HTTPS enabled
                        set socksEnabled to SOCKS firewall enabled
                        set pacEnabled to auto config enabled
                        
                        if httpEnabled then
                            return "HTTP"
                        else if httpsEnabled then
                            return "HTTPS"
                        else if socksEnabled then
                            return "SOCKS5"
                        else if pacEnabled then
                            return "PAC"
                        else
                            return "DISABLED"
                        end if
                    end tell
                end tell
            end tell
        end tell
        """
        
        let result = try executeAppleScript(script)
        
        switch result {
        case "HTTP":
            return .enabled(.http)
        case "HTTPS":
            return .enabled(.https)
        case "SOCKS5":
            return .enabled(.socks5)
        case "PAC":
            return .enabled(.pac)
        case "DISABLED":
            return .disabled
        default:
            return .unknown
        }
    }
    
    private func executeAppleScript(_ script: String) throws -> String {
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        
        guard let result = appleScript?.executeAndReturnError(&error) else {
            if let error = error {
                throw SystemProxyError.appleScriptError(error.description)
            } else {
                throw SystemProxyError.appleScriptError("Unknown AppleScript error")
            }
        }
        
        return result.stringValue ?? ""
    }
}
```

### 3. 系统代理处理器实现

```swift
// MARK: - 系统代理处理器
@MainActor
class SystemProxyHandler: AsyncHandler {
    private let service: SystemProxyServiceProtocol
    private let statusMonitor: ProxyStatusMonitor
    
    @Published var config = SystemProxyConfig()
    @Published var status: ProxyStatus = .disabled
    @Published var networkServices: [NetworkService] = []
    @Published var isMonitoring = false
    
    init(service: SystemProxyServiceProtocol) {
        self.service = service
        self.statusMonitor = ProxyStatusMonitor()
        super.init()
        
        setupStatusMonitoring()
    }
    
    // MARK: - 公共方法
    
    /// 启用系统代理
    func enableProxy() async {
        await performAsyncOperation {
            try await self.service.enableProxy(self.config)
            await self.updateStatus()
            
            // 发送通知
            NotificationCenter.default.post(
                name: .systemProxyEnabled,
                object: self.config
            )
            
            self.logger.info("系统代理已启用")
        }
    }
    
    /// 禁用系统代理
    func disableProxy() async {
        await performAsyncOperation {
            try await self.service.disableProxy()
            await self.updateStatus()
            
            // 发送通知
            NotificationCenter.default.post(
                name: .systemProxyDisabled,
                object: nil
            )
            
            self.logger.info("系统代理已禁用")
        }
    }
    
    /// 切换代理状态
    func toggleProxy() async {
        if status.isEnabled {
            await disableProxy()
        } else {
            await enableProxy()
        }
    }
    
    /// 更新代理配置
    func updateConfig(_ newConfig: SystemProxyConfig) async {
        await performAsyncOperation {
            self.config = newConfig
            
            // 如果当前已启用，重新应用配置
            if self.status.isEnabled {
                try await self.service.enableProxy(newConfig)
                await self.updateStatus()
            }
            
            self.logger.info("代理配置已更新")
        }
    }
    
    /// 测试代理连接
    func testProxy(_ settings: ProxySettings) async -> Bool {
        do {
            return try await service.testProxyConnection(settings)
        } catch {
            logger.error("代理测试失败: \(error)")
            return false
        }
    }
    
    /// 加载网络服务
    func loadNetworkServices() async {
        await performAsyncOperation {
            let services = try await self.service.getNetworkServices()
            await MainActor.run {
                self.networkServices = services
            }
        }
    }
    
    /// 开始状态监控
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        statusMonitor.startMonitoring { [weak self] newStatus in
            Task { @MainActor in
                self?.status = newStatus
            }
        }
        
        logger.info("代理状态监控已启动")
    }
    
    /// 停止状态监控
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        statusMonitor.stopMonitoring()
        
        logger.info("代理状态监控已停止")
    }
    
    // MARK: - 私有方法
    
    private func setupStatusMonitoring() {
        Task {
            await updateStatus()
            await loadNetworkServices()
            startMonitoring()
        }
    }
    
    private func updateStatus() async {
        do {
            let currentStatus = try await service.getCurrentStatus()
            await MainActor.run {
                self.status = currentStatus
            }
        } catch {
            await MainActor.run {
                self.status = .error(error)
            }
            logger.error("获取代理状态失败: \(error)")
        }
    }
}

// MARK: - 代理状态监控器
class ProxyStatusMonitor {
    private var timer: Timer?
    private var statusCallback: ((ProxyStatus) -> Void)?
    private let service = SystemProxyService()
    
    func startMonitoring(callback: @escaping (ProxyStatus) -> Void) {
        statusCallback = callback
        
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                await self?.checkStatus()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        statusCallback = nil
    }
    
    private func checkStatus() async {
        do {
            let status = try await service.getCurrentStatus()
            statusCallback?(status)
        } catch {
            statusCallback?(.error(error))
        }
    }
}
```

### 4. 用户界面实现

```swift
// MARK: - 系统代理视图
struct SystemProxyView: View {
    @StateObject private var handler = HandlerManager.shared.systemProxyHandler
    @State private var showingProxySettings = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 代理状态卡片
            ProxyStatusCard(status: handler.status, handler: handler)
            
            // 代理配置
            ProxyConfigurationView(config: $handler.config, handler: handler)
            
            // 网络服务列表
            NetworkServicesView(services: handler.networkServices)
            
            Spacer()
        }
        .padding()
        .navigationTitle("系统代理")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("设置") {
                    showingProxySettings = true
                }
            }
        }
        .sheet(isPresented: $showingProxySettings) {
            ProxySettingsView(config: $handler.config, handler: handler)
        }
        .task {
            await handler.loadNetworkServices()
        }
    }
}

// MARK: - 代理状态卡片
struct ProxyStatusCard: View {
    let status: ProxyStatus
    let handler: SystemProxyHandler
    
    var body: some View {
        VStack(spacing: 12) {
            // 状态指示器
            HStack {
                StatusIndicator(isActive: status.isEnabled)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("系统代理")
                        .font(.headline)
                    
                    Text(status.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 切换按钮
                Button(action: {
                    Task {
                        await handler.toggleProxy()
                    }
                }) {
                    Text(status.isEnabled ? "禁用" : "启用")
                        .frame(width: 60)
                }
                .buttonStyle(.borderedProminent)
                .disabled(handler.isLoading)
            }
            
            // 加载指示器
            if handler.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - 代理配置视图
struct ProxyConfigurationView: View {
    @Binding var config: SystemProxyConfig
    let handler: SystemProxyHandler
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("代理配置")
                .font(.headline)
            
            // 代理类型选择
            Picker("代理类型", selection: $config.proxyType) {
                ForEach(ProxyType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            // 代理设置
            switch config.proxyType {
            case .http:
                ProxySettingsEditor(
                    title: "HTTP代理",
                    settings: Binding(
                        get: { config.httpProxy ?? ProxySettings(host: "127.0.0.1", port: 8080) },
                        set: { config.httpProxy = $0 }
                    ),
                    handler: handler
                )
                
            case .https:
                ProxySettingsEditor(
                    title: "HTTPS代理",
                    settings: Binding(
                        get: { config.httpsProxy ?? ProxySettings(host: "127.0.0.1", port: 8080) },
                        set: { config.httpsProxy = $0 }
                    ),
                    handler: handler
                )
                
            case .socks5:
                ProxySettingsEditor(
                    title: "SOCKS5代理",
                    settings: Binding(
                        get: { config.socksProxy ?? ProxySettings(host: "127.0.0.1", port: 1080) },
                        set: { config.socksProxy = $0 }
                    ),
                    handler: handler
                )
                
            case .pac:
                PACConfigurationView(config: $config)
                
            case .auto:
                AutoProxyConfigurationView(config: $config, handler: handler)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - 代理设置编辑器
struct ProxySettingsEditor: View {
    let title: String
    @Binding var settings: ProxySettings
    let handler: SystemProxyHandler
    
    @State private var host: String
    @State private var port: String
    @State private var isTestingConnection = false
    @State private var testResult: Bool?
    
    init(title: String, settings: Binding<ProxySettings>, handler: SystemProxyHandler) {
        self.title = title
        self._settings = settings
        self.handler = handler
        self._host = State(initialValue: settings.wrappedValue.host)
        self._port = State(initialValue: String(settings.wrappedValue.port))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                TextField("主机地址", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: host) { newValue in
                        updateSettings()
                    }
                
                TextField("端口", text: $port)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onChange(of: port) { newValue in
                        updateSettings()
                    }
                
                // 测试连接按钮
                Button(action: testConnection) {
                    if isTestingConnection {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "network")
                    }
                }
                .disabled(isTestingConnection || host.isEmpty || port.isEmpty)
                
                // 测试结果指示器
                if let result = testResult {
                    Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result ? .green : .red)
                }
            }
        }
    }
    
    private func updateSettings() {
        guard let portInt = Int(port), portInt > 0, portInt <= 65535 else { return }
        
        settings = ProxySettings(
            host: host,
            port: portInt,
            username: settings.username,
            password: settings.password,
            enabled: settings.enabled
        )
    }
    
    private func testConnection() {
        guard let portInt = Int(port), portInt > 0, portInt <= 65535 else { return }
        
        isTestingConnection = true
        testResult = nil
        
        let testSettings = ProxySettings(host: host, port: portInt)
        
        Task {
            let result = await handler.testProxy(testSettings)
            
            await MainActor.run {
                self.testResult = result
                self.isTestingConnection = false
            }
        }
    }
}
```

## 🔧 使用示例

### 1. 启用HTTP代理

```swift
var config = SystemProxyConfig()
config.proxyType = .http
config.httpProxy = ProxySettings(host: "127.0.0.1", port: 8080)
config.bypassList = ["127.0.0.1", "localhost", "*.local"]

await systemProxyHandler.updateConfig(config)
await systemProxyHandler.enableProxy()
```

### 2. 启用SOCKS5代理

```swift
var config = SystemProxyConfig()
config.proxyType = .socks5
config.socksProxy = ProxySettings(host: "127.0.0.1", port: 1080)

await systemProxyHandler.updateConfig(config)
await systemProxyHandler.enableProxy()
```

### 3. 测试代理连接

```swift
let proxySettings = ProxySettings(host: "127.0.0.1", port: 8080)
let isConnected = await systemProxyHandler.testProxy(proxySettings)

if isConnected {
    print("代理连接正常")
} else {
    print("代理连接失败")
}
```

## 📚 相关文档

- [代理管理功能](proxy-management.md)
- [流量统计功能](traffic-stats.md)
- [路由规则功能](routing-rules.md)
- [基础工具模块](../modules/base-utilities.md)
- [处理器层模块](../modules/handler-layer.md)

---

*本文档详细介绍了V2rayU系统代理功能的设计与实现，为开发者提供了完整的系统代理管理解决方案。*
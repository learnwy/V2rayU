# 处理器文件详解

## 📋 概述

本文档详细解析V2rayU项目中的处理器文件，包括业务逻辑处理、数据管理、网络通信和系统集成的实现细节。

## 🏗️ 处理器分类

### 1. 核心处理器
- `V2rayCore.swift` - V2ray核心管理
- `ProxyManager.swift` - 代理管理器
- `SystemProxy.swift` - 系统代理控制
- `NetworkMonitor.swift` - 网络监控

### 2. 数据处理器
- `ServerManager.swift` - 服务器管理
- `SubscriptionManager.swift` - 订阅管理
- `ConfigManager.swift` - 配置管理
- `DatabaseManager.swift` - 数据库管理

### 3. 网络处理器
- `NetworkClient.swift` - 网络客户端
- `PingTester.swift` - 延迟测试
- `TrafficMonitor.swift` - 流量监控
- `DNSResolver.swift` - DNS解析

### 4. 工具处理器
- `LogManager.swift` - 日志管理
- `NotificationManager.swift` - 通知管理
- `MenuBarManager.swift` - 菜单栏管理
- `UpdateManager.swift` - 更新管理

## 📁 详细处理器解析

### 1. ProxyManager.swift

**文件路径**: `V2rayU/Handlers/ProxyManager.swift`

**功能描述**: 代理管理器，负责代理连接的建立、断开和状态管理。

```swift
import Foundation
import Network
import Combine

/// 代理管理器
@MainActor
class ProxyManager: ObservableObject {
    static let shared = ProxyManager()
    
    // MARK: - Published Properties
    
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var activeServerID: UUID?
    @Published var currentTraffic: TrafficStats = TrafficStats()
    @Published var isConnecting = false
    @Published var lastError: ProxyError?
    
    // MARK: - Private Properties
    
    private let v2rayCore = V2rayCore.shared
    private let systemProxy = SystemProxy.shared
    private let trafficMonitor = TrafficMonitor.shared
    private let networkMonitor = NetworkMonitor.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var connectionTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
        loadLastActiveServer()
    }
    
    // MARK: - Public Methods
    
    /// 连接到指定服务器
    func connect(to server: ServerConfig) async {
        guard !isConnecting else { return }
        
        isConnecting = true
        connectionStatus = .connecting
        lastError = nil
        
        do {
            // 1. 停止当前连接
            await disconnect()
            
            // 2. 验证服务器配置
            try validateServerConfig(server)
            
            // 3. 生成V2ray配置
            let v2rayConfig = try generateV2rayConfig(for: server)
            
            // 4. 启动V2ray核心
            try await v2rayCore.start(with: v2rayConfig)
            
            // 5. 配置系统代理
            try await systemProxy.enable(with: v2rayConfig.inbounds)
            
            // 6. 开始流量监控
            await trafficMonitor.startMonitoring()
            
            // 7. 更新状态
            activeServerID = server.id
            connectionStatus = .connected
            reconnectAttempts = 0
            
            // 8. 更新服务器使用记录
            await ServerManager.shared.updateServerUsage(server.id)
            
            // 9. 发送连接成功通知
            NotificationManager.shared.showConnectionSuccess(serverName: server.name)
            
            // 10. 开始连接监控
            startConnectionMonitoring()
            
            Logger.info("Successfully connected to server: \(server.name)")
            
        } catch {
            await handleConnectionError(error, server: server)
        }
        
        isConnecting = false
    }
    
    /// 断开连接
    func disconnect() async {
        guard connectionStatus != .disconnected else { return }
        
        connectionStatus = .disconnecting
        
        // 停止连接监控
        stopConnectionMonitoring()
        
        // 停止流量监控
        await trafficMonitor.stopMonitoring()
        
        // 禁用系统代理
        await systemProxy.disable()
        
        // 停止V2ray核心
        await v2rayCore.stop()
        
        // 更新状态
        activeServerID = nil
        connectionStatus = .disconnected
        currentTraffic = TrafficStats()
        lastError = nil
        
        Logger.info("Disconnected from proxy")
    }
    
    /// 重新连接
    func reconnect() async {
        guard let serverID = activeServerID,
              let server = await ServerManager.shared.getServer(by: serverID) else {
            return
        }
        
        await connect(to: server)
    }
    
    /// 切换连接状态
    func toggleConnection() async {
        if isConnected {
            await disconnect()
        } else if let serverID = getLastActiveServerID(),
                  let server = await ServerManager.shared.getServer(by: serverID) {
            await connect(to: server)
        }
    }
    
    /// 测试服务器连接
    func testConnection(to server: ServerConfig) async -> ConnectionTestResult {
        do {
            // 创建临时配置
            let testConfig = try generateV2rayConfig(for: server)
            
            // 测试连接
            let result = await v2rayCore.testConnection(with: testConfig)
            
            return ConnectionTestResult(
                isSuccessful: result.isSuccessful,
                latency: result.latency,
                error: result.error
            )
            
        } catch {
            return ConnectionTestResult(
                isSuccessful: false,
                latency: nil,
                error: error
            )
        }
    }
    
    // MARK: - Computed Properties
    
    var isConnected: Bool {
        connectionStatus == .connected
    }
    
    var isDisconnected: Bool {
        connectionStatus == .disconnected
    }
    
    var canConnect: Bool {
        !isConnecting && isDisconnected
    }
    
    var canDisconnect: Bool {
        !isConnecting && isConnected
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // 监听网络状态变化
        networkMonitor.$isConnected
            .dropFirst()
            .sink { [weak self] isNetworkConnected in
                Task { @MainActor in
                    await self?.handleNetworkStatusChange(isNetworkConnected)
                }
            }
            .store(in: &cancellables)
        
        // 监听V2ray核心状态
        v2rayCore.$status
            .sink { [weak self] status in
                Task { @MainActor in
                    await self?.handleV2rayCoreStatusChange(status)
                }
            }
            .store(in: &cancellables)
        
        // 监听流量统计
        trafficMonitor.$currentStats
            .assign(to: \.$currentTraffic, on: self)
            .store(in: &cancellables)
    }
    
    private func validateServerConfig(_ server: ServerConfig) throws {
        guard !server.address.isEmpty else {
            throw ProxyError.invalidServerConfig("服务器地址不能为空")
        }
        
        guard server.port > 0 && server.port <= 65535 else {
            throw ProxyError.invalidServerConfig("端口号无效")
        }
        
        // 验证协议特定配置
        switch server.protocolSettings {
        case .vmess(let config):
            guard !config.uuid.isEmpty else {
                throw ProxyError.invalidServerConfig("VMess UUID不能为空")
            }
        case .vless(let config):
            guard !config.uuid.isEmpty else {
                throw ProxyError.invalidServerConfig("VLESS UUID不能为空")
            }
        case .trojan(let config):
            guard !config.password.isEmpty else {
                throw ProxyError.invalidServerConfig("Trojan密码不能为空")
            }
        case .shadowsocks(let config):
            guard !config.password.isEmpty else {
                throw ProxyError.invalidServerConfig("Shadowsocks密码不能为空")
            }
        }
    }
    
    private func generateV2rayConfig(for server: ServerConfig) throws -> V2rayConfig {
        var config = V2rayConfig.default
        
        // 配置入站
        config.inbounds = [
            InboundConfig.defaultSOCKS(),
            InboundConfig.defaultHTTP()
        ]
        
        // 配置出站
        let outbound = try OutboundConfig.fromServer(server)
        config.outbounds = [outbound, OutboundConfig.defaultDirect(), OutboundConfig.defaultBlocked()]
        
        // 配置路由
        config.routing = try generateRoutingConfig()
        
        // 配置DNS
        config.dns = generateDNSConfig()
        
        // 配置日志
        config.log = LogConfig(
            access: "",
            error: "",
            loglevel: AppSettings.shared.logLevel.rawValue
        )
        
        // 配置统计
        if AppSettings.shared.enableTrafficStats {
            config.stats = StatsConfig()
            config.api = APIConfig(
                tag: "api",
                services: ["StatsService"]
            )
        }
        
        return config
    }
    
    private func generateRoutingConfig() throws -> RoutingConfig {
        let settings = AppSettings.shared
        var rules: [RoutingRule] = []
        
        // API规则
        if settings.enableTrafficStats {
            rules.append(RoutingRule(
                type: "field",
                inboundTag: ["api"],
                outboundTag: "api"
            ))
        }
        
        // 直连规则
        if settings.enableDirectRouting {
            rules.append(RoutingRule(
                type: "field",
                domain: settings.directDomains,
                outboundTag: "direct"
            ))
            
            rules.append(RoutingRule(
                type: "field",
                ip: settings.directIPs,
                outboundTag: "direct"
            ))
        }
        
        // 阻止规则
        if settings.enableAdBlock {
            rules.append(RoutingRule(
                type: "field",
                domain: settings.blockedDomains,
                outboundTag: "blocked"
            ))
        }
        
        return RoutingConfig(
            domainStrategy: settings.domainStrategy.rawValue,
            rules: rules
        )
    }
    
    private func generateDNSConfig() -> DNSConfig {
        let settings = AppSettings.shared
        
        var servers: [DNSServer] = []
        
        // 主DNS服务器
        servers.append(DNSServer(
            address: settings.primaryDNS,
            port: 53,
            domains: nil
        ))
        
        // 备用DNS服务器
        if !settings.secondaryDNS.isEmpty {
            servers.append(DNSServer(
                address: settings.secondaryDNS,
                port: 53,
                domains: nil
            ))
        }
        
        // 国内DNS（用于直连域名）
        if settings.enableDirectRouting {
            servers.append(DNSServer(
                address: "223.5.5.5",
                port: 53,
                domains: settings.directDomains
            ))
        }
        
        return DNSConfig(
            servers: servers,
            hosts: settings.customHosts,
            clientIP: nil,
            tag: "dns"
        )
    }
    
    private func handleConnectionError(_ error: Error, server: ServerConfig) async {
        let proxyError: ProxyError
        
        if let existingError = error as? ProxyError {
            proxyError = existingError
        } else {
            proxyError = ProxyError.connectionFailed(error.localizedDescription)
        }
        
        lastError = proxyError
        connectionStatus = .error
        activeServerID = nil
        
        Logger.error("Connection failed: \(proxyError.localizedDescription)")
        
        // 显示错误通知
        NotificationManager.shared.showConnectionError(
            serverName: server.name,
            error: proxyError
        )
        
        // 尝试自动重连
        if AppSettings.shared.enableAutoReconnect && reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                Task {
                    await self.connect(to: server)
                }
            }
        }
    }
    
    private func handleNetworkStatusChange(_ isConnected: Bool) async {
        if !isConnected {
            // 网络断开，更新状态但不断开代理
            if connectionStatus == .connected {
                connectionStatus = .error
                lastError = ProxyError.networkUnavailable
            }
        } else {
            // 网络恢复，尝试重连
            if connectionStatus == .error && activeServerID != nil {
                await reconnect()
            }
        }
    }
    
    private func handleV2rayCoreStatusChange(_ status: V2rayCoreStatus) async {
        switch status {
        case .stopped:
            if connectionStatus == .connected {
                connectionStatus = .error
                lastError = ProxyError.coreProcessTerminated
                
                // 尝试重启
                if AppSettings.shared.enableAutoReconnect {
                    await reconnect()
                }
            }
        case .error(let error):
            if connectionStatus == .connected {
                connectionStatus = .error
                lastError = ProxyError.coreError(error)
            }
        default:
            break
        }
    }
    
    private func startConnectionMonitoring() {
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkConnectionHealth()
            }
        }
    }
    
    private func stopConnectionMonitoring() {
        connectionTimer?.invalidate()
        connectionTimer = nil
    }
    
    private func checkConnectionHealth() async {
        guard isConnected else { return }
        
        // 检查V2ray核心状态
        let coreStatus = await v2rayCore.getStatus()
        if coreStatus != .running {
            connectionStatus = .error
            lastError = ProxyError.coreProcessTerminated
            return
        }
        
        // 检查系统代理状态
        let proxyStatus = await systemProxy.getStatus()
        if !proxyStatus.isEnabled {
            connectionStatus = .error
            lastError = ProxyError.systemProxyDisabled
            return
        }
        
        // 检查网络连通性
        if !networkMonitor.isConnected {
            connectionStatus = .error
            lastError = ProxyError.networkUnavailable
            return
        }
    }
    
    private func loadLastActiveServer() {
        if let serverIDString = UserDefaults.standard.string(forKey: "lastActiveServerID"),
           let serverID = UUID(uuidString: serverIDString) {
            activeServerID = serverID
        }
    }
    
    private func getLastActiveServerID() -> UUID? {
        if let serverIDString = UserDefaults.standard.string(forKey: "lastActiveServerID") {
            return UUID(uuidString: serverIDString)
        }
        return nil
    }
}

// MARK: - 连接状态
enum ConnectionStatus: String, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case disconnecting = "disconnecting"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .disconnected: return "未连接"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .disconnecting: return "断开中"
        case .error: return "错误"
        }
    }
    
    var color: Color {
        switch self {
        case .disconnected: return .secondary
        case .connecting: return .yellow
        case .connected: return .green
        case .disconnecting: return .orange
        case .error: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .disconnected: return "circle"
        case .connecting: return "circle.dotted"
        case .connected: return "circle.fill"
        case .disconnecting: return "circle.slash"
        case .error: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - 代理错误
enum ProxyError: LocalizedError {
    case invalidServerConfig(String)
    case connectionFailed(String)
    case networkUnavailable
    case coreProcessTerminated
    case coreError(String)
    case systemProxyDisabled
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidServerConfig(let message):
            return "服务器配置无效: \(message)"
        case .connectionFailed(let message):
            return "连接失败: \(message)"
        case .networkUnavailable:
            return "网络不可用"
        case .coreProcessTerminated:
            return "V2ray核心进程意外终止"
        case .coreError(let message):
            return "V2ray核心错误: \(message)"
        case .systemProxyDisabled:
            return "系统代理已被禁用"
        case .configurationError(let message):
            return "配置错误: \(message)"
        }
    }
}

// MARK: - 连接测试结果
struct ConnectionTestResult {
    let isSuccessful: Bool
    let latency: TimeInterval?
    let error: Error?
    
    var displayText: String {
        if isSuccessful {
            if let latency = latency {
                return "\(Int(latency * 1000))ms"
            } else {
                return "成功"
            }
        } else {
            return "失败"
        }
    }
}

// MARK: - 流量统计
struct TrafficStats: Codable {
    var uploadBytes: Int64 = 0
    var downloadBytes: Int64 = 0
    var uploadSpeed: Int64 = 0
    var downloadSpeed: Int64 = 0
    
    var totalBytes: Int64 {
        uploadBytes + downloadBytes
    }
    
    var formattedUpload: String {
        ByteCountFormatter.string(fromByteCount: uploadBytes, countStyle: .binary)
    }
    
    var formattedDownload: String {
        ByteCountFormatter.string(fromByteCount: downloadBytes, countStyle: .binary)
    }
    
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .binary)
    }
    
    var formattedUploadSpeed: String {
        ByteCountFormatter.string(fromByteCount: uploadSpeed, countStyle: .binary) + "/s"
    }
    
    var formattedDownloadSpeed: String {
        ByteCountFormatter.string(fromByteCount: downloadSpeed, countStyle: .binary) + "/s"
    }
}
```

### 2. ServerManager.swift

**文件路径**: `V2rayU/Handlers/ServerManager.swift`

**功能描述**: 服务器管理器，负责服务器的增删改查和状态管理。

```swift
import Foundation
import GRDB
import Combine

/// 服务器管理器
@MainActor
class ServerManager: ObservableObject {
    static let shared = ServerManager()
    
    // MARK: - Published Properties
    
    @Published var servers: [ServerConfig] = []
    @Published var isLoading = false
    @Published var lastError: ServerManagerError?
    
    // MARK: - Private Properties
    
    private let database = DatabaseManager.shared
    private let pingTester = PingTester.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// 加载所有服务器
    func loadServers() async {
        isLoading = true
        lastError = nil
        
        do {
            let loadedServers = try await database.loadServers()
            servers = loadedServers.sorted { $0.name < $1.name }
            Logger.info("Loaded \(servers.count) servers")
        } catch {
            lastError = ServerManagerError.loadFailed(error)
            Logger.error("Failed to load servers: \(error)")
        }
        
        isLoading = false
    }
    
    /// 添加服务器
    func addServer(_ server: ServerConfig) async {
        do {
            let savedServer = try await database.saveServer(server)
            servers.append(savedServer)
            servers.sort { $0.name < $1.name }
            
            Logger.info("Added server: \(server.name)")
            
            // 发送通知
            NotificationCenter.default.post(
                name: .serverAdded,
                object: savedServer
            )
            
        } catch {
            lastError = ServerManagerError.saveFailed(error)
            Logger.error("Failed to add server: \(error)")
        }
    }
    
    /// 更新服务器
    func updateServer(_ server: ServerConfig) async {
        do {
            let updatedServer = try await database.updateServer(server)
            
            if let index = servers.firstIndex(where: { $0.id == server.id }) {
                servers[index] = updatedServer
                servers.sort { $0.name < $1.name }
            }
            
            Logger.info("Updated server: \(server.name)")
            
            // 发送通知
            NotificationCenter.default.post(
                name: .serverUpdated,
                object: updatedServer
            )
            
        } catch {
            lastError = ServerManagerError.updateFailed(error)
            Logger.error("Failed to update server: \(error)")
        }
    }
    
    /// 删除服务器
    func deleteServer(_ serverID: UUID) async {
        do {
            try await database.deleteServer(serverID)
            
            if let index = servers.firstIndex(where: { $0.id == serverID }) {
                let deletedServer = servers.remove(at: index)
                
                Logger.info("Deleted server: \(deletedServer.name)")
                
                // 发送通知
                NotificationCenter.default.post(
                    name: .serverDeleted,
                    object: deletedServer
                )
            }
            
        } catch {
            lastError = ServerManagerError.deleteFailed(error)
            Logger.error("Failed to delete server: \(error)")
        }
    }
    
    /// 批量删除服务器
    func deleteServers(_ serverIDs: Set<UUID>) async {
        do {
            try await database.deleteServers(Array(serverIDs))
            
            let deletedServers = servers.filter { serverIDs.contains($0.id) }
            servers.removeAll { serverIDs.contains($0.id) }
            
            Logger.info("Deleted \(deletedServers.count) servers")
            
            // 发送通知
            NotificationCenter.default.post(
                name: .serversDeleted,
                object: deletedServers
            )
            
        } catch {
            lastError = ServerManagerError.deleteFailed(error)
            Logger.error("Failed to delete servers: \(error)")
        }
    }
    
    /// 复制服务器
    func duplicateServer(_ serverID: UUID) async {
        guard let originalServer = servers.first(where: { $0.id == serverID }) else {
            return
        }
        
        var duplicatedServer = originalServer
        duplicatedServer.id = UUID()
        duplicatedServer.name = "\(originalServer.name) 副本"
        duplicatedServer.createdAt = Date()
        duplicatedServer.updatedAt = Date()
        
        await addServer(duplicatedServer)
    }
    
    /// 获取服务器
    func getServer(by id: UUID) async -> ServerConfig? {
        if let server = servers.first(where: { $0.id == id }) {
            return server
        }
        
        // 从数据库加载
        do {
            return try await database.loadServer(id)
        } catch {
            Logger.error("Failed to load server \(id): \(error)")
            return nil
        }
    }
    
    /// 测试服务器延迟
    func testServer(_ serverID: UUID) async {
        guard let server = servers.first(where: { $0.id == serverID }) else {
            return
        }
        
        do {
            let result = await pingTester.testServer(server)
            
            var updatedServer = server
            updatedServer.lastPingTime = result.latency
            updatedServer.pingStatus = result.status
            updatedServer.lastPingAt = Date()
            
            await updateServer(updatedServer)
            
        } catch {
            Logger.error("Failed to test server \(server.name): \(error)")
        }
    }
    
    /// 批量测试服务器
    func testServers(_ serverIDs: Set<UUID>) async {
        let serversToTest = servers.filter { serverIDs.contains($0.id) }
        
        await withTaskGroup(of: Void.self) { group in
            for server in serversToTest {
                group.addTask {
                    await self.testServer(server.id)
                }
            }
        }
    }
    
    /// 测试所有服务器
    func testAllServers() async {
        let serverIDs = Set(servers.map { $0.id })
        await testServers(serverIDs)
    }
    
    /// 更新服务器使用记录
    func updateServerUsage(_ serverID: UUID) async {
        guard let server = servers.first(where: { $0.id == serverID }) else {
            return
        }
        
        var updatedServer = server
        updatedServer.lastUsed = Date()
        updatedServer.usageCount += 1
        
        await updateServer(updatedServer)
    }
    
    /// 更新服务器流量统计
    func updateServerTraffic(_ serverID: UUID, upload: Int64, download: Int64) async {
        guard let server = servers.first(where: { $0.id == serverID }) else {
            return
        }
        
        var updatedServer = server
        updatedServer.totalUpload += upload
        updatedServer.totalDownload += download
        
        await updateServer(updatedServer)
    }
    
    /// 导入服务器配置
    func importServers(from urls: [String]) async -> ImportResult {
        var successCount = 0
        var failedCount = 0
        var errors: [String] = []
        
        for url in urls {
            do {
                let server = try parseServerURL(url)
                await addServer(server)
                successCount += 1
            } catch {
                failedCount += 1
                errors.append("\(url): \(error.localizedDescription)")
            }
        }
        
        return ImportResult(
            successCount: successCount,
            failedCount: failedCount,
            errors: errors
        )
    }
    
    /// 导出服务器配置
    func exportServers(_ serverIDs: Set<UUID>) -> [String] {
        return servers
            .filter { serverIDs.contains($0.id) }
            .compactMap { $0.connectionURL }
    }
    
    /// 搜索服务器
    func searchServers(query: String) -> [ServerConfig] {
        guard !query.isEmpty else { return servers }
        
        return servers.filter { server in
            server.name.localizedCaseInsensitiveContains(query) ||
            server.address.localizedCaseInsensitiveContains(query) ||
            server.group?.localizedCaseInsensitiveContains(query) == true
        }
    }
    
    /// 按分组获取服务器
    func getServersByGroup() -> [String: [ServerConfig]] {
        return Dictionary(grouping: servers) { server in
            server.group ?? "未分组"
        }
    }
    
    /// 获取服务器统计信息
    func getServerStats() -> ServerStats {
        let totalServers = servers.count
        let activeServers = servers.filter { $0.isActive }.count
        let groupCount = Set(servers.compactMap { $0.group }).count
        
        let protocolStats = Dictionary(grouping: servers, by: { $0.protocol })
            .mapValues { $0.count }
        
        return ServerStats(
            totalServers: totalServers,
            activeServers: activeServers,
            groupCount: groupCount,
            protocolStats: protocolStats
        )
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // 监听数据库变化
        NotificationCenter.default.publisher(for: .databaseDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadServers()
                }
            }
            .store(in: &cancellables)
    }
    
    private func parseServerURL(_ url: String) throws -> ServerConfig {
        guard let parsedURL = URL(string: url) else {
            throw ServerManagerError.invalidURL(url)
        }
        
        switch parsedURL.scheme?.lowercased() {
        case "vmess":
            return try parseVMessURL(url)
        case "vless":
            return try parseVLESSURL(url)
        case "trojan":
            return try parseTrojanURL(url)
        case "ss":
            return try parseShadowsocksURL(url)
        default:
            throw ServerManagerError.unsupportedProtocol(parsedURL.scheme ?? "unknown")
        }
    }
    
    private func parseVMessURL(_ url: String) throws -> ServerConfig {
        // VMess URL解析逻辑
        // 实现VMess协议的URL解析
        throw ServerManagerError.parseError("VMess URL parsing not implemented")
    }
    
    private func parseVLESSURL(_ url: String) throws -> ServerConfig {
        // VLESS URL解析逻辑
        // 实现VLESS协议的URL解析
        throw ServerManagerError.parseError("VLESS URL parsing not implemented")
    }
    
    private func parseTrojanURL(_ url: String) throws -> ServerConfig {
        // Trojan URL解析逻辑
        // 实现Trojan协议的URL解析
        throw ServerManagerError.parseError("Trojan URL parsing not implemented")
    }
    
    private func parseShadowsocksURL(_ url: String) throws -> ServerConfig {
        // Shadowsocks URL解析逻辑
        // 实现Shadowsocks协议的URL解析
        throw ServerManagerError.parseError("Shadowsocks URL parsing not implemented")
    }
}

// MARK: - 服务器管理器错误
enum ServerManagerError: LocalizedError {
    case loadFailed(Error)
    case saveFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case invalidURL(String)
    case unsupportedProtocol(String)
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "加载服务器失败: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "保存服务器失败: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "更新服务器失败: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "删除服务器失败: \(error.localizedDescription)"
        case .invalidURL(let url):
            return "无效的URL: \(url)"
        case .unsupportedProtocol(let protocol):
            return "不支持的协议: \(protocol)"
        case .parseError(let message):
            return "解析错误: \(message)"
        }
    }
}

// MARK: - 导入结果
struct ImportResult {
    let successCount: Int
    let failedCount: Int
    let errors: [String]
    
    var isSuccessful: Bool {
        failedCount == 0
    }
    
    var summary: String {
        if isSuccessful {
            return "成功导入 \(successCount) 个服务器"
        } else {
            return "导入完成：成功 \(successCount) 个，失败 \(failedCount) 个"
        }
    }
}

// MARK: - 服务器统计
struct ServerStats {
    let totalServers: Int
    let activeServers: Int
    let groupCount: Int
    let protocolStats: [ProxyProtocol: Int]
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let serverAdded = Notification.Name("serverAdded")
    static let serverUpdated = Notification.Name("serverUpdated")
    static let serverDeleted = Notification.Name("serverDeleted")
    static let serversDeleted = Notification.Name("serversDeleted")
    static let databaseDidChange = Notification.Name("databaseDidChange")
}
```

### 3. SubscriptionManager.swift

**文件路径**: `V2rayU/Handlers/SubscriptionManager.swift`

**功能描述**: 订阅管理器，负责订阅的管理和自动更新。

```swift
import Foundation
import Combine

/// 订阅管理器
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    
    @Published var subscriptions: [Subscription] = []
    @Published var isUpdating = false
    @Published var updateProgress: Double = 0.0
    @Published var lastError: SubscriptionError?
    
    // MARK: - Private Properties
    
    private let database = DatabaseManager.shared
    private let networkClient = NetworkClient.shared
    private let serverManager = ServerManager.shared
    
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupAutoUpdate()
        loadSubscriptions()
    }
    
    // MARK: - Public Methods
    
    /// 加载所有订阅
    func loadSubscriptions() async {
        do {
            let loadedSubscriptions = try await database.loadSubscriptions()
            subscriptions = loadedSubscriptions.sorted { $0.name < $1.name }
            Logger.info("Loaded \(subscriptions.count) subscriptions")
        } catch {
            lastError = SubscriptionError.loadFailed(error)
            Logger.error("Failed to load subscriptions: \(error)")
        }
    }
    
    /// 添加订阅
    func addSubscription(_ subscription: Subscription) async {
        do {
            let savedSubscription = try await database.saveSubscription(subscription)
            subscriptions.append(savedSubscription)
            subscriptions.sort { $0.name < $1.name }
            
            Logger.info("Added subscription: \(subscription.name)")
            
            // 立即更新新添加的订阅
            if subscription.enabled {
                await updateSubscription(savedSubscription.id)
            }
            
        } catch {
            lastError = SubscriptionError.saveFailed(error)
            Logger.error("Failed to add subscription: \(error)")
        }
    }
    
    /// 更新订阅
    func updateSubscription(_ subscriptionID: UUID) async {
        guard let subscription = subscriptions.first(where: { $0.id == subscriptionID }),
              subscription.enabled else {
            return
        }
        
        isUpdating = true
        updateProgress = 0.0
        lastError = nil
        
        do {
            // 1. 下载订阅内容
            updateProgress = 0.2
            let content = try await downloadSubscriptionContent(subscription)
            
            // 2. 解析服务器列表
            updateProgress = 0.4
            let servers = try parseSubscriptionContent(content, subscription: subscription)
            
            // 3. 更新数据库
            updateProgress = 0.6
            try await updateSubscriptionServers(subscription, servers: servers)
            
            // 4. 更新订阅状态
            updateProgress = 0.8
            var updatedSubscription = subscription
            updatedSubscription.lastUpdateTime = Date()
            updatedSubscription.lastSuccessTime = Date()
            updatedSubscription.updateCount += 1
            updatedSubscription.serverCount = servers.count
            updatedSubscription.activeServerCount = servers.filter { $0.isActive }.count
            
            try await database.updateSubscription(updatedSubscription)
            
            // 5. 更新本地列表
            if let index = subscriptions.firstIndex(where: { $0.id == subscriptionID }) {
                subscriptions[index] = updatedSubscription
            }
            
            updateProgress = 1.0
            
            Logger.info("Updated subscription \(subscription.name): \(servers.count) servers")
            
            // 发送通知
            NotificationCenter.default.post(
                name: .subscriptionUpdated,
                object: updatedSubscription
            )
            
        } catch {
            // 更新失败状态
            var failedSubscription = subscription
            failedSubscription.lastUpdateTime = Date()
            failedSubscription.lastErrorTime = Date()
            failedSubscription.lastError = error.localizedDescription
            
            try? await database.updateSubscription(failedSubscription)
            
            if let index = subscriptions.firstIndex(where: { $0.id == subscriptionID }) {
                subscriptions[index] = failedSubscription
            }
            
            lastError = SubscriptionError.updateFailed(error)
            Logger.error("Failed to update subscription \(subscription.name): \(error)")
        }
        
        isUpdating = false
        updateProgress = 0.0
    }
    
    /// 更新所有订阅
    func updateAllSubscriptions() async {
        let enabledSubscriptions = subscriptions.filter { $0.enabled }
        
        for (index, subscription) in enabledSubscriptions.enumerated() {
            updateProgress = Double(index) / Double(enabledSubscriptions.count)
            await updateSubscription(subscription.id)
        }
        
        updateProgress = 1.0
        
        // 重新加载服务器列表
        await serverManager.loadServers()
    }
    
    /// 删除订阅
    func deleteSubscription(_ subscriptionID: UUID) async {
        do {
            // 删除订阅相关的服务器
            try await database.deleteServersBySubscription(subscriptionID)
            
            // 删除订阅
            try await database.deleteSubscription(subscriptionID)
            
            if let index = subscriptions.firstIndex(where: { $0.id == subscriptionID }) {
                let deletedSubscription = subscriptions.remove(at: index)
                
                Logger.info("Deleted subscription: \(deletedSubscription.name)")
                
                // 发送通知
                NotificationCenter.default.post(
                    name: .subscriptionDeleted,
                    object: deletedSubscription
                )
            }
            
            // 重新加载服务器列表
            await serverManager.loadServers()
            
        } catch {
            lastError = SubscriptionError.deleteFailed(error)
            Logger.error("Failed to delete subscription: \(error)")
        }
    }
    
    /// 启用/禁用订阅
    func toggleSubscription(_ subscriptionID: UUID) async {
        guard let subscription = subscriptions.first(where: { $0.id == subscriptionID }) else {
            return
        }
        
        var updatedSubscription = subscription
        updatedSubscription.enabled.toggle()
        
        do {
            try await database.updateSubscription(updatedSubscription)
            
            if let index = subscriptions.firstIndex(where: { $0.id == subscriptionID }) {
                subscriptions[index] = updatedSubscription
            }
            
            // 如果启用了订阅，立即更新
            if updatedSubscription.enabled {
                await updateSubscription(subscriptionID)
            }
            
        } catch {
            lastError = SubscriptionError.updateFailed(error)
            Logger.error("Failed to toggle subscription: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAutoUpdate() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAutoUpdate()
            }
        }
    }
    
    private func checkAutoUpdate() async {
        let now = Date()
        
        for subscription in subscriptions {
            guard subscription.enabled && subscription.autoUpdate else { continue }
            
            let nextUpdateTime = subscription.nextUpdateTime
            if now >= nextUpdateTime {
                await updateSubscription(subscription.id)
            }
        }
    }
    
    private func downloadSubscriptionContent(_ subscription: Subscription) async throws -> String {
        let request = URLRequest(
            url: URL(string: subscription.url)!,
            headers: subscription.requestHeaders
        )
        
        let (data, response) = try await networkClient.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw SubscriptionError.downloadFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        guard let content = String(data: data, encoding: .utf8) else {
            throw SubscriptionError.invalidContent("无法解码内容")
        }
        
        return content
    }
    
    private func parseSubscriptionContent(_ content: String, subscription: Subscription) throws -> [ServerConfig] {
        // 检测内容格式
        if content.hasPrefix("vmess://") || content.hasPrefix("vless://") ||
           content.hasPrefix("trojan://") || content.hasPrefix("ss://") {
            // URL格式
            return try parseURLFormat(content, subscription: subscription)
        } else {
            // Base64格式
            return try parseBase64Format(content, subscription: subscription)
        }
    }
    
    private func parseURLFormat(_ content: String, subscription: Subscription) throws -> [ServerConfig] {
        let urls = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var servers: [ServerConfig] = []
        
        for url in urls {
            do {
                var server = try parseServerURL(url)
                server.subscriptionID = subscription.id
                server.group = subscription.groupName
                servers.append(server)
            } catch {
                Logger.warning("Failed to parse URL \(url): \(error)")
            }
        }
        
        return servers
    }
    
    private func parseBase64Format(_ content: String, subscription: Subscription) throws -> [ServerConfig] {
        guard let decodedData = Data(base64Encoded: content),
              let decodedContent = String(data: decodedData, encoding: .utf8) else {
            throw SubscriptionError.invalidContent("Base64解码失败")
        }
        
        return try parseURLFormat(decodedContent, subscription: subscription)
    }
    
    private func parseServerURL(_ url: String) throws -> ServerConfig {
        // 使用ServerManager的URL解析逻辑
        // 这里应该调用ServerManager的parseServerURL方法
        // 为了简化，这里只是一个占位符
        throw SubscriptionError.parseError("URL parsing not implemented")
    }
    
    private func updateSubscriptionServers(_ subscription: Subscription, servers: [ServerConfig]) async throws {
        // 删除旧的服务器
        try await database.deleteServersBySubscription(subscription.id)
        
        // 添加新的服务器
        for server in servers {
            try await database.saveServer(server)
        }
    }
}

// MARK: - 订阅错误
enum SubscriptionError: LocalizedError {
    case loadFailed(Error)
    case saveFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case downloadFailed(String)
    case invalidContent(String)
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "加载订阅失败: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "保存订阅失败: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "更新订阅失败: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "删除订阅失败: \(error.localizedDescription)"
        case .downloadFailed(let message):
            return "下载订阅失败: \(message)"
        case .invalidContent(let message):
            return "订阅内容无效: \(message)"
        case .parseError(let message):
            return "解析错误: \(message)"
        }
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let subscriptionUpdated = Notification.Name("subscriptionUpdated")
    static let subscriptionDeleted = Notification.Name("subscriptionDeleted")
}
```

## 🔧 处理器架构图

```
处理器层 (Handler Layer)
├── 核心处理器 (Core Handlers)
│   ├── ProxyManager (代理管理)
│   ├── V2rayCore (V2ray核心)
│   ├── SystemProxy (系统代理)
│   └── NetworkMonitor (网络监控)
├── 数据处理器 (Data Handlers)
│   ├── ServerManager (服务器管理)
│   ├── SubscriptionManager (订阅管理)
│   ├── ConfigManager (配置管理)
│   └── DatabaseManager (数据库管理)
├── 网络处理器 (Network Handlers)
│   ├── NetworkClient (网络客户端)
│   ├── PingTester (延迟测试)
│   ├── TrafficMonitor (流量监控)
│   └── DNSResolver (DNS解析)
└── 工具处理器 (Utility Handlers)
    ├── LogManager (日志管理)
    ├── NotificationManager (通知管理)
    ├── MenuBarManager (菜单栏管理)
    └── UpdateManager (更新管理)
```

## 🎯 设计原则

### 1. 单一职责原则
- 每个处理器只负责一个特定的业务领域
- 避免处理器之间的职责重叠
- 保持接口简洁明确

### 2. 依赖注入
- 使用依赖注入减少耦合
- 便于单元测试和模拟
- 提高代码的可维护性

### 3. 异步处理
- 使用async/await处理异步操作
- 避免阻塞主线程
- 提供良好的用户体验

### 4. 错误处理
- 统一的错误处理机制
- 详细的错误信息
- 优雅的错误恢复

### 5. 状态管理
- 使用ObservableObject管理状态
- 响应式的状态更新
- 线程安全的状态访问

## 📚 最佳实践

### 1. 代码组织
```swift
// 处理器文件结构
class SomeManager: ObservableObject {
    // MARK: - Static Properties
    static let shared = SomeManager()
    
    // MARK: - Published Properties
    @Published var someState: SomeType
    
    // MARK: - Private Properties
    private let dependency: SomeDependency
    
    // MARK: - Initialization
    private init() { }
    
    // MARK: - Public Methods
    func publicMethod() async { }
    
    // MARK: - Private Methods
    private func privateMethod() { }
}
```

### 2. 错误处理
```swift
// 统一的错误类型
enum SomeManagerError: LocalizedError {
    case someError(String)
    
    var errorDescription: String? {
        switch self {
        case .someError(let message):
            return "错误: \(message)"
        }
    }
}
```

### 3. 日志记录
```swift
// 结构化日志
Logger.info("Operation completed successfully")
Logger.warning("Potential issue detected")
Logger.error("Operation failed: \(error)")
```

### 4. 性能优化
```swift
// 使用TaskGroup进行并发处理
await withTaskGroup(of: Void.self) { group in
    for item in items {
        group.addTask {
            await processItem(item)
        }
    }
}
```

处理器层是V2rayU应用的核心业务逻辑层，通过合理的设计和实现，确保了应用的稳定性、可维护性和扩展性。
# 代理管理功能详解

## 📋 概述

代理管理是V2rayU的核心功能之一，提供了完整的代理配置生命周期管理，包括添加、编辑、删除、导入、导出、测试等操作。该功能支持多种代理协议（VMess、VLess、Shadowsocks、Trojan等），并提供了直观的用户界面和强大的批量操作能力。

## 🎯 功能特性

### 1. 支持的代理协议
- **VMess**: V2Ray原生协议，支持多种传输方式
- **VLess**: 轻量级协议，更好的性能表现
- **Shadowsocks**: 经典的代理协议
- **Trojan**: 基于TLS的代理协议
- **HTTP/HTTPS**: 标准HTTP代理
- **SOCKS5**: 通用代理协议

### 2. 核心功能
- ✅ 添加/编辑/删除代理配置
- ✅ 批量导入/导出代理
- ✅ 延迟测试和连通性检查
- ✅ 代理配置验证
- ✅ 订阅管理和自动更新
- ✅ 配置分组和标签管理
- ✅ 搜索和过滤功能
- ✅ 配置备份和恢复

## 🏗️ 架构设计

### 1. 组件关系图

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ProxyView     │────│  ProxyHandler   │────│ ProxyRepository │
│   (UI Layer)    │    │ (Business Logic)│    │  (Data Layer)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ ProxyEditView   │    │ ProtocolManager │    │   DatabaseManager│
│ ProxyRowView    │    │ ConfigParser    │    │   GRDB.swift    │
│ ProxyListView   │    │ PingTester      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 2. 数据流向

```
User Input → ProxyView → ProxyHandler → ProxyRepository → Database
    ↓            ↓            ↓              ↓             ↓
UI Update ← ViewModel ← Business Logic ← Data Access ← Persistence
```

## 💻 核心实现

### 1. 代理配置模型

```swift
// MARK: - 代理配置模型
struct ProxyConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var serverAddress: String
    var serverPort: Int
    var protocolType: ProxyType
    var isActive: Bool
    var subscriptionId: UUID?
    var createdAt: Date
    var updatedAt: Date
    
    // 协议特定字段
    var userId: String?
    var alterId: Int?
    var security: String?
    var network: String?
    var networkSettings: [String: Any]?
    var tlsSettings: TLSSettings?
    
    // Shadowsocks特定字段
    var method: String?
    var password: String?
    var plugin: String?
    var pluginOpts: String?
    
    // 统计信息
    var lastPingTime: Date?
    var latency: Int?
    var isConnectable: Bool?
    var totalUsage: Int64
    var lastUsedAt: Date?
    
    init(
        name: String,
        serverAddress: String,
        serverPort: Int,
        protocolType: ProxyType
    ) {
        self.id = UUID()
        self.name = name
        self.serverAddress = serverAddress
        self.serverPort = serverPort
        self.protocolType = protocolType
        self.isActive = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.totalUsage = 0
    }
}

// MARK: - TLS设置
struct TLSSettings: Codable, Equatable {
    var serverName: String?
    var allowInsecure: Bool
    var alpn: [String]?
    var fingerprint: String?
    
    init() {
        self.allowInsecure = false
    }
}

// MARK: - 代理类型
enum ProxyType: String, CaseIterable, Codable {
    case vmess = "vmess"
    case vless = "vless"
    case shadowsocks = "shadowsocks"
    case trojan = "trojan"
    case http = "http"
    case socks5 = "socks5"
    
    var displayName: String {
        switch self {
        case .vmess: return "VMess"
        case .vless: return "VLess"
        case .shadowsocks: return "Shadowsocks"
        case .trojan: return "Trojan"
        case .http: return "HTTP"
        case .socks5: return "SOCKS5"
        }
    }
    
    var defaultPort: Int {
        switch self {
        case .vmess, .vless: return 443
        case .shadowsocks: return 8388
        case .trojan: return 443
        case .http: return 8080
        case .socks5: return 1080
        }
    }
    
    var supportsTLS: Bool {
        switch self {
        case .vmess, .vless, .trojan: return true
        case .shadowsocks, .http, .socks5: return false
        }
    }
}
```

### 2. 代理处理器实现

```swift
// MARK: - 代理处理器
@MainActor
class ProxyHandler: AsyncHandler {
    private let repository: ProxyRepositoryProtocol
    private let networkService: NetworkServiceProtocol
    private let systemProxyService: SystemProxyServiceProtocol
    private let configParser: ConfigParserProtocol
    private let pingTester: PingTester
    
    @Published var proxies: [ProxyConfig] = []
    @Published var activeProxy: ProxyConfig?
    @Published var searchText = ""
    @Published var selectedProtocol: ProxyType?
    @Published var sortOrder: ProxySortOrder = .name
    
    init(
        repository: ProxyRepositoryProtocol,
        networkService: NetworkServiceProtocol,
        systemProxyService: SystemProxyServiceProtocol,
        configParser: ConfigParserProtocol,
        pingTester: PingTester
    ) {
        self.repository = repository
        self.networkService = networkService
        self.systemProxyService = systemProxyService
        self.configParser = configParser
        self.pingTester = pingTester
        super.init()
        
        setupObservers()
    }
    
    // MARK: - 公共方法
    
    /// 加载所有代理配置
    func loadProxies() async {
        await performAsyncOperation {
            let allProxies = try await self.repository.getAllProxies()
            await MainActor.run {
                self.proxies = self.filterAndSortProxies(allProxies)
                self.activeProxy = allProxies.first { $0.isActive }
            }
        }
    }
    
    /// 添加代理配置
    func addProxy(_ proxy: ProxyConfig) async {
        await performAsyncOperation {
            // 验证配置
            try self.validateProxyConfig(proxy)
            
            // 保存到数据库
            try await self.repository.addProxy(proxy)
            
            // 更新本地列表
            await MainActor.run {
                self.proxies.append(proxy)
                self.proxies = self.filterAndSortProxies(self.proxies)
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .proxyAdded,
                object: proxy
            )
            
            self.logger.info("代理添加成功: \(proxy.name)")
        }
    }
    
    /// 更新代理配置
    func updateProxy(_ proxy: ProxyConfig) async {
        await performAsyncOperation {
            // 验证配置
            try self.validateProxyConfig(proxy)
            
            // 更新数据库
            var updatedProxy = proxy
            updatedProxy.updatedAt = Date()
            try await self.repository.updateProxy(updatedProxy)
            
            // 更新本地列表
            await MainActor.run {
                if let index = self.proxies.firstIndex(where: { $0.id == proxy.id }) {
                    self.proxies[index] = updatedProxy
                    self.proxies = self.filterAndSortProxies(self.proxies)
                }
                
                if self.activeProxy?.id == proxy.id {
                    self.activeProxy = updatedProxy
                }
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .proxyUpdated,
                object: updatedProxy
            )
            
            self.logger.info("代理更新成功: \(proxy.name)")
        }
    }
    
    /// 删除代理配置
    func deleteProxy(_ proxy: ProxyConfig) async {
        await performAsyncOperation {
            // 如果是当前激活的代理，先停用
            if proxy.isActive {
                try await self.deactivateProxy()
            }
            
            // 从数据库删除
            try await self.repository.deleteProxy(proxy.id)
            
            // 更新本地列表
            await MainActor.run {
                self.proxies.removeAll { $0.id == proxy.id }
                if self.activeProxy?.id == proxy.id {
                    self.activeProxy = nil
                }
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .proxyDeleted,
                object: proxy
            )
            
            self.logger.info("代理删除成功: \(proxy.name)")
        }
    }
    
    /// 激活代理
    func activateProxy(_ proxy: ProxyConfig) async {
        await performAsyncOperation {
            // 先停用当前代理
            if let currentActive = self.activeProxy {
                try await self.repository.setProxyActive(currentActive.id, isActive: false)
            }
            
            // 激活新代理
            try await self.repository.setProxyActive(proxy.id, isActive: true)
            
            // 配置系统代理
            try await self.systemProxyService.enableSystemProxy(
                host: "127.0.0.1",
                port: 1080  // V2Ray本地端口
            )
            
            // 更新本地状态
            await MainActor.run {
                // 更新代理列表中的状态
                for i in 0..<self.proxies.count {
                    self.proxies[i].isActive = (self.proxies[i].id == proxy.id)
                }
                
                var activatedProxy = proxy
                activatedProxy.isActive = true
                activatedProxy.lastUsedAt = Date()
                self.activeProxy = activatedProxy
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .proxyActivated,
                object: proxy
            )
            
            self.logger.info("代理激活成功: \(proxy.name)")
        }
    }
    
    /// 停用代理
    func deactivateProxy() async {
        await performAsyncOperation {
            guard let activeProxy = self.activeProxy else { return }
            
            // 停用数据库中的代理
            try await self.repository.setProxyActive(activeProxy.id, isActive: false)
            
            // 禁用系统代理
            try await self.systemProxyService.disableSystemProxy()
            
            // 更新本地状态
            await MainActor.run {
                for i in 0..<self.proxies.count {
                    self.proxies[i].isActive = false
                }
                self.activeProxy = nil
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .proxyDeactivated,
                object: activeProxy
            )
            
            self.logger.info("代理停用成功: \(activeProxy.name)")
        }
    }
    
    /// 测试代理延迟
    func testProxy(_ proxy: ProxyConfig) async {
        await performAsyncOperation {
            let latency = try await self.pingTester.testProxy(proxy)
            
            // 更新代理信息
            var updatedProxy = proxy
            updatedProxy.latency = latency
            updatedProxy.lastPingTime = Date()
            updatedProxy.isConnectable = true
            
            try await self.repository.updateProxy(updatedProxy)
            
            // 更新本地列表
            await MainActor.run {
                if let index = self.proxies.firstIndex(where: { $0.id == proxy.id }) {
                    self.proxies[index] = updatedProxy
                }
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .proxyTested,
                object: updatedProxy
            )
            
            self.logger.info("代理测试完成: \(proxy.name) = \(latency)ms")
        }
    }
    
    /// 批量测试代理
    func testAllProxies() async {
        await performAsyncOperation {
            let testableProxies = self.proxies.filter { !$0.serverAddress.isEmpty }
            
            self.logger.info("开始批量测试 \(testableProxies.count) 个代理")
            
            let results = try await self.pingTester.testProxies(testableProxies)
            
            // 更新代理信息
            var updatedProxies: [ProxyConfig] = []
            
            for proxy in testableProxies {
                var updatedProxy = proxy
                updatedProxy.lastPingTime = Date()
                
                if let latency = results[proxy.id] {
                    updatedProxy.latency = latency
                    updatedProxy.isConnectable = true
                } else {
                    updatedProxy.latency = nil
                    updatedProxy.isConnectable = false
                }
                
                updatedProxies.append(updatedProxy)
            }
            
            // 批量更新数据库
            for proxy in updatedProxies {
                try await self.repository.updateProxy(proxy)
            }
            
            // 更新本地列表
            await MainActor.run {
                for updatedProxy in updatedProxies {
                    if let index = self.proxies.firstIndex(where: { $0.id == updatedProxy.id }) {
                        self.proxies[index] = updatedProxy
                    }
                }
                self.proxies = self.filterAndSortProxies(self.proxies)
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .proxiesBatchTested,
                object: results
            )
            
            self.logger.info("批量测试完成，成功 \(results.count)/\(testableProxies.count) 个")
        }
    }
    
    /// 导入代理配置
    func importProxies(from content: String) async {
        await performAsyncOperation {
            let importedProxies = try self.configParser.parseSubscriptionContent(content)
            
            self.logger.info("准备导入 \(importedProxies.count) 个代理")
            
            var successCount = 0
            var failedCount = 0
            
            for proxy in importedProxies {
                do {
                    try self.validateProxyConfig(proxy)
                    try await self.repository.addProxy(proxy)
                    successCount += 1
                } catch {
                    self.logger.warning("导入代理失败: \(proxy.name) - \(error)")
                    failedCount += 1
                }
            }
            
            // 重新加载代理列表
            await self.loadProxies()
            
            // 发送通知
            NotificationCenter.default.post(
                name: .proxiesImported,
                object: ["success": successCount, "failed": failedCount]
            )
            
            self.logger.info("代理导入完成，成功 \(successCount) 个，失败 \(failedCount) 个")
        }
    }
    
    /// 导出代理配置
    func exportProxies(_ proxies: [ProxyConfig]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let content = try self.configParser.exportProxies(proxies)
                    continuation.resume(returning: content)
                    
                    self.logger.info("代理导出成功，共 \(proxies.count) 个")
                } catch {
                    continuation.resume(throwing: error)
                    self.logger.error("代理导出失败: \(error)")
                }
            }
        }
    }
    
    // MARK: - 搜索和过滤
    
    /// 更新搜索文本
    func updateSearchText(_ text: String) {
        searchText = text
        proxies = filterAndSortProxies(proxies)
    }
    
    /// 更新协议过滤
    func updateProtocolFilter(_ protocol: ProxyType?) {
        selectedProtocol = `protocol`
        proxies = filterAndSortProxies(proxies)
    }
    
    /// 更新排序方式
    func updateSortOrder(_ order: ProxySortOrder) {
        sortOrder = order
        proxies = filterAndSortProxies(proxies)
    }
    
    // MARK: - 私有方法
    
    private func setupObservers() {
        // 监听搜索文本变化
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }
    
    private func applyFilters() {
        Task {
            await loadProxies()
        }
    }
    
    private func filterAndSortProxies(_ proxies: [ProxyConfig]) -> [ProxyConfig] {
        var filtered = proxies
        
        // 应用搜索过滤
        if !searchText.isEmpty {
            filtered = filtered.filter { proxy in
                proxy.name.localizedCaseInsensitiveContains(searchText) ||
                proxy.serverAddress.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 应用协议过滤
        if let selectedProtocol = selectedProtocol {
            filtered = filtered.filter { $0.protocolType == selectedProtocol }
        }
        
        // 应用排序
        switch sortOrder {
        case .name:
            filtered.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .latency:
            filtered.sort { (lhs, rhs) in
                switch (lhs.latency, rhs.latency) {
                case (nil, nil): return false
                case (nil, _): return false
                case (_, nil): return true
                case (let l?, let r?): return l < r
                }
            }
        case .protocol:
            filtered.sort { $0.protocolType.rawValue < $1.protocolType.rawValue }
        case .createdAt:
            filtered.sort { $0.createdAt > $1.createdAt }
        }
        
        return filtered
    }
    
    private func validateProxyConfig(_ proxy: ProxyConfig) throws {
        guard !proxy.name.isEmpty else {
            throw ProxyError.invalidName
        }
        
        guard !proxy.serverAddress.isEmpty else {
            throw ProxyError.invalidServerAddress
        }
        
        guard proxy.serverPort > 0 && proxy.serverPort <= 65535 else {
            throw ProxyError.invalidPort
        }
        
        // 协议特定验证
        switch proxy.protocolType {
        case .vmess, .vless:
            guard let userId = proxy.userId, !userId.isEmpty else {
                throw ProxyError.invalidUserId
            }
            
        case .shadowsocks:
            guard let method = proxy.method, !method.isEmpty else {
                throw ProxyError.invalidMethod
            }
            guard let password = proxy.password, !password.isEmpty else {
                throw ProxyError.invalidPassword
            }
            
        case .trojan:
            guard let password = proxy.password, !password.isEmpty else {
                throw ProxyError.invalidPassword
            }
            
        case .http, .socks5:
            // HTTP和SOCKS5代理的基本验证已经完成
            break
        }
    }
}

// MARK: - 排序方式
enum ProxySortOrder: String, CaseIterable {
    case name = "name"
    case latency = "latency"
    case `protocol` = "protocol"
    case createdAt = "createdAt"
    
    var displayName: String {
        switch self {
        case .name: return "名称"
        case .latency: return "延迟"
        case .protocol: return "协议"
        case .createdAt: return "创建时间"
        }
    }
}

// MARK: - 代理错误
enum ProxyError: LocalizedError {
    case invalidName
    case invalidServerAddress
    case invalidPort
    case invalidUserId
    case invalidMethod
    case invalidPassword
    case proxyNotFound
    case activationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "代理名称不能为空"
        case .invalidServerAddress:
            return "服务器地址不能为空"
        case .invalidPort:
            return "端口号必须在1-65535之间"
        case .invalidUserId:
            return "用户ID不能为空"
        case .invalidMethod:
            return "加密方法不能为空"
        case .invalidPassword:
            return "密码不能为空"
        case .proxyNotFound:
            return "代理配置不存在"
        case .activationFailed:
            return "代理激活失败"
        }
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let proxyAdded = Notification.Name("proxyAdded")
    static let proxyUpdated = Notification.Name("proxyUpdated")
    static let proxyDeleted = Notification.Name("proxyDeleted")
    static let proxyActivated = Notification.Name("proxyActivated")
    static let proxyDeactivated = Notification.Name("proxyDeactivated")
    static let proxyTested = Notification.Name("proxyTested")
    static let proxiesBatchTested = Notification.Name("proxiesBatchTested")
    static let proxiesImported = Notification.Name("proxiesImported")
}
```

### 3. 用户界面实现

```swift
// MARK: - 代理列表视图
struct ProxyListView: View {
    @StateObject private var handler = HandlerManager.shared.proxyHandler
    @State private var showingAddProxy = false
    @State private var showingImportDialog = false
    @State private var selectedProxies: Set<ProxyConfig.ID> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            ProxyToolbarView(
                showingAddProxy: $showingAddProxy,
                showingImportDialog: $showingImportDialog,
                selectedProxies: $selectedProxies,
                handler: handler
            )
            
            // 搜索和过滤栏
            ProxyFilterView(handler: handler)
            
            // 代理列表
            if handler.proxies.isEmpty {
                ProxyEmptyView()
            } else {
                ProxyTableView(
                    proxies: handler.proxies,
                    selectedProxies: $selectedProxies,
                    handler: handler
                )
            }
        }
        .sheet(isPresented: $showingAddProxy) {
            ProxyEditView(handler: handler)
        }
        .sheet(isPresented: $showingImportDialog) {
            ProxyImportView(handler: handler)
        }
        .task {
            await handler.loadProxies()
        }
    }
}

// MARK: - 代理工具栏
struct ProxyToolbarView: View {
    @Binding var showingAddProxy: Bool
    @Binding var showingImportDialog: Bool
    @Binding var selectedProxies: Set<ProxyConfig.ID>
    let handler: ProxyHandler
    
    var body: some View {
        HStack {
            // 添加按钮
            Button("添加代理") {
                showingAddProxy = true
            }
            .buttonStyle(.borderedProminent)
            
            // 导入按钮
            Button("导入") {
                showingImportDialog = true
            }
            
            // 导出按钮
            Button("导出") {
                exportSelectedProxies()
            }
            .disabled(selectedProxies.isEmpty)
            
            Spacer()
            
            // 测试按钮
            Button("测试全部") {
                Task {
                    await handler.testAllProxies()
                }
            }
            .disabled(handler.isLoading)
            
            // 删除按钮
            Button("删除") {
                deleteSelectedProxies()
            }
            .disabled(selectedProxies.isEmpty)
            .foregroundColor(.red)
        }
        .padding()
    }
    
    private func exportSelectedProxies() {
        let proxiesToExport = handler.proxies.filter { selectedProxies.contains($0.id) }
        
        Task {
            do {
                let content = try await handler.exportProxies(proxiesToExport)
                
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.plainText]
                savePanel.nameFieldStringValue = "proxies.txt"
                
                if savePanel.runModal() == .OK {
                    if let url = savePanel.url {
                        try content.write(to: url, atomically: true, encoding: .utf8)
                    }
                }
            } catch {
                // 显示错误
            }
        }
    }
    
    private func deleteSelectedProxies() {
        let proxiesToDelete = handler.proxies.filter { selectedProxies.contains($0.id) }
        
        Task {
            for proxy in proxiesToDelete {
                await handler.deleteProxy(proxy)
            }
            selectedProxies.removeAll()
        }
    }
}

// MARK: - 代理过滤视图
struct ProxyFilterView: View {
    @ObservedObject var handler: ProxyHandler
    
    var body: some View {
        HStack {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索代理...", text: $handler.searchText)
                    .textFieldStyle(.plain)
                
                if !handler.searchText.isEmpty {
                    Button(action: { handler.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            
            // 协议过滤
            Picker("协议", selection: $handler.selectedProtocol) {
                Text("全部协议").tag(ProxyType?.none)
                ForEach(ProxyType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type as ProxyType?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            
            // 排序方式
            Picker("排序", selection: $handler.sortOrder) {
                ForEach(ProxySortOrder.allCases, id: \.self) { order in
                    Text(order.displayName).tag(order)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - 代理表格视图
struct ProxyTableView: View {
    let proxies: [ProxyConfig]
    @Binding var selectedProxies: Set<ProxyConfig.ID>
    let handler: ProxyHandler
    
    var body: some View {
        Table(proxies, selection: $selectedProxies) {
            TableColumn("状态", value: \.isActive) { proxy in
                StatusIndicator(isActive: proxy.isActive)
            }
            .width(60)
            
            TableColumn("名称", value: \.name) { proxy in
                Text(proxy.name)
                    .font(.system(.body, design: .default))
            }
            .width(min: 150, ideal: 200, max: 300)
            
            TableColumn("协议", value: \.protocolType.rawValue) { proxy in
                ProtocolBadge(type: proxy.protocolType)
            }
            .width(80)
            
            TableColumn("服务器", value: \.serverAddress) { proxy in
                Text(proxy.serverAddress)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .width(min: 120, ideal: 150, max: 200)
            
            TableColumn("端口", value: \.serverPort) { proxy in
                Text("\(proxy.serverPort)")
                    .font(.system(.caption, design: .monospaced))
            }
            .width(60)
            
            TableColumn("延迟", value: \.latency) { proxy in
                LatencyIndicator(latency: proxy.latency)
            }
            .width(80)
            
            TableColumn("操作") { proxy in
                ProxyActionButtons(proxy: proxy, handler: handler)
            }
            .width(120)
        }
        .contextMenu(forSelectionType: ProxyConfig.ID.self) { selection in
            if selection.count == 1,
               let proxyId = selection.first,
               let proxy = proxies.first(where: { $0.id == proxyId }) {
                
                Button(proxy.isActive ? "停用" : "激活") {
                    Task {
                        if proxy.isActive {
                            await handler.deactivateProxy()
                        } else {
                            await handler.activateProxy(proxy)
                        }
                    }
                }
                
                Button("测试延迟") {
                    Task {
                        await handler.testProxy(proxy)
                    }
                }
                
                Divider()
                
                Button("删除") {
                    Task {
                        await handler.deleteProxy(proxy)
                    }
                }
                .foregroundColor(.red)
            }
        }
    }
}

// MARK: - 代理操作按钮
struct ProxyActionButtons: View {
    let proxy: ProxyConfig
    let handler: ProxyHandler
    
    var body: some View {
        HStack(spacing: 4) {
            // 激活/停用按钮
            Button(action: {
                Task {
                    if proxy.isActive {
                        await handler.deactivateProxy()
                    } else {
                        await handler.activateProxy(proxy)
                    }
                }
            }) {
                Image(systemName: proxy.isActive ? "stop.circle" : "play.circle")
            }
            .buttonStyle(.plain)
            .foregroundColor(proxy.isActive ? .red : .green)
            
            // 测试按钮
            Button(action: {
                Task {
                    await handler.testProxy(proxy)
                }
            }) {
                Image(systemName: "speedometer")
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
            
            // 编辑按钮
            Button(action: {
                // 显示编辑界面
            }) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .foregroundColor(.orange)
        }
    }
}
```

## 🔧 使用示例

### 1. 添加VMess代理

```swift
let vmessProxy = ProxyConfig(
    name: "香港节点01",
    serverAddress: "hk01.example.com",
    serverPort: 443,
    protocolType: .vmess
)
vmessProxy.userId = "12345678-1234-1234-1234-123456789abc"
vmessProxy.alterId = 0
vmessProxy.security = "auto"
vmessProxy.network = "ws"
vmessProxy.tlsSettings = TLSSettings()
vmessProxy.tlsSettings?.serverName = "hk01.example.com"

await proxyHandler.addProxy(vmessProxy)
```

### 2. 批量导入代理

```swift
let subscriptionContent = """
vmess://eyJ2IjoiMiIsInBzIjoi...
vless://12345678-1234-1234-1234-123456789abc@...
ss://YWVzLTI1Ni1nY206...
"""

await proxyHandler.importProxies(from: subscriptionContent)
```

### 3. 测试代理延迟

```swift
// 测试单个代理
await proxyHandler.testProxy(proxy)

// 批量测试所有代理
await proxyHandler.testAllProxies()
```

## 📚 相关文档

- [协议层模块](../modules/protocol-layer.md)
- [数据库层模块](../modules/database-layer.md)
- [处理器层模块](../modules/handler-layer.md)
- [订阅同步功能](subscription-sync.md)
- [延迟测试功能](ping-testing.md)

---

*本文档详细介绍了V2rayU代理管理功能的设计与实现，为开发者提供了完整的代理配置管理解决方案。*
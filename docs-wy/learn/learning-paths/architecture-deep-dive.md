# 架构深度解析

## 📋 概述

本文档深入分析V2rayU的架构设计，从系统架构、设计模式、技术选型到性能优化等多个维度，为开发者提供全面的架构理解和设计指导。

---

## 🏗️ 系统架构总览

### 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        V2rayU 系统架构                        │
├─────────────────────────────────────────────────────────────┤
│  Presentation Layer (表示层)                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   SwiftUI   │  │   MenuBar   │  │ Preferences │          │
│  │    Views    │  │   Interface │  │   Window    │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  Business Logic Layer (业务逻辑层)                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Proxy     │  │ Subscription│  │   System    │          │
│  │  Manager    │  │   Manager   │  │   Proxy     │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Traffic   │  │    Ping     │  │   Config    │          │
│  │   Monitor   │  │   Tester    │  │   Parser    │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  Data Access Layer (数据访问层)                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │    GRDB     │  │  UserDefaults│  │   Keychain  │          │
│  │  Database   │  │   Storage   │  │   Storage   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  Infrastructure Layer (基础设施层)                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Network   │  │   Security  │  │   Logging   │          │
│  │   Service   │  │   Service   │  │   Service   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   V2ray     │  │   System    │  │   File      │          │
│  │    Core     │  │   APIs      │  │   Manager   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

### 架构层次说明

#### 1. 表示层 (Presentation Layer)
**职责**：用户界面展示和交互处理

**组件**：
- **SwiftUI Views**：主要用户界面组件
- **MenuBar Interface**：菜单栏交互界面
- **Preferences Window**：设置和配置界面

**设计原则**：
- 单一职责：每个视图只负责特定的UI功能
- 数据绑定：使用@ObservedObject和@StateObject进行数据绑定
- 响应式设计：支持不同屏幕尺寸和主题

#### 2. 业务逻辑层 (Business Logic Layer)
**职责**：核心业务逻辑处理和协调

**组件**：
- **Proxy Manager**：代理配置管理
- **Subscription Manager**：订阅管理和同步
- **System Proxy**：系统代理设置
- **Traffic Monitor**：流量监控和统计
- **Ping Tester**：延迟测试
- **Config Parser**：配置解析和验证

**设计原则**：
- 业务封装：将复杂的业务逻辑封装在专门的管理器中
- 异步处理：使用async/await处理耗时操作
- 错误处理：统一的错误处理和恢复机制

#### 3. 数据访问层 (Data Access Layer)
**职责**：数据持久化和存储管理

**组件**：
- **GRDB Database**：主要数据存储
- **UserDefaults Storage**：用户偏好设置
- **Keychain Storage**：敏感信息存储

**设计原则**：
- 数据抽象：通过Repository模式抽象数据访问
- 事务管理：保证数据一致性
- 性能优化：合理使用索引和查询优化

#### 4. 基础设施层 (Infrastructure Layer)
**职责**：提供底层技术服务和支持

**组件**：
- **Network Service**：网络通信服务
- **Security Service**：安全和加密服务
- **Logging Service**：日志记录服务
- **V2ray Core**：V2ray核心引擎
- **System APIs**：系统API调用
- **File Manager**：文件系统管理

**设计原则**：
- 服务化：将基础功能封装为独立服务
- 可配置：支持灵活的配置和扩展
- 高可用：提供稳定可靠的基础服务

---

## 🎯 设计模式深度分析

### 1. MVVM (Model-View-ViewModel) 模式

#### 架构实现
```swift
// Model层：数据模型和业务逻辑
struct ProxyConfig: Codable, Identifiable {
    let id: UUID
    var name: String
    var serverAddress: String
    var serverPort: Int
    var protocol: ProxyProtocol
    var isEnabled: Bool
    
    // 业务逻辑方法
    func validate() throws {
        guard !name.isEmpty else {
            throw ValidationError.emptyName
        }
        
        guard serverPort > 0 && serverPort <= 65535 else {
            throw ValidationError.invalidPort
        }
        
        // 更多验证逻辑...
    }
}

// ViewModel层：视图状态管理和业务协调
@MainActor
class ProxyListViewModel: ObservableObject {
    @Published var proxies: [ProxyConfig] = []
    @Published var selectedProxy: ProxyConfig?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let proxyManager: ProxyManager
    private let databaseManager: DatabaseManager
    
    init(proxyManager: ProxyManager, databaseManager: DatabaseManager) {
        self.proxyManager = proxyManager
        self.databaseManager = databaseManager
        
        setupBindings()
    }
    
    // 视图操作方法
    func loadProxies() async {
        isLoading = true
        errorMessage = nil
        
        do {
            proxies = try await databaseManager.fetchProxies()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func addProxy(_ proxy: ProxyConfig) async {
        do {
            try proxy.validate()
            try await databaseManager.saveProxy(proxy)
            await loadProxies()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteProxy(_ proxy: ProxyConfig) async {
        do {
            try await databaseManager.deleteProxy(proxy)
            await loadProxies()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func selectProxy(_ proxy: ProxyConfig) async {
        selectedProxy = proxy
        
        do {
            try await proxyManager.activateProxy(proxy)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func setupBindings() {
        // 监听代理管理器状态变化
        proxyManager.activeProxyPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedProxy)
    }
}

// View层：用户界面
struct ProxyListView: View {
    @StateObject private var viewModel: ProxyListViewModel
    @State private var showingAddProxy = false
    
    init(viewModel: ProxyListViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("加载中...")
                } else {
                    List(viewModel.proxies) { proxy in
                        ProxyRowView(
                            proxy: proxy,
                            isSelected: proxy.id == viewModel.selectedProxy?.id
                        )
                        .onTapGesture {
                            Task {
                                await viewModel.selectProxy(proxy)
                            }
                        }
                    }
                }
            }
            .navigationTitle("代理列表")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("添加") {
                        showingAddProxy = true
                    }
                }
            }
            .sheet(isPresented: $showingAddProxy) {
                AddProxyView { proxy in
                    Task {
                        await viewModel.addProxy(proxy)
                    }
                }
            }
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("确定") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .task {
            await viewModel.loadProxies()
        }
    }
}
```

#### MVVM优势分析
1. **关注点分离**：View专注UI，ViewModel处理逻辑，Model管理数据
2. **可测试性**：ViewModel可以独立测试，不依赖UI框架
3. **数据绑定**：通过@Published和@ObservedObject实现自动UI更新
4. **可维护性**：清晰的层次结构便于维护和扩展

### 2. Repository 模式

#### 数据访问抽象
```swift
// Repository协议定义
protocol ProxyRepository {
    func fetchAll() async throws -> [ProxyConfig]
    func fetch(by id: UUID) async throws -> ProxyConfig?
    func save(_ proxy: ProxyConfig) async throws
    func delete(_ proxy: ProxyConfig) async throws
    func update(_ proxy: ProxyConfig) async throws
}

// GRDB实现
class GRDBProxyRepository: ProxyRepository {
    private let database: DatabaseManager
    
    init(database: DatabaseManager) {
        self.database = database
    }
    
    func fetchAll() async throws -> [ProxyConfig] {
        return try await database.read { db in
            try ProxyConfig.fetchAll(db)
        }
    }
    
    func fetch(by id: UUID) async throws -> ProxyConfig? {
        return try await database.read { db in
            try ProxyConfig.fetchOne(db, key: id)
        }
    }
    
    func save(_ proxy: ProxyConfig) async throws {
        try await database.write { db in
            try proxy.insert(db)
        }
    }
    
    func delete(_ proxy: ProxyConfig) async throws {
        try await database.write { db in
            try proxy.delete(db)
        }
    }
    
    func update(_ proxy: ProxyConfig) async throws {
        try await database.write { db in
            try proxy.update(db)
        }
    }
}

// 内存实现（用于测试）
class InMemoryProxyRepository: ProxyRepository {
    private var proxies: [UUID: ProxyConfig] = [:]
    private let queue = DispatchQueue(label: "repository.queue", attributes: .concurrent)
    
    func fetchAll() async throws -> [ProxyConfig] {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: Array(self.proxies.values))
            }
        }
    }
    
    func fetch(by id: UUID) async throws -> ProxyConfig? {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.proxies[id])
            }
        }
    }
    
    func save(_ proxy: ProxyConfig) async throws {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.proxies[proxy.id] = proxy
                continuation.resume()
            }
        }
    }
    
    func delete(_ proxy: ProxyConfig) async throws {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.proxies.removeValue(forKey: proxy.id)
                continuation.resume()
            }
        }
    }
    
    func update(_ proxy: ProxyConfig) async throws {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.proxies[proxy.id] = proxy
                continuation.resume()
            }
        }
    }
}
```

### 3. Observer 模式

#### 事件通知系统
```swift
// 事件定义
enum ProxyEvent {
    case configurationChanged(ProxyConfig)
    case connectionStatusChanged(Bool)
    case trafficUpdated(TrafficStats)
    case errorOccurred(Error)
}

// 观察者协议
protocol ProxyEventObserver: AnyObject {
    func handleProxyEvent(_ event: ProxyEvent)
}

// 事件发布者
class ProxyEventPublisher {
    private var observers: [WeakObserver] = []
    private let queue = DispatchQueue(label: "event.publisher", attributes: .concurrent)
    
    func addObserver(_ observer: ProxyEventObserver) {
        queue.async(flags: .barrier) {
            self.observers.append(WeakObserver(observer))
            self.cleanupObservers()
        }
    }
    
    func removeObserver(_ observer: ProxyEventObserver) {
        queue.async(flags: .barrier) {
            self.observers.removeAll { $0.observer === observer }
        }
    }
    
    func publishEvent(_ event: ProxyEvent) {
        queue.async {
            let currentObservers = self.observers.compactMap { $0.observer }
            
            DispatchQueue.main.async {
                for observer in currentObservers {
                    observer.handleProxyEvent(event)
                }
            }
        }
    }
    
    private func cleanupObservers() {
        observers.removeAll { $0.observer == nil }
    }
}

// 弱引用包装器
private class WeakObserver {
    weak var observer: ProxyEventObserver?
    
    init(_ observer: ProxyEventObserver) {
        self.observer = observer
    }
}

// 使用示例
class ProxyManager: ProxyEventObserver {
    private let eventPublisher = ProxyEventPublisher()
    
    init() {
        eventPublisher.addObserver(self)
    }
    
    func handleProxyEvent(_ event: ProxyEvent) {
        switch event {
        case .configurationChanged(let config):
            handleConfigurationChange(config)
        case .connectionStatusChanged(let isConnected):
            handleConnectionStatusChange(isConnected)
        case .trafficUpdated(let stats):
            handleTrafficUpdate(stats)
        case .errorOccurred(let error):
            handleError(error)
        }
    }
    
    private func handleConfigurationChange(_ config: ProxyConfig) {
        // 处理配置变更
    }
    
    private func handleConnectionStatusChange(_ isConnected: Bool) {
        // 处理连接状态变更
    }
    
    private func handleTrafficUpdate(_ stats: TrafficStats) {
        // 处理流量统计更新
    }
    
    private func handleError(_ error: Error) {
        // 处理错误
    }
}
```

### 4. Strategy 模式

#### 协议处理策略
```swift
// 协议处理策略接口
protocol ProxyProtocolStrategy {
    var protocolType: ProxyProtocol { get }
    func createConfiguration(_ config: ProxyConfig) throws -> [String: Any]
    func validateConfiguration(_ config: ProxyConfig) throws
    func parseConfiguration(_ data: [String: Any]) throws -> ProxyConfig
}

// VMess协议策略
class VMessProtocolStrategy: ProxyProtocolStrategy {
    let protocolType: ProxyProtocol = .vmess
    
    func createConfiguration(_ config: ProxyConfig) throws -> [String: Any] {
        guard case .vmess(let vmessConfig) = config.protocolConfig else {
            throw ProtocolError.invalidConfiguration
        }
        
        return [
            "protocol": "vmess",
            "settings": [
                "vnext": [[
                    "address": config.serverAddress,
                    "port": config.serverPort,
                    "users": [[
                        "id": vmessConfig.userId,
                        "security": vmessConfig.security,
                        "level": vmessConfig.level
                    ]]
                ]]
            ],
            "streamSettings": createStreamSettings(vmessConfig)
        ]
    }
    
    func validateConfiguration(_ config: ProxyConfig) throws {
        guard case .vmess(let vmessConfig) = config.protocolConfig else {
            throw ProtocolError.invalidConfiguration
        }
        
        guard UUID(uuidString: vmessConfig.userId) != nil else {
            throw ProtocolError.invalidUserId
        }
        
        guard ["auto", "aes-128-gcm", "chacha20-poly1305", "none"].contains(vmessConfig.security) else {
            throw ProtocolError.invalidSecurity
        }
    }
    
    func parseConfiguration(_ data: [String: Any]) throws -> ProxyConfig {
        // 解析VMess配置
        // 实现配置解析逻辑
        fatalError("Not implemented")
    }
    
    private func createStreamSettings(_ config: VMessConfig) -> [String: Any] {
        var streamSettings: [String: Any] = [:]
        
        // 传输协议设置
        streamSettings["network"] = config.network
        
        switch config.network {
        case "tcp":
            streamSettings["tcpSettings"] = createTCPSettings(config)
        case "ws":
            streamSettings["wsSettings"] = createWSSettings(config)
        case "h2":
            streamSettings["httpSettings"] = createHTTPSettings(config)
        default:
            break
        }
        
        // TLS设置
        if config.tls == "tls" {
            streamSettings["security"] = "tls"
            streamSettings["tlsSettings"] = createTLSSettings(config)
        }
        
        return streamSettings
    }
    
    private func createTCPSettings(_ config: VMessConfig) -> [String: Any] {
        return [:] // TCP设置
    }
    
    private func createWSSettings(_ config: VMessConfig) -> [String: Any] {
        return [
            "path": config.path ?? "/",
            "headers": config.headers ?? [:]
        ]
    }
    
    private func createHTTPSettings(_ config: VMessConfig) -> [String: Any] {
        return [
            "path": config.path ?? "/",
            "host": config.host ?? []
        ]
    }
    
    private func createTLSSettings(_ config: VMessConfig) -> [String: Any] {
        var tlsSettings: [String: Any] = [:]
        
        if let serverName = config.serverName {
            tlsSettings["serverName"] = serverName
        }
        
        tlsSettings["allowInsecure"] = config.allowInsecure
        
        return tlsSettings
    }
}

// Shadowsocks协议策略
class ShadowsocksProtocolStrategy: ProxyProtocolStrategy {
    let protocolType: ProxyProtocol = .shadowsocks
    
    func createConfiguration(_ config: ProxyConfig) throws -> [String: Any] {
        guard case .shadowsocks(let ssConfig) = config.protocolConfig else {
            throw ProtocolError.invalidConfiguration
        }
        
        return [
            "protocol": "shadowsocks",
            "settings": [
                "servers": [[
                    "address": config.serverAddress,
                    "port": config.serverPort,
                    "method": ssConfig.method,
                    "password": ssConfig.password
                ]]
            ]
        ]
    }
    
    func validateConfiguration(_ config: ProxyConfig) throws {
        guard case .shadowsocks(let ssConfig) = config.protocolConfig else {
            throw ProtocolError.invalidConfiguration
        }
        
        let supportedMethods = [
            "aes-256-gcm", "aes-128-gcm", "chacha20-poly1305",
            "aes-256-cfb", "aes-128-cfb", "chacha20", "salsa20"
        ]
        
        guard supportedMethods.contains(ssConfig.method) else {
            throw ProtocolError.unsupportedMethod
        }
        
        guard !ssConfig.password.isEmpty else {
            throw ProtocolError.emptyPassword
        }
    }
    
    func parseConfiguration(_ data: [String: Any]) throws -> ProxyConfig {
        // 解析Shadowsocks配置
        // 实现配置解析逻辑
        fatalError("Not implemented")
    }
}

// 协议策略管理器
class ProtocolStrategyManager {
    private var strategies: [ProxyProtocol: ProxyProtocolStrategy] = [:]
    
    init() {
        registerStrategy(VMessProtocolStrategy())
        registerStrategy(ShadowsocksProtocolStrategy())
        // 注册其他协议策略...
    }
    
    func registerStrategy(_ strategy: ProxyProtocolStrategy) {
        strategies[strategy.protocolType] = strategy
    }
    
    func getStrategy(for protocol: ProxyProtocol) -> ProxyProtocolStrategy? {
        return strategies[protocol]
    }
    
    func createConfiguration(_ config: ProxyConfig) throws -> [String: Any] {
        guard let strategy = getStrategy(for: config.protocol) else {
            throw ProtocolError.unsupportedProtocol
        }
        
        try strategy.validateConfiguration(config)
        return try strategy.createConfiguration(config)
    }
}

enum ProtocolError: Error {
    case invalidConfiguration
    case unsupportedProtocol
    case invalidUserId
    case invalidSecurity
    case unsupportedMethod
    case emptyPassword
}
```

---

## 🔧 技术选型深度分析

### 1. SwiftUI vs UIKit

#### 选择SwiftUI的原因

**优势**：
1. **声明式UI**：代码更简洁，易于理解和维护
2. **数据绑定**：自动UI更新，减少手动同步代码
3. **跨平台**：可以在macOS、iOS等平台复用代码
4. **现代化**：Apple推荐的UI框架，未来发展方向
5. **性能优化**：编译时优化，运行时性能更好

**挑战和解决方案**：
```swift
// 挑战1：复杂动画实现
// 解决方案：使用自定义动画和Transition
struct AnimatedProxyRow: View {
    let proxy: ProxyConfig
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            HStack {
                Text(proxy.name)
                Spacer()
                Button(action: { 
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            
            if isExpanded {
                ProxyDetailView(proxy: proxy)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
            }
        }
        .animation(.spring(), value: isExpanded)
    }
}

// 挑战2：与AppKit集成
// 解决方案：使用NSViewRepresentable
struct StatusBarView: NSViewRepresentable {
    let statusItem: NSStatusItem
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.addSubview(statusItem.button!)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // 更新视图
    }
}

// 挑战3：性能优化
// 解决方案：使用LazyVStack和onAppear优化
struct OptimizedProxyList: View {
    let proxies: [ProxyConfig]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(proxies) { proxy in
                    ProxyRowView(proxy: proxy)
                        .onAppear {
                            // 延迟加载逻辑
                        }
                }
            }
        }
    }
}
```

### 2. GRDB vs Core Data

#### 选择GRDB的原因

**优势**：
1. **SQL直接访问**：可以使用原生SQL查询
2. **性能优异**：针对SQLite优化，性能更好
3. **类型安全**：编译时类型检查
4. **迁移简单**：数据库迁移更加灵活
5. **并发安全**：内置并发控制机制

**实现示例**：
```swift
// 数据库模型定义
struct ProxyConfig: Codable, FetchableRecord, MutablePersistableRecord {
    var id: UUID
    var name: String
    var serverAddress: String
    var serverPort: Int
    var protocol: String
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // 数据库表定义
    static let databaseTableName = "proxy_configs"
    
    // 列定义
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let serverAddress = Column(CodingKeys.serverAddress)
        static let serverPort = Column(CodingKeys.serverPort)
        static let protocol = Column(CodingKeys.protocol)
        static let isEnabled = Column(CodingKeys.isEnabled)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
    
    // 数据库操作
    mutating func didInsert(with rowID: Int64, for column: String?) {
        // 插入后回调
    }
    
    mutating func willUpdate(with rowID: Int64, for column: String?) {
        updatedAt = Date()
    }
}

// 数据库迁移
var migrator = DatabaseMigrator()

migrator.registerMigration("v1.0") { db in
    try db.create(table: "proxy_configs") { t in
        t.column("id", .text).primaryKey()
        t.column("name", .text).notNull()
        t.column("serverAddress", .text).notNull()
        t.column("serverPort", .integer).notNull()
        t.column("protocol", .text).notNull()
        t.column("isEnabled", .boolean).notNull().defaults(to: false)
        t.column("createdAt", .datetime).notNull()
        t.column("updatedAt", .datetime).notNull()
    }
}

migrator.registerMigration("v1.1") { db in
    try db.alter(table: "proxy_configs") { t in
        t.add(column: "tags", .text)
    }
}

// 复杂查询示例
class ProxyConfigRepository {
    private let dbQueue: DatabaseQueue
    
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }
    
    func fetchActiveProxies() async throws -> [ProxyConfig] {
        return try await dbQueue.read { db in
            try ProxyConfig
                .filter(ProxyConfig.Columns.isEnabled == true)
                .order(ProxyConfig.Columns.name)
                .fetchAll(db)
        }
    }
    
    func fetchProxiesByProtocol(_ protocol: String) async throws -> [ProxyConfig] {
        return try await dbQueue.read { db in
            try ProxyConfig
                .filter(ProxyConfig.Columns.protocol == protocol)
                .fetchAll(db)
        }
    }
    
    func searchProxies(_ keyword: String) async throws -> [ProxyConfig] {
        return try await dbQueue.read { db in
            try ProxyConfig
                .filter(ProxyConfig.Columns.name.like("%\(keyword)%") ||
                        ProxyConfig.Columns.serverAddress.like("%\(keyword)%"))
                .fetchAll(db)
        }
    }
}
```

### 3. Combine vs async/await

#### 混合使用策略

**Combine适用场景**：
- 响应式数据流
- UI状态绑定
- 事件处理链

**async/await适用场景**：
- 异步API调用
- 顺序异步操作
- 错误处理

**实现示例**：
```swift
// Combine用于响应式数据流
class NetworkMonitor: ObservableObject {
    @Published var isConnected = false
    @Published var connectionType: NWInterface.InterfaceType?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }
}

// async/await用于异步操作
class ProxyTester {
    func testProxyLatency(_ proxy: ProxyConfig) async throws -> TimeInterval {
        let startTime = Date()
        
        // 配置代理
        try await configureProxy(proxy)
        
        // 测试连接
        let url = URL(string: "https://www.google.com")!
        let (_, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProxyTestError.connectionFailed
        }
        
        return Date().timeIntervalSince(startTime)
    }
    
    func batchTestProxies(_ proxies: [ProxyConfig]) async -> [ProxyTestResult] {
        return await withTaskGroup(of: ProxyTestResult.self) { group in
            for proxy in proxies {
                group.addTask {
                    do {
                        let latency = try await self.testProxyLatency(proxy)
                        return ProxyTestResult(proxy: proxy, latency: latency, error: nil)
                    } catch {
                        return ProxyTestResult(proxy: proxy, latency: nil, error: error)
                    }
                }
            }
            
            var results: [ProxyTestResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    private func configureProxy(_ proxy: ProxyConfig) async throws {
        // 配置代理逻辑
    }
}

// 结合使用：Combine + async/await
class ProxyManager: ObservableObject {
    @Published var activeProxy: ProxyConfig?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    private let proxyTester = ProxyTester()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 使用Combine监听网络状态
        NetworkMonitor().isConnectedPublisher
            .sink { [weak self] isConnected in
                if isConnected {
                    Task {
                        await self?.reconnectIfNeeded()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func activateProxy(_ proxy: ProxyConfig) async throws {
        connectionStatus = .connecting
        
        do {
            // 使用async/await进行异步操作
            let latency = try await proxyTester.testProxyLatency(proxy)
            
            // 更新UI状态（在主线程）
            await MainActor.run {
                self.activeProxy = proxy
                self.connectionStatus = .connected(latency: latency)
            }
        } catch {
            await MainActor.run {
                self.connectionStatus = .failed(error: error)
            }
            throw error
        }
    }
    
    private func reconnectIfNeeded() async {
        guard let activeProxy = activeProxy,
              connectionStatus.isDisconnected else {
            return
        }
        
        do {
            try await activateProxy(activeProxy)
        } catch {
            LogManager.shared.error("重连失败: \(error)")
        }
    }
}

enum ConnectionStatus {
    case disconnected
    case connecting
    case connected(latency: TimeInterval)
    case failed(error: Error)
    
    var isDisconnected: Bool {
        if case .disconnected = self {
            return true
        }
        return false
    }
}
```

---

## ⚡ 性能优化策略

### 1. 内存管理优化

#### 弱引用和内存泄漏防护
```swift
// 避免循环引用的最佳实践
class ProxyConnectionManager {
    private weak var delegate: ProxyConnectionDelegate?
    private var connectionTimer: Timer?
    
    init(delegate: ProxyConnectionDelegate) {
        self.delegate = delegate
    }
    
    func startConnection() {
        // 使用弱引用避免循环引用
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkConnectionStatus()
        }
    }
    
    func stopConnection() {
        connectionTimer?.invalidate()
        connectionTimer = nil
    }
    
    private func checkConnectionStatus() {
        // 检查delegate是否还存在
        guard let delegate = delegate else {
            stopConnection()
            return
        }
        
        // 执行连接检查
        delegate.connectionStatusDidUpdate(isConnected: true)
    }
    
    deinit {
        stopConnection()
    }
}

// 使用@MainActor确保UI更新在主线程
@MainActor
class ProxyListViewModel: ObservableObject {
    @Published var proxies: [ProxyConfig] = []
    
    private let repository: ProxyRepository
    
    init(repository: ProxyRepository) {
        self.repository = repository
    }
    
    func loadProxies() async {
        do {
            let loadedProxies = try await repository.fetchAll()
            // 确保UI更新在主线程
            self.proxies = loadedProxies
        } catch {
            // 错误处理
        }
    }
}
```

### 2. 数据库性能优化

#### 查询优化和索引策略
```swift
// 数据库索引优化
var migrator = DatabaseMigrator()

migrator.registerMigration("indexes") { db in
    // 为常用查询字段创建索引
    try db.create(index: "idx_proxy_configs_enabled", on: "proxy_configs", columns: ["isEnabled"])
    try db.create(index: "idx_proxy_configs_protocol", on: "proxy_configs", columns: ["protocol"])
    try db.create(index: "idx_proxy_configs_name", on: "proxy_configs", columns: ["name"])
    
    // 复合索引用于复杂查询
    try db.create(index: "idx_proxy_configs_enabled_protocol", 
                  on: "proxy_configs", 
                  columns: ["isEnabled", "protocol"])
}

// 查询优化
class OptimizedProxyRepository {
    private let dbQueue: DatabaseQueue
    
    // 使用预编译语句提高性能
    private lazy var fetchActiveProxiesStatement: Statement = {
        try! dbQueue.read { db in
            try db.makeStatement(sql: """
                SELECT * FROM proxy_configs 
                WHERE isEnabled = 1 
                ORDER BY name
            """)
        }
    }()
    
    func fetchActiveProxies() async throws -> [ProxyConfig] {
        return try await dbQueue.read { db in
            try ProxyConfig.fetchAll(fetchActiveProxiesStatement)
        }
    }
    
    // 批量操作优化
    func batchUpdateProxies(_ proxies: [ProxyConfig]) async throws {
        try await dbQueue.write { db in
            try db.inTransaction {
                for proxy in proxies {
                    try proxy.update(db)
                }
                return .commit
            }
        }
    }
    
    // 分页查询
    func fetchProxies(offset: Int, limit: Int) async throws -> [ProxyConfig] {
        return try await dbQueue.read { db in
            try ProxyConfig
                .order(ProxyConfig.Columns.name)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }
}
```

### 3. 网络性能优化

#### 连接池和缓存策略
```swift
// HTTP连接池管理
class HTTPConnectionPool {
    private let maxConnections: Int
    private var availableConnections: [URLSessionDataTask] = []
    private var activeConnections: Set<URLSessionDataTask> = []
    private let queue = DispatchQueue(label: "connection.pool", attributes: .concurrent)
    
    init(maxConnections: Int = 10) {
        self.maxConnections = maxConnections
    }
    
    func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let session = getOptimizedURLSession()
        return try await session.data(for: request)
    }
    
    private func getOptimizedURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        
        // 连接池配置
        config.httpMaximumConnectionsPerHost = maxConnections
        config.httpShouldUsePipelining = true
        
        // 缓存配置
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024, // 50MB
            diskCapacity: 200 * 1024 * 1024,  // 200MB
            diskPath: "proxy_cache"
        )
        
        // 超时配置
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        return URLSession(configuration: config)
    }
}

// 智能缓存管理
class SmartCacheManager {
    private let cache = NSCache<NSString, CacheItem>()
    private let diskCache: DiskCache
    private let cacheQueue = DispatchQueue(label: "cache.queue", attributes: .concurrent)
    
    init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        diskCache = DiskCache()
        
        setupMemoryWarningObserver()
    }
    
    func get<T: Codable>(_ key: String, type: T.Type) async -> T? {
        // 先检查内存缓存
        if let item = cache.object(forKey: NSString(string: key)),
           !item.isExpired {
            return item.value as? T
        }
        
        // 再检查磁盘缓存
        return await withCheckedContinuation { continuation in
            cacheQueue.async {
                let diskItem = self.diskCache.get(key, type: type)
                
                if let diskItem = diskItem, !diskItem.isExpired {
                    // 将磁盘缓存项提升到内存缓存
                    let cacheItem = CacheItem(value: diskItem, expirationDate: diskItem.expirationDate)
                    self.cache.setObject(cacheItem, forKey: NSString(string: key))
                    continuation.resume(returning: diskItem)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func set<T: Codable>(_ key: String, value: T, ttl: TimeInterval = 3600) async {
        let expirationDate = Date().addingTimeInterval(ttl)
        let cacheItem = CacheItem(value: value, expirationDate: expirationDate)
        
        // 设置内存缓存
        cache.setObject(cacheItem, forKey: NSString(string: key))
        
        // 异步设置磁盘缓存
        await withCheckedContinuation { continuation in
            cacheQueue.async {
                self.diskCache.set(key, value: value, expirationDate: expirationDate)
                continuation.resume()
            }
        }
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cache.removeAllObjects()
        }
    }
}

private class CacheItem {
    let value: Any
    let expirationDate: Date
    
    init(value: Any, expirationDate: Date) {
        self.value = value
        self.expirationDate = expirationDate
    }
    
    var isExpired: Bool {
        return Date() > expirationDate
    }
}
```

---

## 🔒 安全架构设计

### 1. 数据加密策略

#### 多层加密保护
```swift
// 加密服务接口
protocol EncryptionService {
    func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data
    func decrypt(_ encryptedData: Data, using key: SymmetricKey) throws -> Data
    func generateKey() -> SymmetricKey
    func deriveKey(from password: String, salt: Data) throws -> SymmetricKey
}

// AES-GCM加密实现
class AESGCMEncryptionService: EncryptionService {
    func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined ?? Data()
    }
    
    func decrypt(_ encryptedData: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    func generateKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        let passwordData = password.data(using: .utf8)!
        return SymmetricKey(data: try HKDF<SHA256>.deriveKey(
            inputKeyMaterial: passwordData,
            salt: salt,
            info: Data("V2rayU-Key-Derivation".utf8),
            outputByteCount: 32
        ))
    }
}

// 安全存储管理器
class SecureStorageManager {
    private let encryptionService: EncryptionService
    private let keychain: KeychainManager
    
    init(encryptionService: EncryptionService, keychain: KeychainManager) {
        self.encryptionService = encryptionService
        self.keychain = keychain
    }
    
    func storeSecureData<T: Codable>(_ data: T, forKey key: String) async throws {
        // 1. 序列化数据
        let jsonData = try JSONEncoder().encode(data)
        
        // 2. 生成或获取加密密钥
        let encryptionKey = try await getOrCreateEncryptionKey(for: key)
        
        // 3. 加密数据
        let encryptedData = try encryptionService.encrypt(jsonData, using: encryptionKey)
        
        // 4. 存储到Keychain
        try await keychain.store(encryptedData, forKey: key)
    }
    
    func retrieveSecureData<T: Codable>(_ type: T.Type, forKey key: String) async throws -> T? {
        // 1. 从Keychain获取加密数据
        guard let encryptedData = try await keychain.retrieve(forKey: key) else {
            return nil
        }
        
        // 2. 获取解密密钥
        let encryptionKey = try await getOrCreateEncryptionKey(for: key)
        
        // 3. 解密数据
        let decryptedData = try encryptionService.decrypt(encryptedData, using: encryptionKey)
        
        // 4. 反序列化
        return try JSONDecoder().decode(type, from: decryptedData)
    }
    
    private func getOrCreateEncryptionKey(for identifier: String) async throws -> SymmetricKey {
        let keyIdentifier = "encryption_key_\(identifier)"
        
        // 尝试从Keychain获取现有密钥
        if let existingKeyData = try await keychain.retrieve(forKey: keyIdentifier) {
            return SymmetricKey(data: existingKeyData)
        }
        
        // 生成新密钥
        let newKey = encryptionService.generateKey()
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        // 存储密钥到Keychain
        try await keychain.store(keyData, forKey: keyIdentifier)
        
        return newKey
    }
}
```

### 2. 访问控制和权限管理

#### 基于角色的访问控制
```swift
// 权限定义
enum Permission: String, CaseIterable {
    case readProxyConfigs = "proxy.read"
    case writeProxyConfigs = "proxy.write"
    case deleteProxyConfigs = "proxy.delete"
    case manageSubscriptions = "subscription.manage"
    case viewTrafficStats = "traffic.view"
    case modifySystemProxy = "system.proxy.modify"
    case accessLogs = "logs.access"
    case modifySettings = "settings.modify"
}

// 角色定义
enum Role: String, CaseIterable {
    case viewer = "viewer"
    case user = "user"
    case admin = "admin"
    
    var permissions: Set<Permission> {
        switch self {
        case .viewer:
            return [.readProxyConfigs, .viewTrafficStats]
        case .user:
            return [
                .readProxyConfigs, .writeProxyConfigs,
                .manageSubscriptions, .viewTrafficStats
            ]
        case .admin:
            return Set(Permission.allCases)
        }
    }
}

// 用户身份
struct UserIdentity {
    let id: UUID
    let username: String
    let role: Role
    let isActive: Bool
    let lastLoginAt: Date?
    
    var permissions: Set<Permission> {
        return isActive ? role.permissions : []
    }
}

// 访问控制管理器
class AccessControlManager {
    private var currentUser: UserIdentity?
    private let auditLogger: AuditLogger
    
    init(auditLogger: AuditLogger) {
        self.auditLogger = auditLogger
    }
    
    func authenticate(username: String, password: String) async throws -> UserIdentity {
        // 实现身份验证逻辑
        // 这里简化为示例
        let user = UserIdentity(
            id: UUID(),
            username: username,
            role: .user,
            isActive: true,
            lastLoginAt: Date()
        )
        
        currentUser = user
        
        await auditLogger.logEvent(
            AuditEvent(
                type: .authentication,
                user: user,
                action: "login",
                result: .success,
                timestamp: Date()
            )
        )
        
        return user
    }
    
    func checkPermission(_ permission: Permission) throws {
        guard let user = currentUser else {
            throw AccessControlError.notAuthenticated
        }
        
        guard user.permissions.contains(permission) else {
            await auditLogger.logEvent(
                AuditEvent(
                    type: .authorization,
                    user: user,
                    action: "access_denied",
                    result: .failure,
                    timestamp: Date(),
                    details: ["permission": permission.rawValue]
                )
            )
            throw AccessControlError.insufficientPermissions
        }
        
        await auditLogger.logEvent(
            AuditEvent(
                type: .authorization,
                user: user,
                action: "access_granted",
                result: .success,
                timestamp: Date(),
                details: ["permission": permission.rawValue]
            )
        )
    }
    
    func requirePermission(_ permission: Permission) -> Bool {
        do {
            try checkPermission(permission)
            return true
        } catch {
            return false
        }
    }
}

// 权限装饰器
@propertyWrapper
struct RequiresPermission<T> {
    private let permission: Permission
    private let accessControl: AccessControlManager
    private let wrappedValue: T
    
    init(wrappedValue: T, _ permission: Permission, accessControl: AccessControlManager) {
        self.wrappedValue = wrappedValue
        self.permission = permission
        self.accessControl = accessControl
    }
    
    var projectedValue: T {
        get throws {
            try accessControl.checkPermission(permission)
            return wrappedValue
        }
    }
}

// 使用示例
class ProxyService {
    private let accessControl: AccessControlManager
    
    @RequiresPermission(.writeProxyConfigs, accessControl: accessControl)
    private let proxyRepository: ProxyRepository
    
    init(accessControl: AccessControlManager, proxyRepository: ProxyRepository) {
        self.accessControl = accessControl
        self._proxyRepository = RequiresPermission(
            wrappedValue: proxyRepository,
            .writeProxyConfigs,
            accessControl: accessControl
        )
    }
    
    func createProxy(_ config: ProxyConfig) async throws {
        let repository = try $proxyRepository
        try await repository.save(config)
    }
}

enum AccessControlError: Error {
    case notAuthenticated
    case insufficientPermissions
    case accountDisabled
}
```

---

## 📊 监控和可观测性

### 1. 应用性能监控

#### 性能指标收集
```swift
// 性能指标定义
struct PerformanceMetrics {
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: UInt64
    let networkLatency: TimeInterval
    let activeConnections: Int
    let requestsPerSecond: Double
    let errorRate: Double
}

// 性能监控器
class PerformanceMonitor: ObservableObject {
    @Published var currentMetrics: PerformanceMetrics?
    @Published var historicalMetrics: [PerformanceMetrics] = []
    
    private let metricsCollector: MetricsCollector
    private let alertManager: AlertManager
    private var monitoringTimer: Timer?
    
    init(metricsCollector: MetricsCollector, alertManager: AlertManager) {
        self.metricsCollector = metricsCollector
        self.alertManager = alertManager
    }
    
    func startMonitoring(interval: TimeInterval = 5.0) {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                await self.collectAndAnalyzeMetrics()
            }
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func collectAndAnalyzeMetrics() async {
        let metrics = await metricsCollector.collectCurrentMetrics()
        
        await MainActor.run {
            self.currentMetrics = metrics
            self.historicalMetrics.append(metrics)
            
            // 保持历史数据在合理范围内
            if self.historicalMetrics.count > 1000 {
                self.historicalMetrics.removeFirst(100)
            }
        }
        
     // 分析指标并触发告警
        await analyzeMetricsAndAlert(metrics)
    }
    
    private func analyzeMetricsAndAlert(_ metrics: PerformanceMetrics) async {
        // CPU使用率告警
        if metrics.cpuUsage > 0.8 {
            await alertManager.triggerAlert(
                Alert(
                    type: .performance,
                    severity: .warning,
                    message: "CPU使用率过高: \(Int(metrics.cpuUsage * 100))%",
                    timestamp: Date()
                )
            )
        }
        
        // 内存使用告警
        let memoryUsageGB = Double(metrics.memoryUsage) / (1024 * 1024 * 1024)
        if memoryUsageGB > 2.0 {
            await alertManager.triggerAlert(
                Alert(
                    type: .performance,
                    severity: .warning,
                    message: "内存使用过高: \(String(format: "%.2f", memoryUsageGB))GB",
                    timestamp: Date()
                )
            )
        }
        
        // 网络延迟告警
        if metrics.networkLatency > 5.0 {
            await alertManager.triggerAlert(
                Alert(
                    type: .network,
                    severity: .error,
                    message: "网络延迟过高: \(Int(metrics.networkLatency * 1000))ms",
                    timestamp: Date()
                )
            )
        }
    }
}

// 指标收集器
class MetricsCollector {
    private let processInfo = ProcessInfo.processInfo
    private let networkMonitor = NetworkLatencyMonitor()
    
    func collectCurrentMetrics() async -> PerformanceMetrics {
        let cpuUsage = await getCPUUsage()
        let memoryUsage = getMemoryUsage()
        let networkLatency = await networkMonitor.getCurrentLatency()
        let activeConnections = getActiveConnectionCount()
        let requestsPerSecond = await getRequestsPerSecond()
        let errorRate = await getErrorRate()
        
        return PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            networkLatency: networkLatency,
            activeConnections: activeConnections,
            requestsPerSecond: requestsPerSecond,
            errorRate: errorRate
        )
    }
    
    private func getCPUUsage() async -> Double {
        // 实现CPU使用率获取
        return processInfo.systemUptime // 简化示例
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    private func getActiveConnectionCount() -> Int {
        // 实现活跃连接数获取
        return 0 // 简化示例
    }
    
    private func getRequestsPerSecond() async -> Double {
        // 实现RPS计算
        return 0.0 // 简化示例
    }
    
    private func getErrorRate() async -> Double {
        // 实现错误率计算
        return 0.0 // 简化示例
    }
}
```

### 2. 日志管理系统

#### 结构化日志记录
```swift
// 日志级别定义
enum LogLevel: String, CaseIterable {
    case trace = "TRACE"
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var priority: Int {
        switch self {
        case .trace: return 0
        case .debug: return 1
        case .info: return 2
        case .warning: return 3
        case .error: return 4
        case .critical: return 5
        }
    }
}

// 日志条目
struct LogEntry {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let metadata: [String: Any]
    let file: String
    let function: String
    let line: Int
    
    init(
        level: LogLevel,
        category: String,
        message: String,
        metadata: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.file = URL(fileURLWithPath: file).lastPathComponent
        self.function = function
        self.line = line
    }
}

// 日志输出器协议
protocol LogOutput {
    func write(_ entry: LogEntry) async
    func flush() async
}

// 控制台日志输出器
class ConsoleLogOutput: LogOutput {
    private let formatter: LogFormatter
    
    init(formatter: LogFormatter = DefaultLogFormatter()) {
        self.formatter = formatter
    }
    
    func write(_ entry: LogEntry) async {
        let formattedMessage = formatter.format(entry)
        print(formattedMessage)
    }
    
    func flush() async {
        // 控制台输出无需刷新
    }
}

// 文件日志输出器
class FileLogOutput: LogOutput {
    private let fileURL: URL
    private let formatter: LogFormatter
    private let fileHandle: FileHandle
    private let queue = DispatchQueue(label: "file.log.output", qos: .utility)
    
    init(fileURL: URL, formatter: LogFormatter = DefaultLogFormatter()) throws {
        self.fileURL = fileURL
        self.formatter = formatter
        
        // 确保目录存在
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        // 创建或打开文件
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        
        self.fileHandle = try FileHandle(forWritingTo: fileURL)
        fileHandle.seekToEndOfFile()
    }
    
    func write(_ entry: LogEntry) async {
        let formattedMessage = formatter.format(entry)
        let data = (formattedMessage + "\n").data(using: .utf8) ?? Data()
        
        await withCheckedContinuation { continuation in
            queue.async {
                self.fileHandle.write(data)
                continuation.resume()
            }
        }
    }
    
    func flush() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.fileHandle.synchronizeFile()
                continuation.resume()
            }
        }
    }
    
    deinit {
        fileHandle.closeFile()
    }
}

// 日志格式化器
protocol LogFormatter {
    func format(_ entry: LogEntry) -> String
}

class DefaultLogFormatter: LogFormatter {
    private let dateFormatter: DateFormatter
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    func format(_ entry: LogEntry) -> String {
        let timestamp = dateFormatter.string(from: entry.timestamp)
        let location = "\(entry.file):\(entry.line)"
        
        var components = [
            timestamp,
            "[\(entry.level.rawValue)]",
            "[\(entry.category)]",
            entry.message,
            "(\(location))"
        ]
        
        if !entry.metadata.isEmpty {
            let metadataString = entry.metadata
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            components.append("[\(metadataString)]")
        }
        
        return components.joined(separator: " ")
    }
}

class JSONLogFormatter: LogFormatter {
    private let encoder = JSONEncoder()
    
    init() {
        encoder.dateEncodingStrategy = .iso8601
    }
    
    func format(_ entry: LogEntry) -> String {
        let logData: [String: Any] = [
            "id": entry.id.uuidString,
            "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
            "level": entry.level.rawValue,
            "category": entry.category,
            "message": entry.message,
            "metadata": entry.metadata,
            "source": [
                "file": entry.file,
                "function": entry.function,
                "line": entry.line
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: logData)
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            return "Failed to encode log entry: \(error)"
        }
    }
}

// 主日志管理器
class LogManager {
    static let shared = LogManager()
    
    private var outputs: [LogOutput] = []
    private var minimumLevel: LogLevel = .info
    private let queue = DispatchQueue(label: "log.manager", qos: .utility)
    
    private init() {
        setupDefaultOutputs()
    }
    
    func addOutput(_ output: LogOutput) {
        queue.async {
            self.outputs.append(output)
        }
    }
    
    func setMinimumLevel(_ level: LogLevel) {
        queue.async {
            self.minimumLevel = level
        }
    }
    
    func log(
        level: LogLevel,
        category: String,
        message: String,
        metadata: [String: Any] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level.priority >= minimumLevel.priority else { return }
        
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
        
        queue.async {
            Task {
                for output in self.outputs {
                    await output.write(entry)
                }
            }
        }
    }
    
    // 便捷方法
    func trace(_ message: String, category: String = "App", metadata: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .trace, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    func debug(_ message: String, category: String = "App", metadata: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: String = "App", metadata: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: String = "App", metadata: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: String = "App", metadata: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, category: String = "App", metadata: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .critical, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    func flush() async {
        await withTaskGroup(of: Void.self) { group in
            for output in outputs {
                group.addTask {
                    await output.flush()
                }
            }
        }
    }
    
    private func setupDefaultOutputs() {
        // 添加控制台输出
        outputs.append(ConsoleLogOutput())
        
        // 添加文件输出
        do {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let logFileURL = documentsURL.appendingPathComponent("V2rayU/logs/app.log")
            let fileOutput = try FileLogOutput(fileURL: logFileURL, formatter: JSONLogFormatter())
            outputs.append(fileOutput)
        } catch {
            print("Failed to setup file logging: \(error)")
        }
    }
}
```

---

## 🧪 测试架构设计

### 1. 单元测试策略

#### 测试金字塔实现
```swift
// 测试基类
class BaseTestCase: XCTestCase {
    var mockContainer: MockContainer!
    
    override func setUp() {
        super.setUp()
        mockContainer = MockContainer()
    }
    
    override func tearDown() {
        mockContainer = nil
        super.tearDown()
    }
}

// Mock容器
class MockContainer {
    private var mocks: [String: Any] = [:]
    
    func register<T>(_ mock: T, for type: T.Type) {
        let key = String(describing: type)
        mocks[key] = mock
    }
    
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return mocks[key] as? T
    }
}

// 代理管理器测试
class ProxyManagerTests: BaseTestCase {
    var proxyManager: ProxyManager!
    var mockRepository: MockProxyRepository!
    var mockNetworkService: MockNetworkService!
    
    override func setUp() {
        super.setUp()
        
        mockRepository = MockProxyRepository()
        mockNetworkService = MockNetworkService()
        
        mockContainer.register(mockRepository, for: ProxyRepository.self)
        mockContainer.register(mockNetworkService, for: NetworkService.self)
        
        proxyManager = ProxyManager(
            repository: mockRepository,
            networkService: mockNetworkService
        )
    }
    
    func testActivateProxy_Success() async throws {
        // Given
        let proxy = ProxyConfig.mock()
        mockRepository.saveResult = .success(())
        mockNetworkService.testConnectionResult = .success(true)
        
        // When
        try await proxyManager.activateProxy(proxy)
        
        // Then
        XCTAssertEqual(proxyManager.activeProxy?.id, proxy.id)
        XCTAssertTrue(mockRepository.saveCalled)
        XCTAssertTrue(mockNetworkService.testConnectionCalled)
    }
    
    func testActivateProxy_NetworkFailure() async {
        // Given
        let proxy = ProxyConfig.mock()
        mockNetworkService.testConnectionResult = .failure(NetworkError.connectionTimeout)
        
        // When & Then
        do {
            try await proxyManager.activateProxy(proxy)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is NetworkError)
            XCTAssertNil(proxyManager.activeProxy)
        }
    }
    
    func testBatchTestProxies_Performance() async {
        // Given
        let proxies = (1...100).map { _ in ProxyConfig.mock() }
        mockNetworkService.testConnectionResult = .success(true)
        
        // When
        let startTime = Date()
        let results = await proxyManager.batchTestProxies(proxies)
        let duration = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(results.count, 100)
        XCTAssertLessThan(duration, 10.0) // 应该在10秒内完成
    }
}

// Mock实现
class MockProxyRepository: ProxyRepository {
    var saveResult: Result<Void, Error> = .success(())
    var fetchAllResult: Result<[ProxyConfig], Error> = .success([])
    var saveCalled = false
    var fetchAllCalled = false
    
    func save(_ proxy: ProxyConfig) async throws {
        saveCalled = true
        switch saveResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    func fetchAll() async throws -> [ProxyConfig] {
        fetchAllCalled = true
        switch fetchAllResult {
        case .success(let proxies):
            return proxies
        case .failure(let error):
            throw error
        }
    }
    
    func fetch(by id: UUID) async throws -> ProxyConfig? {
        return nil
    }
    
    func delete(_ proxy: ProxyConfig) async throws {
        // Mock implementation
    }
    
    func update(_ proxy: ProxyConfig) async throws {
        // Mock implementation
    }
}

class MockNetworkService: NetworkService {
    var testConnectionResult: Result<Bool, Error> = .success(true)
    var testConnectionCalled = false
    
    func testConnection(to proxy: ProxyConfig) async throws -> Bool {
        testConnectionCalled = true
        switch testConnectionResult {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }
}

// 测试数据工厂
extension ProxyConfig {
    static func mock(
        id: UUID = UUID(),
        name: String = "Test Proxy",
        serverAddress: String = "127.0.0.1",
        serverPort: Int = 1080,
        protocol: ProxyProtocol = .vmess
    ) -> ProxyConfig {
        return ProxyConfig(
            id: id,
            name: name,
            serverAddress: serverAddress,
            serverPort: serverPort,
            protocol: protocol,
            isEnabled: true
        )
    }
}
```

### 2. 集成测试

#### 端到端测试实现
```swift
// 集成测试基类
class IntegrationTestCase: XCTestCase {
    var testContainer: TestContainer!
    var testDatabase: DatabaseManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 创建测试数据库
        testDatabase = try await createTestDatabase()
        
        // 设置测试容器
        testContainer = TestContainer(database: testDatabase)
    }
    
    override func tearDown() async throws {
        // 清理测试数据
        try await cleanupTestDatabase()
        testContainer = nil
        testDatabase = nil
        
        try await super.tearDown()
    }
    
    private func createTestDatabase() async throws -> DatabaseManager {
        let testDBURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).db")
        
        let database = try DatabaseManager(url: testDBURL)
        try await database.migrate()
        
        return database
    }
    
    private func cleanupTestDatabase() async throws {
        try await testDatabase.close()
        
        let dbURL = testDatabase.databaseURL
        if FileManager.default.fileExists(atPath: dbURL.path) {
            try FileManager.default.removeItem(at: dbURL)
        }
    }
}

// 代理管理集成测试
class ProxyManagementIntegrationTests: IntegrationTestCase {
    var proxyManager: ProxyManager!
    var subscriptionManager: SubscriptionManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        proxyManager = testContainer.resolve(ProxyManager.self)
        subscriptionManager = testContainer.resolve(SubscriptionManager.self)
    }
    
    func testCompleteProxyWorkflow() async throws {
        // 1. 添加订阅
        let subscription = Subscription(
            id: UUID(),
            name: "Test Subscription",
            url: "https://example.com/subscription",
            isEnabled: true
        )
        
        try await subscriptionManager.addSubscription(subscription)
        
        // 2. 同步订阅获取代理
        try await subscriptionManager.syncSubscription(subscription)
        
        // 3. 验证代理已添加
        let proxies = try await proxyManager.getAllProxies()
        XCTAssertFalse(proxies.isEmpty)
        
        // 4. 激活代理
        let firstProxy = proxies.first!
        try await proxyManager.activateProxy(firstProxy)
        
        // 5. 验证代理状态
        XCTAssertEqual(proxyManager.activeProxy?.id, firstProxy.id)
        
        // 6. 测试代理连接
        let isConnected = try await proxyManager.testActiveProxyConnection()
        XCTAssertTrue(isConnected)
        
        // 7. 停用代理
        try await proxyManager.deactivateProxy()
        XCTAssertNil(proxyManager.activeProxy)
    }
    
    func testProxyFailover() async throws {
        // 准备多个代理
        let proxies = [
            ProxyConfig.mock(name: "Proxy 1", serverAddress: "1.1.1.1"),
            ProxyConfig.mock(name: "Proxy 2", serverAddress: "2.2.2.2"),
            ProxyConfig.mock(name: "Proxy 3", serverAddress: "3.3.3.3")
        ]
        
        for proxy in proxies {
            try await proxyManager.addProxy(proxy)
        }
        
        // 模拟第一个代理失败
        try await proxyManager.activateProxy(proxies[0])
        
        // 触发故障转移
        try await proxyManager.handleConnectionFailure()
        
        // 验证已切换到下一个可用代理
        XCTAssertNotEqual(proxyManager.activeProxy?.id, proxies[0].id)
        XCTAssertNotNil(proxyManager.activeProxy)
    }
}

// UI测试
class V2rayUUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    func testProxyListNavigation() {
        // 验证主界面加载
        XCTAssertTrue(app.windows["V2rayU"].exists)
        
        // 点击代理列表
        app.buttons["代理列表"].tap()
        
        // 验证代理列表界面
        XCTAssertTrue(app.tables["ProxyList"].exists)
        
        // 添加新代理
        app.buttons["添加代理"].tap()
        
        // 填写代理信息
        let nameField = app.textFields["代理名称"]
        nameField.tap()
        nameField.typeText("Test Proxy")
        
        let addressField = app.textFields["服务器地址"]
        addressField.tap()
        addressField.typeText("127.0.0.1")
        
        let portField = app.textFields["端口"]
        portField.tap()
        portField.typeText("1080")
        
        // 保存代理
        app.buttons["保存"].tap()
        
        // 验证代理已添加到列表
        XCTAssertTrue(app.tables["ProxyList"].cells.containing(.staticText, identifier: "Test Proxy").element.exists)
    }
    
    func testProxyActivation() {
        // 选择代理
        let proxyCell = app.tables["ProxyList"].cells.firstMatch
        proxyCell.tap()
        
        // 激活代理
        app.buttons["激活"].tap()
        
        // 验证状态指示器
        let statusIndicator = app.images["StatusIndicator"]
        XCTAssertTrue(statusIndicator.exists)
        
        // 等待连接建立
        let connectedExpectation = expectation(for: NSPredicate(format: "label == 'Connected'"), 
                                             evaluatedWith: statusIndicator, 
                                             handler: nil)
        wait(for: [connectedExpectation], timeout: 10.0)
    }
}
```

---

## 📈 总结与最佳实践

### 架构演进路径

1. **起始阶段**：简单的MVC架构
2. **成长阶段**：引入MVVM和Repository模式
3. **成熟阶段**：完整的分层架构和设计模式
4. **优化阶段**：性能优化和监控完善

### 关键成功因素

1. **清晰的架构边界**：每层职责明确，依赖关系清晰
2. **一致的设计模式**：在整个应用中保持设计模式的一致性
3. **完善的测试覆盖**：单元测试、集成测试、UI测试全覆盖
4. **持续的性能监控**：实时监控应用性能和用户体验
5. **安全优先设计**：从架构层面考虑安全性

### 未来发展方向

1. **微服务架构**：考虑将功能模块拆分为独立服务
2. **云原生支持**：支持容器化部署和云服务集成
3. **AI/ML集成**：智能代理选择和网络优化
4. **跨平台扩展**：支持iOS、Windows等更多平台

---

## 📚 参考资源

### 官方文档
- [Swift官方文档](https://docs.swift.org/)
- [SwiftUI官方指南](https://developer.apple.com/swiftui/)
- [GRDB官方文档](https://github.com/groue/GRDB.swift)

### 架构设计
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [MVVM Pattern in SwiftUI](https://www.hackingwithswift.com/books/ios-swiftui/introducing-mvvm-into-your-swiftui-project)
- [Repository Pattern](https://martinfowler.com/eaaCatalog/repository.html)

### 性能优化
- [Swift Performance Tips](https://github.com/apple/swift/blob/main/docs/OptimizationTips.rst)
- [SwiftUI Performance](https://www.hackingwithswift.com/articles/216/complete-guide-to-swiftui-performance)

### 安全最佳实践
- [iOS Security Guide](https://www.apple.com/business/docs/site/iOS_Security_Guide.pdf)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security-testing-guide/)

---

*本文档将随着项目的发展持续更新，确保架构设计与最佳实践保持同步。*
# 应用架构模块详解

## 📋 概述

应用架构模块是V2rayU的核心架构设计，采用分层架构模式，确保代码的可维护性、可扩展性和可测试性。本文档详细介绍了架构的各个层次、设计原则和实现细节。

## 🏗️ 架构层次

### 1. 表现层 (Presentation Layer)

#### 职责
- 用户界面展示
- 用户交互处理
- 数据绑定和状态管理
- 视图生命周期管理

#### 核心组件
```swift
// MARK: - 主要视图组件
struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var proxyManager = ProxyManager.shared
    
    var body: some View {
        NavigationView {
            ProxyListView()
                .navigationTitle("V2rayU")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("添加代理") {
                            // 添加代理逻辑
                        }
                    }
                }
        }
        .environmentObject(appState)
        .environmentObject(proxyManager)
    }
}

// MARK: - 代理列表视图
struct ProxyListView: View {
    @EnvironmentObject var proxyManager: ProxyManager
    @State private var selectedProxy: ProxyConfig?
    
    var body: some View {
        List(proxyManager.proxies, id: \.id) { proxy in
            ProxyRowView(proxy: proxy)
                .onTapGesture {
                    selectedProxy = proxy
                }
        }
        .sheet(item: $selectedProxy) { proxy in
            ProxyDetailView(proxy: proxy)
        }
    }
}

// MARK: - 代理行视图
struct ProxyRowView: View {
    let proxy: ProxyConfig
    @EnvironmentObject var proxyManager: ProxyManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(proxy.name)
                    .font(.headline)
                Text("\(proxy.serverAddress):\(proxy.serverPort)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            StatusIndicatorView(isActive: proxy.id == proxyManager.activeProxy?.id)
            
            Button(proxy.id == proxyManager.activeProxy?.id ? "断开" : "连接") {
                Task {
                    if proxy.id == proxyManager.activeProxy?.id {
                        await proxyManager.deactivateProxy()
                    } else {
                        try await proxyManager.activateProxy(proxy)
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}
```

#### 状态管理
```swift
// MARK: - 应用状态管理
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isMenuBarVisible = true
    @Published var currentTheme: AppTheme = .system
    @Published var language: AppLanguage = .system
    @Published var isFirstLaunch = true
    
    private init() {
        loadSettings()
    }
    
    func updateTheme(_ theme: AppTheme) {
        currentTheme = theme
        saveSettings()
    }
    
    func updateLanguage(_ language: AppLanguage) {
        self.language = language
        saveSettings()
    }
    
    private func loadSettings() {
        // 从UserDefaults加载设置
        currentTheme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "app_theme") ?? "system") ?? .system
        language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "app_language") ?? "system") ?? .system
        isFirstLaunch = UserDefaults.standard.bool(forKey: "is_first_launch")
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
        UserDefaults.standard.set(language.rawValue, forKey: "app_language")
        UserDefaults.standard.set(false, forKey: "is_first_launch")
    }
}

// MARK: - 主题枚举
enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        case .system: return "跟随系统"
        }
    }
}

// MARK: - 语言枚举
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case chinese = "zh"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        case .system: return "跟随系统"
        }
    }
}
```

### 2. 业务逻辑层 (Business Logic Layer)

#### 职责
- 业务规则实现
- 数据处理和转换
- 业务流程协调
- 领域模型管理

#### 核心管理器
```swift
// MARK: - 代理管理器
@MainActor
class ProxyManager: ObservableObject {
    static let shared = ProxyManager()
    
    @Published var proxies: [ProxyConfig] = []
    @Published var activeProxy: ProxyConfig?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    private let repository: ProxyRepository
    private let networkService: NetworkService
    private let systemProxyService: SystemProxyService
    
    init(
        repository: ProxyRepository = ProxyRepositoryImpl(),
        networkService: NetworkService = NetworkServiceImpl(),
        systemProxyService: SystemProxyService = SystemProxyServiceImpl()
    ) {
        self.repository = repository
        self.networkService = networkService
        self.systemProxyService = systemProxyService
        
        Task {
            await loadProxies()
        }
    }
    
    // MARK: - 代理操作
    func addProxy(_ proxy: ProxyConfig) async throws {
        try await repository.save(proxy)
        await loadProxies()
    }
    
    func updateProxy(_ proxy: ProxyConfig) async throws {
        try await repository.update(proxy)
        await loadProxies()
    }
    
    func deleteProxy(_ proxy: ProxyConfig) async throws {
        if activeProxy?.id == proxy.id {
            await deactivateProxy()
        }
        try await repository.delete(proxy)
        await loadProxies()
    }
    
    func activateProxy(_ proxy: ProxyConfig) async throws {
        // 1. 测试连接
        let isConnected = try await networkService.testConnection(to: proxy)
        guard isConnected else {
            throw ProxyError.connectionFailed
        }
        
        // 2. 停用当前代理
        if let currentProxy = activeProxy {
            await deactivateProxy()
        }
        
        // 3. 启动新代理
        try await systemProxyService.setSystemProxy(proxy)
        
        // 4. 更新状态
        activeProxy = proxy
        connectionStatus = .connected
        
        // 5. 保存状态
        try await repository.setActiveProxy(proxy)
    }
    
    func deactivateProxy() async {
        // 1. 清除系统代理
        await systemProxyService.clearSystemProxy()
        
        // 2. 更新状态
        activeProxy = nil
        connectionStatus = .disconnected
        
        // 3. 保存状态
        try? await repository.clearActiveProxy()
    }
    
    func testProxy(_ proxy: ProxyConfig) async -> Bool {
        do {
            return try await networkService.testConnection(to: proxy)
        } catch {
            return false
        }
    }
    
    func batchTestProxies(_ proxies: [ProxyConfig]) async -> [ProxyTestResult] {
        await withTaskGroup(of: ProxyTestResult.self) { group in
            for proxy in proxies {
                group.addTask {
                    let startTime = Date()
                    let isConnected = await self.testProxy(proxy)
                    let latency = Date().timeIntervalSince(startTime)
                    
                    return ProxyTestResult(
                        proxy: proxy,
                        isConnected: isConnected,
                        latency: latency
                    )
                }
            }
            
            var results: [ProxyTestResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    // MARK: - 私有方法
    private func loadProxies() async {
        do {
            let loadedProxies = try await repository.fetchAll()
            proxies = loadedProxies
            
            // 恢复活跃代理状态
            if let activeProxyId = try? await repository.getActiveProxyId() {
                activeProxy = proxies.first { $0.id == activeProxyId }
                connectionStatus = activeProxy != nil ? .connected : .disconnected
            }
        } catch {
            print("Failed to load proxies: \(error)")
        }
    }
}

// MARK: - 订阅管理器
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var subscriptions: [Subscription] = []
    @Published var isUpdating = false
    
    private let repository: SubscriptionRepository
    private let networkService: NetworkService
    private let proxyManager: ProxyManager
    
    init(
        repository: SubscriptionRepository = SubscriptionRepositoryImpl(),
        networkService: NetworkService = NetworkServiceImpl(),
        proxyManager: ProxyManager = ProxyManager.shared
    ) {
        self.repository = repository
        self.networkService = networkService
        self.proxyManager = proxyManager
        
        Task {
            await loadSubscriptions()
        }
    }
    
    func addSubscription(_ subscription: Subscription) async throws {
        try await repository.save(subscription)
        await loadSubscriptions()
    }
    
    func updateSubscription(_ subscription: Subscription) async throws {
        try await repository.update(subscription)
        await loadSubscriptions()
    }
    
    func deleteSubscription(_ subscription: Subscription) async throws {
        try await repository.delete(subscription)
        await loadSubscriptions()
    }
    
    func syncSubscription(_ subscription: Subscription) async throws {
        isUpdating = true
        defer { isUpdating = false }
        
        do {
            // 1. 下载订阅内容
            let content = try await networkService.downloadSubscription(from: subscription.url)
            
            // 2. 解析代理配置
            let proxies = try parseSubscriptionContent(content)
            
            // 3. 更新代理列表
            for proxy in proxies {
                var updatedProxy = proxy
                updatedProxy.subscriptionId = subscription.id
                try await proxyManager.addProxy(updatedProxy)
            }
            
            // 4. 更新订阅信息
            var updatedSubscription = subscription
            updatedSubscription.lastUpdateTime = Date()
            updatedSubscription.proxyCount = proxies.count
            try await updateSubscription(updatedSubscription)
            
        } catch {
            throw SubscriptionError.syncFailed(error)
        }
    }
    
    func syncAllSubscriptions() async {
        isUpdating = true
        defer { isUpdating = false }
        
        await withTaskGroup(of: Void.self) { group in
            for subscription in subscriptions where subscription.isEnabled {
                group.addTask {
                    try? await self.syncSubscription(subscription)
                }
            }
        }
    }
    
    private func loadSubscriptions() async {
        do {
            subscriptions = try await repository.fetchAll()
        } catch {
            print("Failed to load subscriptions: \(error)")
        }
    }
    
    private func parseSubscriptionContent(_ content: String) throws -> [ProxyConfig] {
        // 实现订阅内容解析逻辑
        // 支持多种格式：base64编码的vmess/vless链接、clash配置等
        return []
    }
}
```

### 3. 数据访问层 (Data Access Layer)

#### 职责
- 数据持久化
- 数据库操作
- 缓存管理
- 数据同步

#### Repository模式实现
```swift
// MARK: - 代理仓库协议
protocol ProxyRepository {
    func save(_ proxy: ProxyConfig) async throws
    func fetchAll() async throws -> [ProxyConfig]
    func fetch(by id: UUID) async throws -> ProxyConfig?
    func update(_ proxy: ProxyConfig) async throws
    func delete(_ proxy: ProxyConfig) async throws
    func setActiveProxy(_ proxy: ProxyConfig) async throws
    func getActiveProxyId() async throws -> UUID?
    func clearActiveProxy() async throws
}

// MARK: - 代理仓库实现
class ProxyRepositoryImpl: ProxyRepository {
    private let database: DatabaseManager
    
    init(database: DatabaseManager = DatabaseManager.shared) {
        self.database = database
    }
    
    func save(_ proxy: ProxyConfig) async throws {
        try await database.write { db in
            try proxy.insert(db)
        }
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
    
    func update(_ proxy: ProxyConfig) async throws {
        try await database.write { db in
            try proxy.update(db)
        }
    }
    
    func delete(_ proxy: ProxyConfig) async throws {
        try await database.write { db in
            try proxy.delete(db)
        }
    }
    
    func setActiveProxy(_ proxy: ProxyConfig) async throws {
        try await database.write { db in
            // 清除所有活跃状态
            try db.execute(sql: "UPDATE proxy_configs SET is_active = 0")
            // 设置新的活跃代理
            try db.execute(sql: "UPDATE proxy_configs SET is_active = 1 WHERE id = ?", arguments: [proxy.id])
        }
    }
    
    func getActiveProxyId() async throws -> UUID? {
        return try await database.read { db in
            try UUID.fetchOne(db, sql: "SELECT id FROM proxy_configs WHERE is_active = 1")
        }
    }
    
    func clearActiveProxy() async throws {
        try await database.write { db in
            try db.execute(sql: "UPDATE proxy_configs SET is_active = 0")
        }
    }
}
```

### 4. 基础设施层 (Infrastructure Layer)

#### 职责
- 外部服务集成
- 系统API调用
- 网络通信
- 文件系统操作

#### 网络服务实现
```swift
// MARK: - 网络服务协议
protocol NetworkService {
    func testConnection(to proxy: ProxyConfig) async throws -> Bool
    func downloadSubscription(from url: String) async throws -> String
    func measureLatency(to proxy: ProxyConfig) async throws -> TimeInterval
}

// MARK: - 网络服务实现
class NetworkServiceImpl: NetworkService {
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        self.session = URLSession(configuration: config)
    }
    
    func testConnection(to proxy: ProxyConfig) async throws -> Bool {
        // 实现代理连接测试
        let testURL = URL(string: "https://www.google.com")!
        
        do {
            let (_, response) = try await session.data(from: testURL)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
    
    func downloadSubscription(from url: String) async throws -> String {
        guard let subscriptionURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await session.data(from: subscriptionURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.httpError(response)
        }
        
        guard let content = String(data: data, encoding: .utf8) else {
            throw NetworkError.invalidData
        }
        
        return content
    }
    
    func measureLatency(to proxy: ProxyConfig) async throws -> TimeInterval {
        let startTime = Date()
        let isConnected = try await testConnection(to: proxy)
        let endTime = Date()
        
        guard isConnected else {
            throw NetworkError.connectionFailed
        }
        
        return endTime.timeIntervalSince(startTime)
    }
}
```

## 🔄 依赖注入

### 依赖注入容器
```swift
// MARK: - 依赖注入容器
class DIContainer {
    static let shared = DIContainer()
    
    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    
    private init() {
        registerDefaultServices()
    }
    
    // MARK: - 注册服务
    func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        services[key] = service
    }
    
    func register<T>(_ factory: @escaping () -> T, for type: T.Type) {
        let key = String(describing: type)
        factories[key] = factory
    }
    
    // MARK: - 解析服务
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        
        // 首先尝试从已注册的服务中获取
        if let service = services[key] as? T {
            return service
        }
        
        // 然后尝试从工厂方法创建
        if let factory = factories[key] {
            let service = factory() as! T
            services[key] = service // 缓存创建的服务
            return service
        }
        
        return nil
    }
    
    // MARK: - 默认服务注册
    private func registerDefaultServices() {
        // 注册数据库管理器
        register(DatabaseManager.shared, for: DatabaseManager.self)
        
        // 注册仓库
        register({ ProxyRepositoryImpl() }, for: ProxyRepository.self)
        register({ SubscriptionRepositoryImpl() }, for: SubscriptionRepository.self)
        
        // 注册服务
        register({ NetworkServiceImpl() }, for: NetworkService.self)
        register({ SystemProxyServiceImpl() }, for: SystemProxyService.self)
        
        // 注册管理器
        register({ ProxyManager.shared }, for: ProxyManager.self)
        register({ SubscriptionManager.shared }, for: SubscriptionManager.self)
    }
}

// MARK: - 依赖注入属性包装器
@propertyWrapper
struct Inject<T> {
    private let type: T.Type
    
    init(_ type: T.Type) {
        self.type = type
    }
    
    var wrappedValue: T {
        guard let service = DIContainer.shared.resolve(type) else {
            fatalError("Service of type \(type) not registered")
        }
        return service
    }
}

// 使用示例
class SomeService {
    @Inject(NetworkService.self)
    private var networkService: NetworkService
    
    @Inject(ProxyRepository.self)
    private var proxyRepository: ProxyRepository
    
    func doSomething() {
        // 使用注入的依赖
    }
}
```

## 📊 架构优势

### 1. 可维护性
- **清晰的职责分离**：每层都有明确的职责
- **低耦合高内聚**：模块间依赖最小化
- **一致的设计模式**：整个应用使用统一的设计模式

### 2. 可扩展性
- **插件化架构**：支持功能模块的动态加载
- **接口导向设计**：易于添加新的实现
- **配置驱动**：通过配置文件控制行为

### 3. 可测试性
- **依赖注入**：便于Mock和单元测试
- **接口抽象**：测试时可以替换实现
- **纯函数设计**：业务逻辑易于测试

### 4. 性能优化
- **异步处理**：使用async/await处理耗时操作
- **缓存机制**：减少重复计算和网络请求
- **懒加载**：按需加载资源

## 🔧 最佳实践

### 1. 代码组织
```
V2rayU/
├── Presentation/           # 表现层
│   ├── Views/             # SwiftUI视图
│   ├── ViewModels/        # 视图模型
│   └── Components/        # 可复用组件
├── Business/              # 业务逻辑层
│   ├── Managers/          # 业务管理器
│   ├── Services/          # 业务服务
│   └── Models/            # 业务模型
├── Data/                  # 数据访问层
│   ├── Repositories/      # 仓库实现
│   ├── Database/          # 数据库相关
│   └── Cache/             # 缓存实现
├── Infrastructure/        # 基础设施层
│   ├── Network/           # 网络服务
│   ├── System/            # 系统服务
│   └── External/          # 外部服务集成
└── Core/                  # 核心组件
    ├── DI/                # 依赖注入
    ├── Extensions/        # 扩展
    └── Utilities/         # 工具类
```

### 2. 错误处理
```swift
// 统一错误处理
enum AppError: Error, LocalizedError {
    case networkError(NetworkError)
    case databaseError(DatabaseError)
    case proxyError(ProxyError)
    case subscriptionError(SubscriptionError)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .databaseError(let error):
            return "数据库错误: \(error.localizedDescription)"
        case .proxyError(let error):
            return "代理错误: \(error.localizedDescription)"
        case .subscriptionError(let error):
            return "订阅错误: \(error.localizedDescription)"
        }
    }
}
```

### 3. 日志记录
```swift
// 结构化日志
LogManager.shared.info("代理激活成功", category: "ProxyManager", metadata: [
    "proxyId": proxy.id.uuidString,
    "proxyName": proxy.name,
    "serverAddress": proxy.serverAddress
])
```

## 📚 相关文档

- [数据库层模块](database-layer.md)
- [处理器层模块](handler-layer.md)
- [协议层模块](protocol-layer.md)
- [视图层模块](view-layer.md)
- [基础工具模块](base-utilities.md)

---

*本文档描述了V2rayU应用架构的核心设计，为开发者提供了清晰的架构指导。*
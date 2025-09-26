# 处理器层模块详解

## 📋 概述

处理器层模块是V2rayU业务逻辑的核心，负责协调各个组件之间的交互，处理用户操作，管理应用状态。本模块采用MVVM架构模式，通过各种Handler类来封装具体的业务逻辑，确保代码的可维护性和可测试性。

## 🏗️ 架构设计

### 1. 处理器基类

```swift
// MARK: - 基础处理器协议
protocol BaseHandler: AnyObject {
    associatedtype Input
    associatedtype Output
    
    func handle(_ input: Input) async throws -> Output
}

// MARK: - 异步处理器基类
@MainActor
class AsyncHandler<Input, Output>: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    
    private let logger = LogManager.shared
    
    func execute(_ input: Input, operation: @escaping (Input) async throws -> Output) async -> Output? {
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let result = try await operation(input)
            logger.info("Handler operation completed successfully", category: .handler)
            return result
        } catch {
            self.error = error
            logger.error("Handler operation failed: \(error)", category: .handler)
            return nil
        }
    }
    
    func clearError() {
        error = nil
    }
}

// MARK: - 处理器错误类型
enum HandlerError: Error, LocalizedError {
    case invalidInput(String)
    case operationFailed(String)
    case networkError(Error)
    case databaseError(Error)
    case validationError(String)
    case unauthorized
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "输入无效: \(message)"
        case .operationFailed(let message):
            return "操作失败: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .databaseError(let error):
            return "数据库错误: \(error.localizedDescription)"
        case .validationError(let message):
            return "验证失败: \(message)"
        case .unauthorized:
            return "未授权访问"
        case .timeout:
            return "操作超时"
        }
    }
}
```

## 🔧 核心处理器

### 1. 代理管理处理器

```swift
// MARK: - 代理管理处理器
@MainActor
class ProxyHandler: AsyncHandler<ProxyHandler.Input, ProxyHandler.Output> {
    
    // MARK: - 输入输出类型
    enum Input {
        case addProxy(ProxyConfig)
        case updateProxy(ProxyConfig)
        case deleteProxy(UUID)
        case activateProxy(UUID)
        case deactivateProxy
        case testProxy(UUID)
        case batchTestProxies([UUID])
        case importFromURL(String)
        case exportProxies([UUID])
    }
    
    enum Output {
        case proxyAdded(ProxyConfig)
        case proxyUpdated(ProxyConfig)
        case proxyDeleted(UUID)
        case proxyActivated(ProxyConfig)
        case proxyDeactivated
        case testResult(UUID, PingResult)
        case batchTestResults([UUID: PingResult])
        case importResult([ProxyConfig])
        case exportResult(String)
    }
    
    // MARK: - 依赖注入
    private let proxyRepository: ProxyRepository
    private let networkService: NetworkService
    private let systemProxyService: SystemProxyService
    private let configParser: ConfigParser
    private let pingTester: PingTester
    
    init(
        proxyRepository: ProxyRepository,
        networkService: NetworkService,
        systemProxyService: SystemProxyService,
        configParser: ConfigParser,
        pingTester: PingTester
    ) {
        self.proxyRepository = proxyRepository
        self.networkService = networkService
        self.systemProxyService = systemProxyService
        self.configParser = configParser
        self.pingTester = pingTester
    }
    
    // MARK: - 主要处理方法
    func handle(_ input: Input) async -> Output? {
        switch input {
        case .addProxy(let proxy):
            return await execute(proxy) { proxy in
                try await self.addProxy(proxy)
            }.map { .proxyAdded($0) }
            
        case .updateProxy(let proxy):
            return await execute(proxy) { proxy in
                try await self.updateProxy(proxy)
            }.map { .proxyUpdated($0) }
            
        case .deleteProxy(let id):
            return await execute(id) { id in
                try await self.deleteProxy(id)
            }.map { .proxyDeleted($0) }
            
        case .activateProxy(let id):
            return await execute(id) { id in
                try await self.activateProxy(id)
            }.map { .proxyActivated($0) }
            
        case .deactivateProxy:
            return await execute(()) { _ in
                try await self.deactivateProxy()
            }.map { .proxyDeactivated }
            
        case .testProxy(let id):
            return await execute(id) { id in
                try await self.testProxy(id)
            }.map { result in .testResult(input.proxyId, result) }
            
        case .batchTestProxies(let ids):
            return await execute(ids) { ids in
                try await self.batchTestProxies(ids)
            }.map { .batchTestResults($0) }
            
        case .importFromURL(let url):
            return await execute(url) { url in
                try await self.importFromURL(url)
            }.map { .importResult($0) }
            
        case .exportProxies(let ids):
            return await execute(ids) { ids in
                try await self.exportProxies(ids)
            }.map { .exportResult($0) }
        }
    }
    
    // MARK: - 私有实现方法
    private func addProxy(_ proxy: ProxyConfig) async throws -> ProxyConfig {
        // 验证代理配置
        try validateProxyConfig(proxy)
        
        // 保存到数据库
        try await proxyRepository.save(proxy)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .proxyAdded,
            object: proxy
        )
        
        return proxy
    }
    
    private func updateProxy(_ proxy: ProxyConfig) async throws -> ProxyConfig {
        // 验证代理配置
        try validateProxyConfig(proxy)
        
        // 检查代理是否存在
        guard let existingProxy = try await proxyRepository.fetch(by: proxy.id) else {
            throw HandlerError.invalidInput("代理不存在")
        }
        
        // 如果是活跃代理，需要重新配置系统代理
        if existingProxy.isActive {
            try await systemProxyService.updateProxy(proxy)
        }
        
        // 更新数据库
        try await proxyRepository.update(proxy)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .proxyUpdated,
            object: proxy
        )
        
        return proxy
    }
    
    private func deleteProxy(_ id: UUID) async throws -> UUID {
        // 检查代理是否存在
        guard let proxy = try await proxyRepository.fetch(by: id) else {
            throw HandlerError.invalidInput("代理不存在")
        }
        
        // 如果是活跃代理，先停用
        if proxy.isActive {
            try await deactivateProxy()
        }
        
        // 删除数据库记录
        try await proxyRepository.delete(proxy)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .proxyDeleted,
            object: id
        )
        
        return id
    }
    
    private func activateProxy(_ id: UUID) async throws -> ProxyConfig {
        // 获取代理配置
        guard let proxy = try await proxyRepository.fetch(by: id) else {
            throw HandlerError.invalidInput("代理不存在")
        }
        
        // 验证代理配置
        try validateProxyConfig(proxy)
        
        // 设置系统代理
        try await systemProxyService.setProxy(proxy)
        
        // 更新数据库状态
        try await proxyRepository.setActiveProxy(proxy)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .proxyActivated,
            object: proxy
        )
        
        return proxy
    }
    
    private func deactivateProxy() async throws {
        // 清除系统代理
        try await systemProxyService.clearProxy()
        
        // 更新数据库状态
        try await proxyRepository.clearActiveProxy()
        
        // 发送通知
        NotificationCenter.default.post(
            name: .proxyDeactivated,
            object: nil
        )
    }
    
    private func testProxy(_ id: UUID) async throws -> PingResult {
        // 获取代理配置
        guard let proxy = try await proxyRepository.fetch(by: id) else {
            throw HandlerError.invalidInput("代理不存在")
        }
        
        // 执行延迟测试
        let result = await pingTester.testProxy(proxy)
        
        // 保存测试结果
        let record = PingRecord(
            proxyId: proxy.id,
            latency: result.latency,
            isSuccess: result.isSuccess,
            errorMessage: result.error?.localizedDescription,
            testTime: Date()
        )
        
        // 这里可以保存到数据库
        // try await pingRecordRepository.save(record)
        
        return result
    }
    
    private func batchTestProxies(_ ids: [UUID]) async throws -> [UUID: PingResult] {
        var results: [UUID: PingResult] = [:]
        
        // 并发测试所有代理
        await withTaskGroup(of: (UUID, PingResult).self) { group in
            for id in ids {
                group.addTask {
                    do {
                        let result = try await self.testProxy(id)
                        return (id, result)
                    } catch {
                        return (id, PingResult(latency: nil, isSuccess: false, error: error))
                    }
                }
            }
            
            for await (id, result) in group {
                results[id] = result
            }
        }
        
        return results
    }
    
    private func importFromURL(_ urlString: String) async throws -> [ProxyConfig] {
        // 验证URL
        guard let url = URL(string: urlString) else {
            throw HandlerError.invalidInput("无效的URL")
        }
        
        // 下载配置内容
        let content = try await networkService.downloadString(from: url)
        
        // 解析配置
        let proxies = try configParser.parseSubscriptionContent(content)
        
        // 批量保存
        for proxy in proxies {
            try await proxyRepository.save(proxy)
        }
        
        return proxies
    }
    
    private func exportProxies(_ ids: [UUID]) async throws -> String {
        var proxies: [ProxyConfig] = []
        
        // 获取所有代理配置
        for id in ids {
            if let proxy = try await proxyRepository.fetch(by: id) {
                proxies.append(proxy)
            }
        }
        
        // 导出为配置文件格式
        return try configParser.exportProxies(proxies)
    }
    
    // MARK: - 验证方法
    private func validateProxyConfig(_ proxy: ProxyConfig) throws {
        // 验证服务器地址
        if proxy.serverAddress.isEmpty {
            throw HandlerError.validationError("服务器地址不能为空")
        }
        
        // 验证端口
        if proxy.serverPort <= 0 || proxy.serverPort > 65535 {
            throw HandlerError.validationError("端口号必须在1-65535之间")
        }
        
        // 根据协议类型验证特定字段
        switch proxy.protocolType {
        case .vmess, .vless:
            if proxy.userId?.isEmpty ?? true {
                throw HandlerError.validationError("用户ID不能为空")
            }
            
        case .shadowsocks:
            if proxy.password?.isEmpty ?? true {
                throw HandlerError.validationError("密码不能为空")
            }
            if proxy.method?.isEmpty ?? true {
                throw HandlerError.validationError("加密方法不能为空")
            }
            
        case .trojan:
            if proxy.password?.isEmpty ?? true {
                throw HandlerError.validationError("密码不能为空")
            }
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
}
```

### 2. 订阅管理处理器

```swift
// MARK: - 订阅管理处理器
@MainActor
class SubscriptionHandler: AsyncHandler<SubscriptionHandler.Input, SubscriptionHandler.Output> {
    
    // MARK: - 输入输出类型
    enum Input {
        case addSubscription(String, String) // name, url
        case updateSubscription(Subscription)
        case deleteSubscription(UUID)
        case syncSubscription(UUID)
        case syncAllSubscriptions
        case toggleSubscription(UUID, Bool)
        case setAutoUpdate(UUID, Bool, Int) // id, enabled, interval
    }
    
    enum Output {
        case subscriptionAdded(Subscription)
        case subscriptionUpdated(Subscription)
        case subscriptionDeleted(UUID)
        case syncCompleted(UUID, Int) // id, proxy count
        case syncAllCompleted([UUID: Int])
        case subscriptionToggled(UUID, Bool)
        case autoUpdateSet(UUID, Bool, Int)
    }
    
    // MARK: - 依赖注入
    private let subscriptionRepository: SubscriptionRepository
    private let proxyRepository: ProxyRepository
    private let networkService: NetworkService
    private let configParser: ConfigParser
    
    init(
        subscriptionRepository: SubscriptionRepository,
        proxyRepository: ProxyRepository,
        networkService: NetworkService,
        configParser: ConfigParser
    ) {
        self.subscriptionRepository = subscriptionRepository
        self.proxyRepository = proxyRepository
        self.networkService = networkService
        self.configParser = configParser
    }
    
    // MARK: - 主要处理方法
    func handle(_ input: Input) async -> Output? {
        switch input {
        case .addSubscription(let name, let url):
            return await execute((name, url)) { (name, url) in
                try await self.addSubscription(name: name, url: url)
            }.map { .subscriptionAdded($0) }
            
        case .updateSubscription(let subscription):
            return await execute(subscription) { subscription in
                try await self.updateSubscription(subscription)
            }.map { .subscriptionUpdated($0) }
            
        case .deleteSubscription(let id):
            return await execute(id) { id in
                try await self.deleteSubscription(id)
            }.map { .subscriptionDeleted($0) }
            
        case .syncSubscription(let id):
            return await execute(id) { id in
                try await self.syncSubscription(id)
            }.map { count in .syncCompleted(input.subscriptionId, count) }
            
        case .syncAllSubscriptions:
            return await execute(()) { _ in
                try await self.syncAllSubscriptions()
            }.map { .syncAllCompleted($0) }
            
        case .toggleSubscription(let id, let enabled):
            return await execute((id, enabled)) { (id, enabled) in
                try await self.toggleSubscription(id, enabled: enabled)
            }.map { .subscriptionToggled(id, enabled) }
            
        case .setAutoUpdate(let id, let enabled, let interval):
            return await execute((id, enabled, interval)) { (id, enabled, interval) in
                try await self.setAutoUpdate(id, enabled: enabled, interval: interval)
            }.map { .autoUpdateSet(id, enabled, interval) }
        }
    }
    
    // MARK: - 私有实现方法
    private func addSubscription(name: String, url: String) async throws -> Subscription {
        // 验证输入
        try validateSubscriptionInput(name: name, url: url)
        
        // 创建订阅对象
        let subscription = Subscription(name: name, url: url)
        
        // 保存到数据库
        try await subscriptionRepository.save(subscription)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .subscriptionAdded,
            object: subscription
        )
        
        return subscription
    }
    
    private func updateSubscription(_ subscription: Subscription) async throws -> Subscription {
        // 验证输入
        try validateSubscriptionInput(name: subscription.name, url: subscription.url)
        
        // 更新数据库
        try await subscriptionRepository.update(subscription)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .subscriptionUpdated,
            object: subscription
        )
        
        return subscription
    }
    
    private func deleteSubscription(_ id: UUID) async throws -> UUID {
        // 检查订阅是否存在
        guard let subscription = try await subscriptionRepository.fetch(by: id) else {
            throw HandlerError.invalidInput("订阅不存在")
        }
        
        // 删除订阅（会级联删除相关代理）
        try await subscriptionRepository.delete(subscription)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .subscriptionDeleted,
            object: id
        )
        
        return id
    }
    
    private func syncSubscription(_ id: UUID) async throws -> Int {
        // 获取订阅
        guard var subscription = try await subscriptionRepository.fetch(by: id) else {
            throw HandlerError.invalidInput("订阅不存在")
        }
        
        // 检查订阅是否启用
        if !subscription.isEnabled {
            throw HandlerError.operationFailed("订阅已禁用")
        }
        
        // 下载订阅内容
        guard let url = URL(string: subscription.url) else {
            throw HandlerError.invalidInput("无效的订阅URL")
        }
        
        let content = try await networkService.downloadString(from: url)
        
        // 解析代理配置
        let proxies = try configParser.parseSubscriptionContent(content)
        
        // 删除旧的代理配置
        let oldProxies = try await proxyRepository.fetchBySubscription(subscription.id)
        for proxy in oldProxies {
            try await proxyRepository.delete(proxy)
        }
        
        // 保存新的代理配置
        var savedProxies: [ProxyConfig] = []
        for var proxy in proxies {
            proxy.subscriptionId = subscription.id
            try await proxyRepository.save(proxy)
            savedProxies.append(proxy)
        }
        
        // 更新订阅信息
        subscription.lastUpdateTime = Date()
        subscription.proxyCount = savedProxies.count
        subscription.updatedAt = Date()
        try await subscriptionRepository.update(subscription)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .subscriptionSynced,
            object: subscription
        )
        
        return savedProxies.count
    }
    
    private func syncAllSubscriptions() async throws -> [UUID: Int] {
        // 获取所有启用的订阅
        let subscriptions = try await subscriptionRepository.fetchEnabled()
        var results: [UUID: Int] = [:]
        
        // 并发同步所有订阅
        await withTaskGroup(of: (UUID, Int?).self) { group in
            for subscription in subscriptions {
                group.addTask {
                    do {
                        let count = try await self.syncSubscription(subscription.id)
                        return (subscription.id, count)
                    } catch {
                        return (subscription.id, nil)
                    }
                }
            }
            
            for await (id, count) in group {
                if let count = count {
                    results[id] = count
                }
            }
        }
        
        return results
    }
    
    private func toggleSubscription(_ id: UUID, enabled: Bool) async throws {
        // 获取订阅
        guard var subscription = try await subscriptionRepository.fetch(by: id) else {
            throw HandlerError.invalidInput("订阅不存在")
        }
        
        // 更新状态
        subscription.isEnabled = enabled
        subscription.updatedAt = Date()
        
        // 保存到数据库
        try await subscriptionRepository.update(subscription)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .subscriptionToggled,
            object: subscription
        )
    }
    
    private func setAutoUpdate(_ id: UUID, enabled: Bool, interval: Int) async throws {
        // 获取订阅
        guard var subscription = try await subscriptionRepository.fetch(by: id) else {
            throw HandlerError.invalidInput("订阅不存在")
        }
        
        // 验证更新间隔
        if interval < 1 || interval > 168 { // 1小时到1周
            throw HandlerError.validationError("更新间隔必须在1-168小时之间")
        }
        
        // 更新设置
        subscription.autoUpdate = enabled
        subscription.updateInterval = interval
        subscription.updatedAt = Date()
        
        // 保存到数据库
        try await subscriptionRepository.update(subscription)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .subscriptionAutoUpdateChanged,
            object: subscription
        )
    }
    
    // MARK: - 验证方法
    private func validateSubscriptionInput(name: String, url: String) throws {
        // 验证名称
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw HandlerError.validationError("订阅名称不能为空")
        }
        
        // 验证URL
        guard let _ = URL(string: url), url.hasPrefix("http") else {
            throw HandlerError.validationError("无效的订阅URL")
        }
    }
}

// MARK: - 订阅通知扩展
extension Notification.Name {
    static let subscriptionAdded = Notification.Name("subscriptionAdded")
    static let subscriptionUpdated = Notification.Name("subscriptionUpdated")
    static let subscriptionDeleted = Notification.Name("subscriptionDeleted")
    static let subscriptionSynced = Notification.Name("subscriptionSynced")
    static let subscriptionToggled = Notification.Name("subscriptionToggled")
    static let subscriptionAutoUpdateChanged = Notification.Name("subscriptionAutoUpdateChanged")
}
```

### 3. 系统代理处理器

```swift
// MARK: - 系统代理处理器
@MainActor
class SystemProxyHandler: AsyncHandler<SystemProxyHandler.Input, SystemProxyHandler.Output> {
    
    // MARK: - 输入输出类型
    enum Input {
        case enableSystemProxy(ProxyConfig)
        case disableSystemProxy
        case checkSystemProxyStatus
        case updateProxySettings(ProxySettings)
        case resetSystemProxy
    }
    
    enum Output {
        case systemProxyEnabled(ProxyConfig)
        case systemProxyDisabled
        case systemProxyStatus(Bool, ProxyConfig?)
        case proxySettingsUpdated(ProxySettings)
        case systemProxyReset
    }
    
    // MARK: - 依赖注入
    private let systemProxyService: SystemProxyService
    private let proxyRepository: ProxyRepository
    
    init(
        systemProxyService: SystemProxyService,
        proxyRepository: ProxyRepository
    ) {
        self.systemProxyService = systemProxyService
        self.proxyRepository = proxyRepository
    }
    
    // MARK: - 主要处理方法
    func handle(_ input: Input) async -> Output? {
        switch input {
        case .enableSystemProxy(let proxy):
            return await execute(proxy) { proxy in
                try await self.enableSystemProxy(proxy)
            }.map { .systemProxyEnabled($0) }
            
        case .disableSystemProxy:
            return await execute(()) { _ in
                try await self.disableSystemProxy()
            }.map { .systemProxyDisabled }
            
        case .checkSystemProxyStatus:
            return await execute(()) { _ in
                try await self.checkSystemProxyStatus()
            }.map { (enabled, proxy) in .systemProxyStatus(enabled, proxy) }
            
        case .updateProxySettings(let settings):
            return await execute(settings) { settings in
                try await self.updateProxySettings(settings)
            }.map { .proxySettingsUpdated($0) }
            
        case .resetSystemProxy:
            return await execute(()) { _ in
                try await self.resetSystemProxy()
            }.map { .systemProxyReset }
        }
    }
    
    // MARK: - 私有实现方法
    private func enableSystemProxy(_ proxy: ProxyConfig) async throws -> ProxyConfig {
        // 验证代理配置
        try validateProxyForSystemUse(proxy)
        
        // 设置系统代理
        try await systemProxyService.setProxy(proxy)
        
        // 更新数据库状态
        try await proxyRepository.setActiveProxy(proxy)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .systemProxyEnabled,
            object: proxy
        )
        
        return proxy
    }
    
    private func disableSystemProxy() async throws {
        // 清除系统代理
        try await systemProxyService.clearProxy()
        
        // 更新数据库状态
        try await proxyRepository.clearActiveProxy()
        
        // 发送通知
        NotificationCenter.default.post(
            name: .systemProxyDisabled,
            object: nil
        )
    }
    
    private func checkSystemProxyStatus() async throws -> (Bool, ProxyConfig?) {
        // 检查系统代理状态
        let isEnabled = await systemProxyService.isProxyEnabled()
        
        // 获取当前活跃代理
        let activeProxyId = try await proxyRepository.getActiveProxyId()
        let activeProxy = if let id = activeProxyId {
            try await proxyRepository.fetch(by: id)
        } else {
            nil
        }
        
        return (isEnabled, activeProxy)
    }
    
    private func updateProxySettings(_ settings: ProxySettings) async throws -> ProxySettings {
        // 应用代理设置
        try await systemProxyService.updateSettings(settings)
        
        // 发送通知
        NotificationCenter.default.post(
            name: .proxySettingsUpdated,
            object: settings
        )
        
        return settings
    }
    
    private func resetSystemProxy() async throws {
        // 重置系统代理设置
        try await systemProxyService.resetToDefault()
        
        // 清除数据库状态
        try await proxyRepository.clearActiveProxy()
        
        // 发送通知
        NotificationCenter.default.post(
            name: .systemProxyReset,
            object: nil
        )
    }
    
    // MARK: - 验证方法
    private func validateProxyForSystemUse(_ proxy: ProxyConfig) throws {
        // 检查基本配置
        if proxy.serverAddress.isEmpty {
            throw HandlerError.validationError("服务器地址不能为空")
        }
        
        if proxy.serverPort <= 0 || proxy.serverPort > 65535 {
            throw HandlerError.validationError("端口号无效")
        }
        
        // 检查协议特定配置
        switch proxy.protocolType {
        case .vmess, .vless:
            if proxy.userId?.isEmpty ?? true {
                throw HandlerError.validationError("用户ID不能为空")
            }
            
        case .shadowsocks:
            if proxy.password?.isEmpty ?? true {
                throw HandlerError.validationError("密码不能为空")
            }
            if proxy.method?.isEmpty ?? true {
                throw HandlerError.validationError("加密方法不能为空")
            }
            
        case .trojan:
            if proxy.password?.isEmpty ?? true {
                throw HandlerError.validationError("密码不能为空")
            }
        }
    }
}

// MARK: - 系统代理通知扩展
extension Notification.Name {
    static let systemProxyEnabled = Notification.Name("systemProxyEnabled")
    static let systemProxyDisabled = Notification.Name("systemProxyDisabled")
    static let proxySettingsUpdated = Notification.Name("proxySettingsUpdated")
    static let systemProxyReset = Notification.Name("systemProxyReset")
}
```

### 4. 流量统计处理器

```swift
// MARK: - 流量统计处理器
@MainActor
class TrafficHandler: AsyncHandler<TrafficHandler.Input, TrafficHandler.Output> {
    
    // MARK: - 输入输出类型
    enum Input {
        case startTrafficMonitoring(UUID) // proxy id
        case stopTrafficMonitoring
        case getTrafficStats(UUID)
        case getTotalTraffic
        case getTrafficHistory(UUID, DateRange)
        case resetTrafficStats(UUID)
        case exportTrafficData(UUID, DateRange)
    }
    
    enum Output {
        case monitoringStarted(UUID)
        case monitoringStopped
        case trafficStats(UUID, TrafficStats)
        case totalTraffic(Int64, Int64, Int64) // upload, download, total
        case trafficHistory(UUID, [TrafficStats])
        case trafficStatsReset(UUID)
        case trafficDataExported(String)
    }
    
    // MARK: - 依赖注入
    private let trafficMonitor: TrafficMonitor
    private let trafficRepository: TrafficRepository
    
    private var currentSession: TrafficStats?
    private var monitoringTimer: Timer?
    
    init(
        trafficMonitor: TrafficMonitor,
        trafficRepository: TrafficRepository
    ) {
        self.trafficMonitor = trafficMonitor
        self.trafficRepository = trafficRepository
    }
    
    // MARK: - 主要处理方法
    func handle(_ input: Input) async -> Output? {
        switch input {
        case .startTrafficMonitoring(let proxyId):
            return await execute(proxyId) { proxyId in
                try await self.startTrafficMonitoring(proxyId)
            }.map { .monitoringStarted($0) }
            
        case .stopTrafficMonitoring:
            return await execute(()) { _ in
                try await self.stopTrafficMonitoring()
            }.map { .monitoringStopped }
            
        case .getTrafficStats(let proxyId):
            return await execute(proxyId) { proxyId in
                try await self.getTrafficStats(proxyId)
            }.map { stats in .trafficStats(input.proxyId, stats) }
            
        case .getTotalTraffic:
            return await execute(()) { _ in
                try await self.getTotalTraffic()
            }.map { (upload, download, total) in .totalTraffic(upload, download, total) }
            
        case .getTrafficHistory(let proxyId, let dateRange):
            return await execute((proxyId, dateRange)) { (proxyId, dateRange) in
                try await self.getTrafficHistory(proxyId, dateRange: dateRange)
            }.map { history in .trafficHistory(input.proxyId, history) }
            
        case .resetTrafficStats(let proxyId):
            return await execute(proxyId) { proxyId in
                try await self.resetTrafficStats(proxyId)
            }.map { .trafficStatsReset($0) }
            
        case .exportTrafficData(let proxyId, let dateRange):
            return await execute((proxyId, dateRange)) { (proxyId, dateRange) in
                try await self.exportTrafficData(proxyId, dateRange: dateRange)
            }.map { .trafficDataExported($0) }
        }
    }
    
    // MARK: - 私有实现方法
    private func startTrafficMonitoring(_ proxyId: UUID) async throws -> UUID {
        // 停止之前的监控
        await stopTrafficMonitoring()
        
        // 创建新的流量会话
        currentSession = TrafficStats(proxyId: proxyId)
        
        // 开始监控
        try await trafficMonitor.startMonitoring()
        
        // 启动定时器更新流量数据
        startMonitoringTimer()
        
        return proxyId
    }
    
    private func stopTrafficMonitoring() async {
        // 停止定时器
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // 停止监控
        await trafficMonitor.stopMonitoring()
        
        // 保存当前会话
        if var session = currentSession {
            session.endSession()
            try? await trafficRepository.save(session)
            currentSession = nil
        }
    }
    
    private func getTrafficStats(_ proxyId: UUID) async throws -> TrafficStats {
        // 如果是当前监控的代理，返回实时数据
        if let session = currentSession, session.proxyId == proxyId {
            return session
        }
        
        // 否则从数据库获取最新数据
        let stats = try await trafficRepository.fetchLatest(proxyId: proxyId)
        return stats ?? TrafficStats(proxyId: proxyId)
    }
    
    private func getTotalTraffic() async throws -> (Int64, Int64, Int64) {
        return try await trafficRepository.fetchTotalTraffic()
    }
    
    private func getTrafficHistory(_ proxyId: UUID, dateRange: DateRange) async throws -> [TrafficStats] {
        return try await trafficRepository.fetchHistory(
            proxyId: proxyId,
            from: dateRange.start,
            to: dateRange.end
        )
    }
    
    private func resetTrafficStats(_ proxyId: UUID) async throws -> UUID {
        try await trafficRepository.deleteAll(proxyId: proxyId)
        return proxyId
    }
    
    private func exportTrafficData(_ proxyId: UUID, dateRange: DateRange) async throws -> String {
        let history = try await getTrafficHistory(proxyId, dateRange: dateRange)
        
        // 转换为CSV格式
        var csv = "时间,上传(MB),下载(MB),总计(MB)\n"
        
        for stats in history {
            let uploadMB = Double(stats.uploadBytes) / 1024.0 / 1024.0
            let downloadMB = Double(stats.downloadBytes) / 1024.0 / 1024.0
            let totalMB = Double(stats.totalBytes) / 1024.0 / 1024.0
            
            csv += "\(stats.sessionStart),\(String(format: "%.2f", uploadMB)),\(String(format: "%.2f", downloadMB)),\(String(format: "%.2f", totalMB))\n"
        }
        
        return csv
    }
    
    // MARK: - 定时器管理
    private func startMonitoringTimer() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateTrafficData()
            }
        }
    }
    
    private func updateTrafficData() async {
        guard var session = currentSession else { return }
        
        // 获取当前流量数据
        let currentTraffic = await trafficMonitor.getCurrentTraffic()
        
        // 更新会话数据
        session.updateTraffic(
            upload: currentTraffic.upload,
            download: currentTraffic.download
        )
        
        currentSession = session
        
        // 发送实时更新通知
        NotificationCenter.default.post(
            name: .trafficUpdated,
            object: session
        )
    }
}

// MARK: - 流量统计通知扩展
extension Notification.Name {
    static let trafficUpdated = Notification.Name("trafficUpdated")
    static let trafficMonitoringStarted = Notification.Name("trafficMonitoringStarted")
    static let trafficMonitoringStopped = Notification.Name("trafficMonitoringStopped")
}

// MARK: - 日期范围结构
struct DateRange {
    let start: Date
    let end: Date
    
    static func today() -> DateRange {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return DateRange(start: start, end: end)
    }
    
    static func thisWeek() -> DateRange {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        let end = calendar.dateInterval(of: .weekOfYear, for: Date())!.end
        return DateRange(start: start, end: end)
    }
    
    static func thisMonth() -> DateRange {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .month, for: Date())!.start
        let end = calendar.dateInterval(of: .month, for: Date())!.end
        return DateRange(start: start, end: end)
    }
}
```

## 🔄 处理器协调

### 1. 处理器管理器

```swift
// MARK: - 处理器管理器
@MainActor
class HandlerManager: ObservableObject {
    
    // MARK: - 处理器实例
    let proxyHandler: ProxyHandler
    let subscriptionHandler: SubscriptionHandler
    let systemProxyHandler: SystemProxyHandler
    let trafficHandler: TrafficHandler
    
    // MARK: - 状态管理
    @Published var isProcessing = false
    @Published var lastError: Error?
    
    init(
        proxyHandler: ProxyHandler,
        subscriptionHandler: SubscriptionHandler,
        systemProxyHandler: SystemProxyHandler,
        trafficHandler: TrafficHandler
    ) {
        self.proxyHandler = proxyHandler
        self.subscriptionHandler = subscriptionHandler
        self.systemProxyHandler = systemProxyHandler
        self.trafficHandler = trafficHandler
        
        setupErrorHandling()
    }
    
    // MARK: - 错误处理设置
    private func setupErrorHandling() {
        // 监听各个处理器的错误
        Publishers.MergeMany(
            proxyHandler.$error,
            subscriptionHandler.$error,
            systemProxyHandler.$error,
            trafficHandler.$error
        )
        .compactMap { $0 }
        .assign(to: &$lastError)
        
        // 监听处理器的加载状态
        Publishers.CombineLatest4(
            proxyHandler.$isLoading,
            subscriptionHandler.$isLoading,
            systemProxyHandler.$isLoading,
            trafficHandler.$isLoading
        )
        .map { $0 || $1 || $2 || $3 }
        .assign(to: &$isProcessing)
    }
    
    // MARK: - 统一错误清理
    func clearErrors() {
        lastError = nil
        proxyHandler.clearError()
        subscriptionHandler.clearError()
        systemProxyHandler.clearError()
        trafficHandler.clearError()
    }
}
```

### 2. 依赖注入容器

```swift
// MARK: - 处理器依赖注入容器
class HandlerDIContainer {
    
    // MARK: - 单例
    static let shared = HandlerDIContainer()
    
    // MARK: - 仓库依赖
    private let proxyRepository: ProxyRepository
    private let subscriptionRepository: SubscriptionRepository
    private let trafficRepository: TrafficRepository
    
    // MARK: - 服务依赖
    private let networkService: NetworkService
    private let systemProxyService: SystemProxyService
    private let configParser: ConfigParser
    private let pingTester: PingTester
    private let trafficMonitor: TrafficMonitor
    
    private init() {
        // 初始化仓库
        self.proxyRepository = ProxyRepositoryImpl()
        self.subscriptionRepository = SubscriptionRepositoryImpl()
        self.trafficRepository = TrafficRepositoryImpl()
        
        // 初始化服务
        self.networkService = NetworkServiceImpl()
        self.systemProxyService = SystemProxyServiceImpl()
        self.configParser = ConfigParserImpl()
        self.pingTester = PingTesterImpl()
        self.trafficMonitor = TrafficMonitorImpl()
    }
    
    // MARK: - 处理器工厂方法
    func makeProxyHandler() -> ProxyHandler {
        return ProxyHandler(
            proxyRepository: proxyRepository,
            networkService: networkService,
            systemProxyService: systemProxyService,
            configParser: configParser,
            pingTester: pingTester
        )
    }
    
    func makeSubscriptionHandler() -> SubscriptionHandler {
        return SubscriptionHandler(
            subscriptionRepository: subscriptionRepository,
            proxyRepository: proxyRepository,
            networkService: networkService,
            configParser: configParser
        )
    }
    
    func makeSystemProxyHandler() -> SystemProxyHandler {
        return SystemProxyHandler(
            systemProxyService: systemProxyService,
            proxyRepository: proxyRepository
        )
    }
    
    func makeTrafficHandler() -> TrafficHandler {
        return TrafficHandler(
            trafficMonitor: trafficMonitor,
            trafficRepository: trafficRepository
        )
    }
    
    func makeHandlerManager() -> HandlerManager {
        return HandlerManager(
            proxyHandler: makeProxyHandler(),
            subscriptionHandler: makeSubscriptionHandler(),
            systemProxyHandler: makeSystemProxyHandler(),
            trafficHandler: makeTrafficHandler()
        )
    }
}
```

## 🧪 测试支持

### 1. 处理器测试基类

```swift
// MARK: - 处理器测试基类
class HandlerTestCase: XCTestCase {
    
    var mockProxyRepository: MockProxyRepository!
    var mockSubscriptionRepository: MockSubscriptionRepository!
    var mockNetworkService: MockNetworkService!
    var mockSystemProxyService: MockSystemProxyService!
    
    override func setUp() {
        super.setUp()
        
        mockProxyRepository = MockProxyRepository()
        mockSubscriptionRepository = MockSubscriptionRepository()
        mockNetworkService = MockNetworkService()
        mockSystemProxyService = MockSystemProxyService()
    }
    
    override func tearDown() {
        mockProxyRepository = nil
        mockSubscriptionRepository = nil
        mockNetworkService = nil
        mockSystemProxyService = nil
        
        super.tearDown()
    }
}

// MARK: - 代理处理器测试
class ProxyHandlerTests: HandlerTestCase {
    
    var proxyHandler: ProxyHandler!
    
    override func setUp() {
        super.setUp()
        
        proxyHandler = ProxyHandler(
            proxyRepository: mockProxyRepository,
            networkService: mockNetworkService,
            systemProxyService: mockSystemProxyService,
            configParser: MockConfigParser(),
            pingTester: MockPingTester()
        )
    }
    
    func testAddProxy() async throws {
        // Given
        let proxy = ProxyConfig.mock()
        
        // When
        let result = await proxyHandler.handle(.addProxy(proxy))
        
        // Then
        XCTAssertNotNil(result)
        if case .proxyAdded(let addedProxy) = result {
            XCTAssertEqual(addedProxy.id, proxy.id)
        } else {
            XCTFail("Expected proxyAdded result")
        }
        
        XCTAssertTrue(mockProxyRepository.saveWasCalled)
    }
    
    func testActivateProxy() async throws {
        // Given
        let proxy = ProxyConfig.mock()
        mockProxyRepository.fetchResult = proxy
        
        // When
        let result = await proxyHandler.handle(.activateProxy(proxy.id))
        
        // Then
        XCTAssertNotNil(result)
        if case .proxyActivated(let activatedProxy) = result {
            XCTAssertEqual(activatedProxy.id, proxy.id)
        } else {
            XCTFail("Expected proxyActivated result")
        }
        
        XCTAssertTrue(mockSystemProxyService.setProxyWasCalled)
        XCTAssertTrue(mockProxyRepository.setActiveProxyWasCalled)
    }
}
```

## 📚 相关文档

- [应用架构模块](app-architecture.md)
- [数据库层模块](database-layer.md)
- [协议层模块](protocol-layer.md)
- [视图层模块](view-layer.md)
- [基础工具模块](base-utilities.md)

---

*本文档详细介绍了V2rayU处理器层的设计与实现，为开发者提供了完整的业务逻辑处理解决方案。*
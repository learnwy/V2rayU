# 订阅同步功能详解

## 📋 概述

订阅同步是V2rayU的重要功能之一，允许用户通过订阅URL自动获取和更新代理配置。该功能支持多种订阅格式，提供自动更新机制，并能智能处理配置变更，大大简化了代理配置的管理工作。

## 🎯 功能特性

### 1. 支持的订阅格式
- **Base64编码**: 标准的Base64编码代理列表
- **原始文本**: 直接的代理URL列表
- **JSON格式**: 结构化的代理配置
- **Clash配置**: Clash格式的YAML配置
- **V2Ray配置**: V2Ray原生JSON配置

### 2. 核心功能
- ✅ 添加/编辑/删除订阅源
- ✅ 手动/自动同步订阅
- ✅ 订阅内容解析和验证
- ✅ 增量更新和全量替换
- ✅ 订阅分组和标签管理
- ✅ 同步历史和错误记录
- ✅ 自定义更新间隔
- ✅ 网络代理支持

## 🏗️ 架构设计

### 1. 组件关系图

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│SubscriptionView │────│SubscriptionHandler│──│SubscriptionRepo │
│   (UI Layer)    │    │ (Business Logic)│    │  (Data Layer)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│SubscriptionEdit │    │ NetworkService  │    │ DatabaseManager │
│ SubscriptionRow │    │ ConfigParser    │    │   GRDB.swift    │
│ SyncStatusView  │    │ SyncScheduler   │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 2. 数据流向

```
Subscription URL → NetworkService → ConfigParser → ProxyRepository
       ↓               ↓              ↓               ↓
   UI Update ← SubscriptionHandler ← Parsed Configs ← Database
```

## 💻 核心实现

### 1. 订阅配置模型

```swift
// MARK: - 订阅配置模型
struct SubscriptionConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: String
    var isEnabled: Bool
    var autoUpdate: Bool
    var updateInterval: TimeInterval // 秒
    var lastUpdateTime: Date?
    var lastSyncTime: Date?
    var proxyCount: Int
    var createdAt: Date
    var updatedAt: Date
    
    // 同步设置
    var replaceExisting: Bool // 是否替换现有代理
    var groupName: String? // 分组名称
    var tags: [String] // 标签
    
    // 网络设置
    var useProxy: Bool // 是否使用代理下载
    var timeout: TimeInterval // 超时时间
    var userAgent: String? // 自定义User-Agent
    var headers: [String: String] // 自定义请求头
    
    // 统计信息
    var totalSyncs: Int
    var successfulSyncs: Int
    var lastError: String?
    var lastErrorTime: Date?
    
    init(
        name: String,
        url: String
    ) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.isEnabled = true
        self.autoUpdate = true
        self.updateInterval = 3600 // 1小时
        self.proxyCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.replaceExisting = false
        self.tags = []
        self.useProxy = false
        self.timeout = 30
        self.headers = [:]
        self.totalSyncs = 0
        self.successfulSyncs = 0
    }
}

// MARK: - 同步状态
enum SyncStatus {
    case idle
    case syncing
    case success(Date)
    case failed(Error, Date)
    
    var isLoading: Bool {
        if case .syncing = self {
            return true
        }
        return false
    }
    
    var lastUpdateTime: Date? {
        switch self {
        case .success(let date), .failed(_, let date):
            return date
        default:
            return nil
        }
    }
}

// MARK: - 同步结果
struct SyncResult {
    let subscriptionId: UUID
    let success: Bool
    let addedCount: Int
    let updatedCount: Int
    let removedCount: Int
    let totalCount: Int
    let error: Error?
    let syncTime: Date
    let duration: TimeInterval
    
    init(
        subscriptionId: UUID,
        success: Bool,
        addedCount: Int = 0,
        updatedCount: Int = 0,
        removedCount: Int = 0,
        totalCount: Int = 0,
        error: Error? = nil,
        syncTime: Date = Date(),
        duration: TimeInterval = 0
    ) {
        self.subscriptionId = subscriptionId
        self.success = success
        self.addedCount = addedCount
        self.updatedCount = updatedCount
        self.removedCount = removedCount
        self.totalCount = totalCount
        self.error = error
        self.syncTime = syncTime
        self.duration = duration
    }
}
```

### 2. 订阅处理器实现

```swift
// MARK: - 订阅处理器
@MainActor
class SubscriptionHandler: AsyncHandler {
    private let repository: SubscriptionRepositoryProtocol
    private let proxyRepository: ProxyRepositoryProtocol
    private let networkService: NetworkServiceProtocol
    private let configParser: ConfigParserProtocol
    private let syncScheduler: SyncScheduler
    
    @Published var subscriptions: [SubscriptionConfig] = []
    @Published var syncStatuses: [UUID: SyncStatus] = [:]
    @Published var isAutoSyncEnabled = true
    
    init(
        repository: SubscriptionRepositoryProtocol,
        proxyRepository: ProxyRepositoryProtocol,
        networkService: NetworkServiceProtocol,
        configParser: ConfigParserProtocol,
        syncScheduler: SyncScheduler
    ) {
        self.repository = repository
        self.proxyRepository = proxyRepository
        self.networkService = networkService
        self.configParser = configParser
        self.syncScheduler = syncScheduler
        super.init()
        
        setupAutoSync()
    }
    
    // MARK: - 公共方法
    
    /// 加载所有订阅
    func loadSubscriptions() async {
        await performAsyncOperation {
            let allSubscriptions = try await self.repository.getAllSubscriptions()
            await MainActor.run {
                self.subscriptions = allSubscriptions
                
                // 初始化同步状态
                for subscription in allSubscriptions {
                    if self.syncStatuses[subscription.id] == nil {
                        if let lastError = subscription.lastError {
                            let error = SubscriptionError.syncFailed(lastError)
                            self.syncStatuses[subscription.id] = .failed(
                                error,
                                subscription.lastErrorTime ?? Date()
                            )
                        } else if let lastSync = subscription.lastSyncTime {
                            self.syncStatuses[subscription.id] = .success(lastSync)
                        } else {
                            self.syncStatuses[subscription.id] = .idle
                        }
                    }
                }
            }
        }
    }
    
    /// 添加订阅
    func addSubscription(_ subscription: SubscriptionConfig) async {
        await performAsyncOperation {
            // 验证订阅配置
            try self.validateSubscription(subscription)
            
            // 保存到数据库
            try await self.repository.addSubscription(subscription)
            
            // 更新本地列表
            await MainActor.run {
                self.subscriptions.append(subscription)
                self.syncStatuses[subscription.id] = .idle
            }
            
            // 如果启用了自动更新，添加到调度器
            if subscription.autoUpdate {
                self.syncScheduler.scheduleSubscription(subscription)
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .subscriptionAdded,
                object: subscription
            )
            
            self.logger.info("订阅添加成功: \(subscription.name)")
        }
    }
    
    /// 更新订阅
    func updateSubscription(_ subscription: SubscriptionConfig) async {
        await performAsyncOperation {
            // 验证订阅配置
            try self.validateSubscription(subscription)
            
            // 更新数据库
            var updatedSubscription = subscription
            updatedSubscription.updatedAt = Date()
            try await self.repository.updateSubscription(updatedSubscription)
            
            // 更新本地列表
            await MainActor.run {
                if let index = self.subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                    self.subscriptions[index] = updatedSubscription
                }
            }
            
            // 更新调度器
            if updatedSubscription.autoUpdate {
                self.syncScheduler.scheduleSubscription(updatedSubscription)
            } else {
                self.syncScheduler.unscheduleSubscription(updatedSubscription.id)
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .subscriptionUpdated,
                object: updatedSubscription
            )
            
            self.logger.info("订阅更新成功: \(subscription.name)")
        }
    }
    
    /// 删除订阅
    func deleteSubscription(_ subscription: SubscriptionConfig) async {
        await performAsyncOperation {
            // 从调度器移除
            self.syncScheduler.unscheduleSubscription(subscription.id)
            
            // 删除相关的代理配置（如果需要）
            let relatedProxies = try await self.proxyRepository.getProxiesBySubscription(subscription.id)
            for proxy in relatedProxies {
                try await self.proxyRepository.deleteProxy(proxy.id)
            }
            
            // 从数据库删除
            try await self.repository.deleteSubscription(subscription.id)
            
            // 更新本地列表
            await MainActor.run {
                self.subscriptions.removeAll { $0.id == subscription.id }
                self.syncStatuses.removeValue(forKey: subscription.id)
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .subscriptionDeleted,
                object: subscription
            )
            
            self.logger.info("订阅删除成功: \(subscription.name)")
        }
    }
    
    /// 同步单个订阅
    func syncSubscription(_ subscription: SubscriptionConfig) async {
        let startTime = Date()
        
        // 更新同步状态
        await MainActor.run {
            self.syncStatuses[subscription.id] = .syncing
        }
        
        do {
            self.logger.info("开始同步订阅: \(subscription.name)")
            
            // 下载订阅内容
            let content = try await downloadSubscriptionContent(subscription)
            
            // 解析代理配置
            let newProxies = try configParser.parseSubscriptionContent(content)
            
            self.logger.info("解析到 \(newProxies.count) 个代理配置")
            
            // 更新代理配置
            let result = try await updateProxyConfigs(
                subscription: subscription,
                newProxies: newProxies
            )
            
            // 更新订阅信息
            var updatedSubscription = subscription
            updatedSubscription.lastSyncTime = Date()
            updatedSubscription.lastUpdateTime = Date()
            updatedSubscription.proxyCount = result.totalCount
            updatedSubscription.totalSyncs += 1
            updatedSubscription.successfulSyncs += 1
            updatedSubscription.lastError = nil
            updatedSubscription.lastErrorTime = nil
            
            try await repository.updateSubscription(updatedSubscription)
            
            // 更新本地状态
            await MainActor.run {
                if let index = self.subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                    self.subscriptions[index] = updatedSubscription
                }
                self.syncStatuses[subscription.id] = .success(Date())
            }
            
            let duration = Date().timeIntervalSince(startTime)
            let finalResult = SyncResult(
                subscriptionId: subscription.id,
                success: true,
                addedCount: result.addedCount,
                updatedCount: result.updatedCount,
                removedCount: result.removedCount,
                totalCount: result.totalCount,
                syncTime: Date(),
                duration: duration
            )
            
            // 发送通知
            NotificationCenter.default.post(
                name: .subscriptionSynced,
                object: finalResult
            )
            
            self.logger.info("订阅同步成功: \(subscription.name), 耗时: \(String(format: "%.2f", duration))s")
            
        } catch {
            // 更新错误信息
            var updatedSubscription = subscription
            updatedSubscription.lastError = error.localizedDescription
            updatedSubscription.lastErrorTime = Date()
            updatedSubscription.totalSyncs += 1
            
            try? await repository.updateSubscription(updatedSubscription)
            
            // 更新本地状态
            await MainActor.run {
                if let index = self.subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                    self.subscriptions[index] = updatedSubscription
                }
                self.syncStatuses[subscription.id] = .failed(error, Date())
            }
            
            let duration = Date().timeIntervalSince(startTime)
            let failedResult = SyncResult(
                subscriptionId: subscription.id,
                success: false,
                error: error,
                syncTime: Date(),
                duration: duration
            )
            
            // 发送通知
            NotificationCenter.default.post(
                name: .subscriptionSyncFailed,
                object: failedResult
            )
            
            self.logger.error("订阅同步失败: \(subscription.name) - \(error)")
        }
    }
    
    /// 同步所有订阅
    func syncAllSubscriptions() async {
        let enabledSubscriptions = subscriptions.filter { $0.isEnabled }
        
        self.logger.info("开始同步所有订阅，共 \(enabledSubscriptions.count) 个")
        
        // 并发同步，但限制并发数
        await withTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore(value: 3) // 最多3个并发
            
            for subscription in enabledSubscriptions {
                group.addTask {
                    await semaphore.wait()
                    defer { semaphore.signal() }
                    
                    await self.syncSubscription(subscription)
                }
            }
        }
        
        self.logger.info("所有订阅同步完成")
    }
    
    /// 切换订阅启用状态
    func toggleSubscription(_ subscription: SubscriptionConfig) async {
        await performAsyncOperation {
            var updatedSubscription = subscription
            updatedSubscription.isEnabled.toggle()
            updatedSubscription.updatedAt = Date()
            
            try await self.repository.updateSubscription(updatedSubscription)
            
            // 更新本地列表
            await MainActor.run {
                if let index = self.subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                    self.subscriptions[index] = updatedSubscription
                }
            }
            
            // 更新调度器
            if updatedSubscription.isEnabled && updatedSubscription.autoUpdate {
                self.syncScheduler.scheduleSubscription(updatedSubscription)
            } else {
                self.syncScheduler.unscheduleSubscription(updatedSubscription.id)
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .subscriptionToggled,
                object: updatedSubscription
            )
            
            self.logger.info("订阅状态切换: \(subscription.name) -> \(updatedSubscription.isEnabled ? "启用" : "禁用")")
        }
    }
    
    /// 设置自动更新
    func setAutoUpdate(_ subscription: SubscriptionConfig, enabled: Bool) async {
        await performAsyncOperation {
            var updatedSubscription = subscription
            updatedSubscription.autoUpdate = enabled
            updatedSubscription.updatedAt = Date()
            
            try await self.repository.updateSubscription(updatedSubscription)
            
            // 更新本地列表
            await MainActor.run {
                if let index = self.subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                    self.subscriptions[index] = updatedSubscription
                }
            }
            
            // 更新调度器
            if enabled && updatedSubscription.isEnabled {
                self.syncScheduler.scheduleSubscription(updatedSubscription)
            } else {
                self.syncScheduler.unscheduleSubscription(updatedSubscription.id)
            }
            
            self.logger.info("订阅自动更新设置: \(subscription.name) -> \(enabled ? "启用" : "禁用")")
        }
    }
    
    // MARK: - 私有方法
    
    private func setupAutoSync() {
        // 设置自动同步调度器
        syncScheduler.onScheduledSync = { [weak self] subscriptionId in
            guard let self = self else { return }
            
            Task {
                if let subscription = await self.subscriptions.first(where: { $0.id == subscriptionId }) {
                    await self.syncSubscription(subscription)
                }
            }
        }
        
        // 启动调度器
        Task {
            await loadSubscriptions()
            
            // 为所有启用自动更新的订阅设置调度
            for subscription in subscriptions {
                if subscription.isEnabled && subscription.autoUpdate {
                    syncScheduler.scheduleSubscription(subscription)
                }
            }
        }
    }
    
    private func downloadSubscriptionContent(_ subscription: SubscriptionConfig) async throws -> String {
        var request = URLRequest(url: URL(string: subscription.url)!)
        request.timeoutInterval = subscription.timeout
        
        // 设置自定义请求头
        if let userAgent = subscription.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        
        for (key, value) in subscription.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 使用网络服务下载
        let content = try await networkService.downloadString(from: request)
        
        guard !content.isEmpty else {
            throw SubscriptionError.emptyContent
        }
        
        return content
    }
    
    private func updateProxyConfigs(
        subscription: SubscriptionConfig,
        newProxies: [ProxyConfig]
    ) async throws -> SyncResult {
        var addedCount = 0
        var updatedCount = 0
        var removedCount = 0
        
        if subscription.replaceExisting {
            // 全量替换模式
            let existingProxies = try await proxyRepository.getProxiesBySubscription(subscription.id)
            
            // 删除现有代理
            for proxy in existingProxies {
                try await proxyRepository.deleteProxy(proxy.id)
                removedCount += 1
            }
            
            // 添加新代理
            for var proxy in newProxies {
                proxy.subscriptionId = subscription.id
                if let groupName = subscription.groupName {
                    proxy.name = "[\(groupName)] \(proxy.name)"
                }
                
                try await proxyRepository.addProxy(proxy)
                addedCount += 1
            }
        } else {
            // 增量更新模式
            let existingProxies = try await proxyRepository.getProxiesBySubscription(subscription.id)
            let existingProxyMap = Dictionary(uniqueKeysWithValues: existingProxies.map { ($0.serverAddress + ":\($0.serverPort)", $0) })
            
            for var newProxy in newProxies {
                newProxy.subscriptionId = subscription.id
                if let groupName = subscription.groupName {
                    newProxy.name = "[\(groupName)] \(newProxy.name)"
                }
                
                let key = newProxy.serverAddress + ":\(newProxy.serverPort)"
                
                if let existingProxy = existingProxyMap[key] {
                    // 更新现有代理
                    newProxy.id = existingProxy.id
                    newProxy.createdAt = existingProxy.createdAt
                    newProxy.totalUsage = existingProxy.totalUsage
                    newProxy.lastUsedAt = existingProxy.lastUsedAt
                    
                    try await proxyRepository.updateProxy(newProxy)
                    updatedCount += 1
                } else {
                    // 添加新代理
                    try await proxyRepository.addProxy(newProxy)
                    addedCount += 1
                }
            }
        }
        
        return SyncResult(
            subscriptionId: subscription.id,
            success: true,
            addedCount: addedCount,
            updatedCount: updatedCount,
            removedCount: removedCount,
            totalCount: newProxies.count
        )
    }
    
    private func validateSubscription(_ subscription: SubscriptionConfig) throws {
        guard !subscription.name.isEmpty else {
            throw SubscriptionError.invalidName
        }
        
        guard let url = URL(string: subscription.url), url.scheme != nil else {
            throw SubscriptionError.invalidURL
        }
        
        guard subscription.updateInterval >= 60 else {
            throw SubscriptionError.invalidUpdateInterval
        }
        
        guard subscription.timeout > 0 && subscription.timeout <= 300 else {
            throw SubscriptionError.invalidTimeout
        }
    }
}

// MARK: - 同步调度器
class SyncScheduler {
    private var scheduledTasks: [UUID: Task<Void, Never>] = [:]
    private let queue = DispatchQueue(label: "sync.scheduler", qos: .background)
    
    var onScheduledSync: ((UUID) -> Void)?
    
    func scheduleSubscription(_ subscription: SubscriptionConfig) {
        unscheduleSubscription(subscription.id)
        
        let task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(subscription.updateInterval * 1_000_000_000))
                
                if !Task.isCancelled {
                    onScheduledSync?(subscription.id)
                }
            }
        }
        
        scheduledTasks[subscription.id] = task
    }
    
    func unscheduleSubscription(_ subscriptionId: UUID) {
        scheduledTasks[subscriptionId]?.cancel()
        scheduledTasks.removeValue(forKey: subscriptionId)
    }
    
    func unscheduleAll() {
        for task in scheduledTasks.values {
            task.cancel()
        }
        scheduledTasks.removeAll()
    }
}

// MARK: - 异步信号量
actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        if value > 0 {
            value -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }
    
    func signal() {
        if waiters.isEmpty {
            value += 1
        } else {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
}

// MARK: - 订阅错误
enum SubscriptionError: LocalizedError {
    case invalidName
    case invalidURL
    case invalidUpdateInterval
    case invalidTimeout
    case emptyContent
    case parseError(String)
    case networkError(Error)
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "订阅名称不能为空"
        case .invalidURL:
            return "订阅URL格式无效"
        case .invalidUpdateInterval:
            return "更新间隔必须大于等于60秒"
        case .invalidTimeout:
            return "超时时间必须在1-300秒之间"
        case .emptyContent:
            return "订阅内容为空"
        case .parseError(let message):
            return "解析错误: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .syncFailed(let message):
            return "同步失败: \(message)"
        }
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let subscriptionAdded = Notification.Name("subscriptionAdded")
    static let subscriptionUpdated = Notification.Name("subscriptionUpdated")
    static let subscriptionDeleted = Notification.Name("subscriptionDeleted")
    static let subscriptionToggled = Notification.Name("subscriptionToggled")
    static let subscriptionSynced = Notification.Name("subscriptionSynced")
    static let subscriptionSyncFailed = Notification.Name("subscriptionSyncFailed")
}
```

### 3. 用户界面实现

```swift
// MARK: - 订阅列表视图
struct SubscriptionListView: View {
    @StateObject private var handler = HandlerManager.shared.subscriptionHandler
    @State private var showingAddSubscription = false
    @State private var selectedSubscriptions: Set<SubscriptionConfig.ID> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            SubscriptionToolbarView(
                showingAddSubscription: $showingAddSubscription,
                selectedSubscriptions: $selectedSubscriptions,
                handler: handler
            )
            
            // 订阅列表
            if handler.subscriptions.isEmpty {
                SubscriptionEmptyView()
            } else {
                SubscriptionTableView(
                    subscriptions: handler.subscriptions,
                    syncStatuses: handler.syncStatuses,
                    selectedSubscriptions: $selectedSubscriptions,
                    handler: handler
                )
            }
        }
        .sheet(isPresented: $showingAddSubscription) {
            SubscriptionEditView(handler: handler)
        }
        .task {
            await handler.loadSubscriptions()
        }
    }
}

// MARK: - 订阅工具栏
struct SubscriptionToolbarView: View {
    @Binding var showingAddSubscription: Bool
    @Binding var selectedSubscriptions: Set<SubscriptionConfig.ID>
    let handler: SubscriptionHandler
    
    var body: some View {
        HStack {
            // 添加按钮
            Button("添加订阅") {
                showingAddSubscription = true
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
            
            // 同步按钮
            Button("同步全部") {
                Task {
                    await handler.syncAllSubscriptions()
                }
            }
            .disabled(handler.isLoading)
            
            // 删除按钮
            Button("删除") {
                deleteSelectedSubscriptions()
            }
            .disabled(selectedSubscriptions.isEmpty)
            .foregroundColor(.red)
        }
        .padding()
    }
    
    private func deleteSelectedSubscriptions() {
        let subscriptionsToDelete = handler.subscriptions.filter { selectedSubscriptions.contains($0.id) }
        
        Task {
            for subscription in subscriptionsToDelete {
                await handler.deleteSubscription(subscription)
            }
            selectedSubscriptions.removeAll()
        }
    }
}

// MARK: - 订阅表格视图
struct SubscriptionTableView: View {
    let subscriptions: [SubscriptionConfig]
    let syncStatuses: [UUID: SyncStatus]
    @Binding var selectedSubscriptions: Set<SubscriptionConfig.ID>
    let handler: SubscriptionHandler
    
    var body: some View {
        Table(subscriptions, selection: $selectedSubscriptions) {
            TableColumn("状态", value: \.isEnabled) { subscription in
                HStack {
                    // 启用状态
                    Image(systemName: subscription.isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundColor(subscription.isEnabled ? .green : .gray)
                    
                    // 同步状态
                    SyncStatusIndicator(status: syncStatuses[subscription.id] ?? .idle)
                }
            }
            .width(80)
            
            TableColumn("名称", value: \.name) { subscription in
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.name)
                        .font(.system(.body, design: .default))
                    
                    if let groupName = subscription.groupName {
                        Text(groupName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .width(min: 150, ideal: 200, max: 300)
            
            TableColumn("URL", value: \.url) { subscription in
                Text(subscription.url)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 200, ideal: 300, max: 400)
            
            TableColumn("代理数量", value: \.proxyCount) { subscription in
                Text("\(subscription.proxyCount)")
                    .font(.system(.body, design: .monospaced))
            }
            .width(80)
            
            TableColumn("自动更新", value: \.autoUpdate) { subscription in
                HStack {
                    Image(systemName: subscription.autoUpdate ? "arrow.clockwise" : "pause")
                        .foregroundColor(subscription.autoUpdate ? .blue : .gray)
                    
                    if subscription.autoUpdate {
                        Text(formatUpdateInterval(subscription.updateInterval))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .width(100)
            
            TableColumn("最后同步", value: \.lastSyncTime) { subscription in
                if let lastSync = subscription.lastSyncTime {
                    Text(formatRelativeTime(lastSync))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("从未同步")
                        .font(.caption)
                        .foregroundColor(.tertiary)
                }
            }
            .width(100)
            
            TableColumn("操作") { subscription in
                SubscriptionActionButtons(subscription: subscription, handler: handler)
            }
            .width(120)
        }
        .contextMenu(forSelectionType: SubscriptionConfig.ID.self) { selection in
            if selection.count == 1,
               let subscriptionId = selection.first,
               let subscription = subscriptions.first(where: { $0.id == subscriptionId }) {
                
                Button(subscription.isEnabled ? "禁用" : "启用") {
                    Task {
                        await handler.toggleSubscription(subscription)
                    }
                }
                
                Button("立即同步") {
                    Task {
                        await handler.syncSubscription(subscription)
                    }
                }
                
                Divider()
                
                Button("删除") {
                    Task {
                        await handler.deleteSubscription(subscription)
                    }
                }
                .foregroundColor(.red)
            }
        }
    }
    
    private func formatUpdateInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        if hours >= 24 {
            return "\(hours / 24)天"
        } else if hours > 0 {
            return "\(hours)小时"
        } else {
            return "\(Int(interval) / 60)分钟"
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 同步状态指示器
struct SyncStatusIndicator: View {
    let status: SyncStatus
    
    var body: some View {
        Group {
            switch status {
            case .idle:
                Image(systemName: "circle")
                    .foregroundColor(.gray)
                
            case .syncing:
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: status.isLoading)
                
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.caption)
    }
}

// MARK: - 订阅操作按钮
struct SubscriptionActionButtons: View {
    let subscription: SubscriptionConfig
    let handler: SubscriptionHandler
    
    var body: some View {
        HStack(spacing: 4) {
            // 启用/禁用按钮
            Button(action: {
                Task {
                    await handler.toggleSubscription(subscription)
                }
            }) {
                Image(systemName: subscription.isEnabled ? "pause.circle" : "play.circle")
            }
            .buttonStyle(.plain)
            .foregroundColor(subscription.isEnabled ? .orange : .green)
            
            // 同步按钮
            Button(action: {
                Task {
                    await handler.syncSubscription(subscription)
                }
            }) {
                Image(systemName: "arrow.clockwise")
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

### 1. 添加订阅

```swift
let subscription = SubscriptionConfig(
    name: "机场订阅",
    url: "https://example.com/subscribe?token=abc123"
)
subscription.autoUpdate = true
subscription.updateInterval = 3600 // 1小时
subscription.groupName = "机场A"

await subscriptionHandler.addSubscription(subscription)
```

### 2. 手动同步订阅

```swift
// 同步单个订阅
await subscriptionHandler.syncSubscription(subscription)

// 同步所有订阅
await subscriptionHandler.syncAllSubscriptions()
```

### 3. 设置自动更新

```swift
// 启用自动更新
await subscriptionHandler.setAutoUpdate(subscription, enabled: true)

// 禁用自动更新
await subscriptionHandler.setAutoUpdate(subscription, enabled: false)
```

## 📚 相关文档

- [代理管理功能](proxy-management.md)
- [协议层模块](../modules/protocol-layer.md)
- [网络服务工具](../modules/base-utilities.md)
- [数据库层模块](../modules/database-layer.md)
- [配置解析功能](../files/utility-files.md)

---

*本文档详细介绍了V2rayU订阅同步功能的设计与实现，为开发者提供了完整的订阅管理解决方案。*
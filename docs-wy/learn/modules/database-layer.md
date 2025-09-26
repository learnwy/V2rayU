# 数据库层模块详解

## 📋 概述

数据库层模块是V2rayU数据持久化的核心，采用GRDB.swift作为SQLite数据库的ORM框架。本模块负责所有数据的存储、查询、更新和删除操作，为上层业务逻辑提供可靠的数据服务。

## 🗄️ 数据库架构

### 1. 数据库管理器

```swift
// MARK: - 数据库管理器
class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var dbQueue: DatabaseQueue?
    private let dbPath: String
    
    private init() {
        // 获取应用支持目录
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("V2rayU")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appDirectory,
                                                withIntermediateDirectories: true)
        
        // 数据库文件路径
        dbPath = appDirectory.appendingPathComponent("v2rayu.db").path
        
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            dbQueue = try DatabaseQueue(path: dbPath)
            try migrator.migrate(dbQueue!)
        } catch {
            fatalError("Failed to setup database: \(error)")
        }
    }
    
    // MARK: - 数据库操作
    func read<T>(_ operation: @escaping (Database) throws -> T) async throws -> T {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notInitialized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            dbQueue.asyncRead { result in
                switch result {
                case .success(let db):
                    do {
                        let value = try operation(db)
                        continuation.resume(returning: value)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func write<T>(_ operation: @escaping (Database) throws -> T) async throws -> T {
        guard let dbQueue = dbQueue else {
            throw DatabaseError.notInitialized
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            dbQueue.asyncWrite { result in
                switch result {
                case .success(let db):
                    do {
                        let value = try operation(db)
                        continuation.resume(returning: value)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - 事务操作
    func transaction<T>(_ operation: @escaping (Database) throws -> T) async throws -> T {
        return try await write { db in
            try db.inTransaction {
                return try operation(db)
            }
        }
    }
}

// MARK: - 数据库错误
enum DatabaseError: Error, LocalizedError {
    case notInitialized
    case migrationFailed(Error)
    case queryFailed(Error)
    case insertFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "数据库未初始化"
        case .migrationFailed(let error):
            return "数据库迁移失败: \(error.localizedDescription)"
        case .queryFailed(let error):
            return "查询失败: \(error.localizedDescription)"
        case .insertFailed(let error):
            return "插入失败: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "更新失败: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "删除失败: \(error.localizedDescription)"
        }
    }
}
```

### 2. 数据库迁移

```swift
// MARK: - 数据库迁移器
var migrator: DatabaseMigrator {
    var migrator = DatabaseMigrator()
    
    // 版本1: 初始数据库结构
    migrator.registerMigration("v1.0") { db in
        // 代理配置表
        try db.create(table: "proxy_configs") { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("protocol_type", .text).notNull()
            t.column("server_address", .text).notNull()
            t.column("server_port", .integer).notNull()
            t.column("user_id", .text)
            t.column("alter_id", .integer)
            t.column("security", .text)
            t.column("network", .text)
            t.column("path", .text)
            t.column("host", .text)
            t.column("tls", .text)
            t.column("password", .text)
            t.column("method", .text)
            t.column("plugin", .text)
            t.column("plugin_opts", .text)
            t.column("is_active", .boolean).notNull().defaults(to: false)
            t.column("subscription_id", .text)
            t.column("created_at", .datetime).notNull()
            t.column("updated_at", .datetime).notNull()
        }
        
        // 订阅表
        try db.create(table: "subscriptions") { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("url", .text).notNull()
            t.column("is_enabled", .boolean).notNull().defaults(to: true)
            t.column("auto_update", .boolean).notNull().defaults(to: false)
            t.column("update_interval", .integer).notNull().defaults(to: 24)
            t.column("last_update_time", .datetime)
            t.column("proxy_count", .integer).notNull().defaults(to: 0)
            t.column("created_at", .datetime).notNull()
            t.column("updated_at", .datetime).notNull()
        }
        
        // 流量统计表
        try db.create(table: "traffic_stats") { t in
            t.column("id", .text).primaryKey()
            t.column("proxy_id", .text).notNull()
            t.column("upload_bytes", .integer).notNull().defaults(to: 0)
            t.column("download_bytes", .integer).notNull().defaults(to: 0)
            t.column("total_bytes", .integer).notNull().defaults(to: 0)
            t.column("session_start", .datetime).notNull()
            t.column("session_end", .datetime)
            t.column("created_at", .datetime).notNull()
        }
        
        // 延迟测试记录表
        try db.create(table: "ping_records") { t in
            t.column("id", .text).primaryKey()
            t.column("proxy_id", .text).notNull()
            t.column("latency", .double)
            t.column("is_success", .boolean).notNull()
            t.column("error_message", .text)
            t.column("test_time", .datetime).notNull()
        }
        
        // 应用设置表
        try db.create(table: "app_settings") { t in
            t.column("key", .text).primaryKey()
            t.column("value", .text)
            t.column("type", .text).notNull()
            t.column("updated_at", .datetime).notNull()
        }
        
        // 创建索引
        try db.create(index: "idx_proxy_configs_subscription_id",
                     on: "proxy_configs",
                     columns: ["subscription_id"])
        try db.create(index: "idx_traffic_stats_proxy_id",
                     on: "traffic_stats",
                     columns: ["proxy_id"])
        try db.create(index: "idx_ping_records_proxy_id",
                     on: "ping_records",
                     columns: ["proxy_id"])
    }
    
    // 版本1.1: 添加路由规则表
    migrator.registerMigration("v1.1") { db in
        try db.create(table: "routing_rules") { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("type", .text).notNull() // domain, ip, geoip, geosite
            t.column("pattern", .text).notNull()
            t.column("outbound", .text).notNull() // proxy, direct, block
            t.column("priority", .integer).notNull().defaults(to: 0)
            t.column("is_enabled", .boolean).notNull().defaults(to: true)
            t.column("created_at", .datetime).notNull()
            t.column("updated_at", .datetime).notNull()
        }
        
        try db.create(index: "idx_routing_rules_priority",
                     on: "routing_rules",
                     columns: ["priority"])
    }
    
    // 版本1.2: 添加日志表
    migrator.registerMigration("v1.2") { db in
        try db.create(table: "app_logs") { t in
            t.column("id", .text).primaryKey()
            t.column("level", .text).notNull()
            t.column("category", .text).notNull()
            t.column("message", .text).notNull()
            t.column("metadata", .text) // JSON格式的元数据
            t.column("timestamp", .datetime).notNull()
        }
        
        try db.create(index: "idx_app_logs_timestamp",
                     on: "app_logs",
                     columns: ["timestamp"])
        try db.create(index: "idx_app_logs_level",
                     on: "app_logs",
                     columns: ["level"])
    }
    
    return migrator
}
```

## 📊 数据模型

### 1. 代理配置模型

```swift
// MARK: - 代理配置模型
struct ProxyConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var protocolType: ProxyProtocol
    var serverAddress: String
    var serverPort: Int
    
    // VMess/VLess 特有字段
    var userId: String?
    var alterId: Int?
    var security: String?
    var network: String?
    var path: String?
    var host: String?
    var tls: String?
    
    // Shadowsocks 特有字段
    var password: String?
    var method: String?
    var plugin: String?
    var pluginOpts: String?
    
    // 通用字段
    var isActive: Bool
    var subscriptionId: UUID?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        name: String,
        protocolType: ProxyProtocol,
        serverAddress: String,
        serverPort: Int
    ) {
        self.id = UUID()
        self.name = name
        self.protocolType = protocolType
        self.serverAddress = serverAddress
        self.serverPort = serverPort
        self.isActive = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - GRDB 支持
extension ProxyConfig: FetchableRecord, PersistableRecord {
    static let databaseTableName = "proxy_configs"
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let protocolType = Column(CodingKeys.protocolType)
        static let serverAddress = Column(CodingKeys.serverAddress)
        static let serverPort = Column(CodingKeys.serverPort)
        static let userId = Column(CodingKeys.userId)
        static let alterId = Column(CodingKeys.alterId)
        static let security = Column(CodingKeys.security)
        static let network = Column(CodingKeys.network)
        static let path = Column(CodingKeys.path)
        static let host = Column(CodingKeys.host)
        static let tls = Column(CodingKeys.tls)
        static let password = Column(CodingKeys.password)
        static let method = Column(CodingKeys.method)
        static let plugin = Column(CodingKeys.plugin)
        static let pluginOpts = Column(CodingKeys.pluginOpts)
        static let isActive = Column(CodingKeys.isActive)
        static let subscriptionId = Column(CodingKeys.subscriptionId)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
    
    init(row: Row) {
        id = row[Columns.id]
        name = row[Columns.name]
        protocolType = ProxyProtocol(rawValue: row[Columns.protocolType]) ?? .vmess
        serverAddress = row[Columns.serverAddress]
        serverPort = row[Columns.serverPort]
        userId = row[Columns.userId]
        alterId = row[Columns.alterId]
        security = row[Columns.security]
        network = row[Columns.network]
        path = row[Columns.path]
        host = row[Columns.host]
        tls = row[Columns.tls]
        password = row[Columns.password]
        method = row[Columns.method]
        plugin = row[Columns.plugin]
        pluginOpts = row[Columns.pluginOpts]
        isActive = row[Columns.isActive]
        subscriptionId = row[Columns.subscriptionId]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
    }
    
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.name] = name
        container[Columns.protocolType] = protocolType.rawValue
        container[Columns.serverAddress] = serverAddress
        container[Columns.serverPort] = serverPort
        container[Columns.userId] = userId
        container[Columns.alterId] = alterId
        container[Columns.security] = security
        container[Columns.network] = network
        container[Columns.path] = path
        container[Columns.host] = host
        container[Columns.tls] = tls
        container[Columns.password] = password
        container[Columns.method] = method
        container[Columns.plugin] = plugin
        container[Columns.pluginOpts] = pluginOpts
        container[Columns.isActive] = isActive
        container[Columns.subscriptionId] = subscriptionId
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        // 插入后的回调
    }
}

// MARK: - 查询扩展
extension ProxyConfig {
    // 查询活跃代理
    static func fetchActive(_ db: Database) throws -> ProxyConfig? {
        return try ProxyConfig
            .filter(Columns.isActive == true)
            .fetchOne(db)
    }
    
    // 按订阅查询
    static func fetchBySubscription(_ db: Database, subscriptionId: UUID) throws -> [ProxyConfig] {
        return try ProxyConfig
            .filter(Columns.subscriptionId == subscriptionId)
            .order(Columns.name)
            .fetchAll(db)
    }
    
    // 按协议类型查询
    static func fetchByProtocol(_ db: Database, protocol: ProxyProtocol) throws -> [ProxyConfig] {
        return try ProxyConfig
            .filter(Columns.protocolType == `protocol`.rawValue)
            .order(Columns.name)
            .fetchAll(db)
    }
    
    // 搜索代理
    static func search(_ db: Database, keyword: String) throws -> [ProxyConfig] {
        let pattern = "%\(keyword)%"
        return try ProxyConfig
            .filter(Columns.name.like(pattern) ||
                   Columns.serverAddress.like(pattern))
            .order(Columns.name)
            .fetchAll(db)
    }
}
```

### 2. 订阅模型

```swift
// MARK: - 订阅模型
struct Subscription: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: String
    var isEnabled: Bool
    var autoUpdate: Bool
    var updateInterval: Int // 小时
    var lastUpdateTime: Date?
    var proxyCount: Int
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, url: String) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.isEnabled = true
        self.autoUpdate = false
        self.updateInterval = 24
        self.proxyCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - GRDB 支持
extension Subscription: FetchableRecord, PersistableRecord {
    static let databaseTableName = "subscriptions"
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let url = Column(CodingKeys.url)
        static let isEnabled = Column(CodingKeys.isEnabled)
        static let autoUpdate = Column(CodingKeys.autoUpdate)
        static let updateInterval = Column(CodingKeys.updateInterval)
        static let lastUpdateTime = Column(CodingKeys.lastUpdateTime)
        static let proxyCount = Column(CodingKeys.proxyCount)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
    
    init(row: Row) {
        id = row[Columns.id]
        name = row[Columns.name]
        url = row[Columns.url]
        isEnabled = row[Columns.isEnabled]
        autoUpdate = row[Columns.autoUpdate]
        updateInterval = row[Columns.updateInterval]
        lastUpdateTime = row[Columns.lastUpdateTime]
        proxyCount = row[Columns.proxyCount]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
    }
    
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.name] = name
        container[Columns.url] = url
        container[Columns.isEnabled] = isEnabled
        container[Columns.autoUpdate] = autoUpdate
        container[Columns.updateInterval] = updateInterval
        container[Columns.lastUpdateTime] = lastUpdateTime
        container[Columns.proxyCount] = proxyCount
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
    }
}

// MARK: - 查询扩展
extension Subscription {
    // 查询启用的订阅
    static func fetchEnabled(_ db: Database) throws -> [Subscription] {
        return try Subscription
            .filter(Columns.isEnabled == true)
            .order(Columns.name)
            .fetchAll(db)
    }
    
    // 查询需要自动更新的订阅
    static func fetchAutoUpdate(_ db: Database) throws -> [Subscription] {
        return try Subscription
            .filter(Columns.isEnabled == true && Columns.autoUpdate == true)
            .fetchAll(db)
    }
    
    // 查询过期的订阅
    static func fetchExpired(_ db: Database) throws -> [Subscription] {
        let now = Date()
        return try Subscription
            .filter(Columns.isEnabled == true &&
                   Columns.autoUpdate == true &&
                   (Columns.lastUpdateTime == nil ||
                    Columns.lastUpdateTime < now.addingTimeInterval(-Double(Columns.updateInterval) * 3600)))
            .fetchAll(db)
    }
}
```

### 3. 流量统计模型

```swift
// MARK: - 流量统计模型
struct TrafficStats: Codable, Identifiable {
    let id: UUID
    let proxyId: UUID
    var uploadBytes: Int64
    var downloadBytes: Int64
    var totalBytes: Int64
    let sessionStart: Date
    var sessionEnd: Date?
    let createdAt: Date
    
    init(proxyId: UUID) {
        self.id = UUID()
        self.proxyId = proxyId
        self.uploadBytes = 0
        self.downloadBytes = 0
        self.totalBytes = 0
        self.sessionStart = Date()
        self.createdAt = Date()
    }
    
    mutating func updateTraffic(upload: Int64, download: Int64) {
        uploadBytes += upload
        downloadBytes += download
        totalBytes = uploadBytes + downloadBytes
    }
    
    mutating func endSession() {
        sessionEnd = Date()
    }
}

// MARK: - GRDB 支持
extension TrafficStats: FetchableRecord, PersistableRecord {
    static let databaseTableName = "traffic_stats"
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let proxyId = Column(CodingKeys.proxyId)
        static let uploadBytes = Column(CodingKeys.uploadBytes)
        static let downloadBytes = Column(CodingKeys.downloadBytes)
        static let totalBytes = Column(CodingKeys.totalBytes)
        static let sessionStart = Column(CodingKeys.sessionStart)
        static let sessionEnd = Column(CodingKeys.sessionEnd)
        static let createdAt = Column(CodingKeys.createdAt)
    }
    
    init(row: Row) {
        id = row[Columns.id]
        proxyId = row[Columns.proxyId]
        uploadBytes = row[Columns.uploadBytes]
        downloadBytes = row[Columns.downloadBytes]
        totalBytes = row[Columns.totalBytes]
        sessionStart = row[Columns.sessionStart]
        sessionEnd = row[Columns.sessionEnd]
        createdAt = row[Columns.createdAt]
    }
    
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.proxyId] = proxyId
        container[Columns.uploadBytes] = uploadBytes
        container[Columns.downloadBytes] = downloadBytes
        container[Columns.totalBytes] = totalBytes
        container[Columns.sessionStart] = sessionStart
        container[Columns.sessionEnd] = sessionEnd
        container[Columns.createdAt] = createdAt
    }
}

// MARK: - 查询扩展
extension TrafficStats {
    // 查询代理的总流量
    static func fetchTotalTraffic(_ db: Database, proxyId: UUID) throws -> (upload: Int64, download: Int64, total: Int64) {
        let stats = try TrafficStats
            .filter(Columns.proxyId == proxyId)
            .fetchAll(db)
        
        let totalUpload = stats.reduce(0) { $0 + $1.uploadBytes }
        let totalDownload = stats.reduce(0) { $0 + $1.downloadBytes }
        let total = totalUpload + totalDownload
        
        return (totalUpload, totalDownload, total)
    }
    
    // 查询时间范围内的流量
    static func fetchTrafficInRange(_ db: Database, proxyId: UUID, from: Date, to: Date) throws -> [TrafficStats] {
        return try TrafficStats
            .filter(Columns.proxyId == proxyId &&
                   Columns.sessionStart >= from &&
                   Columns.sessionStart <= to)
            .order(Columns.sessionStart.desc)
            .fetchAll(db)
    }
    
    // 查询活跃会话
    static func fetchActiveSessions(_ db: Database) throws -> [TrafficStats] {
        return try TrafficStats
            .filter(Columns.sessionEnd == nil)
            .fetchAll(db)
    }
}
```

## 🔧 仓库实现

### 1. 代理仓库实现

```swift
// MARK: - 代理仓库实现
class ProxyRepositoryImpl: ProxyRepository {
    private let database: DatabaseManager
    
    init(database: DatabaseManager = DatabaseManager.shared) {
        self.database = database
    }
    
    func save(_ proxy: ProxyConfig) async throws {
        try await database.write { db in
            var mutableProxy = proxy
            mutableProxy.updatedAt = Date()
            try mutableProxy.insert(db)
        }
    }
    
    func fetchAll() async throws -> [ProxyConfig] {
        return try await database.read { db in
            try ProxyConfig
                .order(ProxyConfig.Columns.name)
                .fetchAll(db)
        }
    }
    
    func fetch(by id: UUID) async throws -> ProxyConfig? {
        return try await database.read { db in
            try ProxyConfig.fetchOne(db, key: id)
        }
    }
    
    func update(_ proxy: ProxyConfig) async throws {
        try await database.write { db in
            var mutableProxy = proxy
            mutableProxy.updatedAt = Date()
            try mutableProxy.update(db)
        }
    }
    
    func delete(_ proxy: ProxyConfig) async throws {
        try await database.write { db in
            try proxy.delete(db)
        }
    }
    
    func setActiveProxy(_ proxy: ProxyConfig) async throws {
        try await database.transaction { db in
            // 清除所有活跃状态
            try db.execute(sql: """
                UPDATE proxy_configs 
                SET is_active = 0, updated_at = ?
                """, arguments: [Date()])
            
            // 设置新的活跃代理
            try db.execute(sql: """
                UPDATE proxy_configs 
                SET is_active = 1, updated_at = ? 
                WHERE id = ?
                """, arguments: [Date(), proxy.id])
            
            return ()
        }
    }
    
    func getActiveProxyId() async throws -> UUID? {
        return try await database.read { db in
            try UUID.fetchOne(db, sql: """
                SELECT id FROM proxy_configs 
                WHERE is_active = 1
                """)
        }
    }
    
    func clearActiveProxy() async throws {
        try await database.write { db in
            try db.execute(sql: """
                UPDATE proxy_configs 
                SET is_active = 0, updated_at = ?
                """, arguments: [Date()])
        }
    }
    
    // MARK: - 扩展查询方法
    func fetchBySubscription(_ subscriptionId: UUID) async throws -> [ProxyConfig] {
        return try await database.read { db in
            try ProxyConfig.fetchBySubscription(db, subscriptionId: subscriptionId)
        }
    }
    
    func search(_ keyword: String) async throws -> [ProxyConfig] {
        return try await database.read { db in
            try ProxyConfig.search(db, keyword: keyword)
        }
    }
    
    func fetchByProtocol(_ protocol: ProxyProtocol) async throws -> [ProxyConfig] {
        return try await database.read { db in
            try ProxyConfig.fetchByProtocol(db, protocol: `protocol`)
        }
    }
}
```

### 2. 订阅仓库实现

```swift
// MARK: - 订阅仓库实现
class SubscriptionRepositoryImpl: SubscriptionRepository {
    private let database: DatabaseManager
    
    init(database: DatabaseManager = DatabaseManager.shared) {
        self.database = database
    }
    
    func save(_ subscription: Subscription) async throws {
        try await database.write { db in
            var mutableSubscription = subscription
            mutableSubscription.updatedAt = Date()
            try mutableSubscription.insert(db)
        }
    }
    
    func fetchAll() async throws -> [Subscription] {
        return try await database.read { db in
            try Subscription
                .order(Subscription.Columns.name)
                .fetchAll(db)
        }
    }
    
    func fetch(by id: UUID) async throws -> Subscription? {
        return try await database.read { db in
            try Subscription.fetchOne(db, key: id)
        }
    }
    
    func update(_ subscription: Subscription) async throws {
        try await database.write { db in
            var mutableSubscription = subscription
            mutableSubscription.updatedAt = Date()
            try mutableSubscription.update(db)
        }
    }
    
    func delete(_ subscription: Subscription) async throws {
        try await database.transaction { db in
            // 删除相关的代理配置
            try db.execute(sql: """
                DELETE FROM proxy_configs 
                WHERE subscription_id = ?
                """, arguments: [subscription.id])
            
            // 删除订阅
            try subscription.delete(db)
            
            return ()
        }
    }
    
    func fetchEnabled() async throws -> [Subscription] {
        return try await database.read { db in
            try Subscription.fetchEnabled(db)
        }
    }
    
    func fetchExpired() async throws -> [Subscription] {
        return try await database.read { db in
            try Subscription.fetchExpired(db)
        }
    }
}
```

## 📈 性能优化

### 1. 索引策略

```swift
// 在迁移中创建合适的索引
migrator.registerMigration("performance_indexes") { db in
    // 复合索引
    try db.create(index: "idx_proxy_configs_subscription_active",
                 on: "proxy_configs",
                 columns: ["subscription_id", "is_active"])
    
    // 时间范围查询索引
    try db.create(index: "idx_traffic_stats_proxy_time",
                 on: "traffic_stats",
                 columns: ["proxy_id", "session_start"])
    
    // 搜索优化索引
    try db.create(index: "idx_proxy_configs_name_address",
                 on: "proxy_configs",
                 columns: ["name", "server_address"])
}
```

### 2. 查询优化

```swift
// MARK: - 优化的查询方法
extension ProxyRepositoryImpl {
    // 分页查询
    func fetchPaginated(offset: Int, limit: Int) async throws -> [ProxyConfig] {
        return try await database.read { db in
            try ProxyConfig
                .order(ProxyConfig.Columns.name)
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }
    
    // 批量操作
    func batchInsert(_ proxies: [ProxyConfig]) async throws {
        try await database.write { db in
            for var proxy in proxies {
                proxy.updatedAt = Date()
                try proxy.insert(db)
            }
        }
    }
    
    // 统计查询
    func getProxyCount() async throws -> Int {
        return try await database.read { db in
            try ProxyConfig.fetchCount(db)
        }
    }
    
    func getProxyCountBySubscription(_ subscriptionId: UUID) async throws -> Int {
        return try await database.read { db in
            try ProxyConfig
                .filter(ProxyConfig.Columns.subscriptionId == subscriptionId)
                .fetchCount(db)
        }
    }
}
```

### 3. 缓存策略

```swift
// MARK: - 缓存管理器
class DatabaseCacheManager {
    private var proxyCache: [UUID: ProxyConfig] = [:]
    private var subscriptionCache: [UUID: Subscription] = [:]
    private let cacheQueue = DispatchQueue(label: "database.cache", attributes: .concurrent)
    
    func cacheProxy(_ proxy: ProxyConfig) {
        cacheQueue.async(flags: .barrier) {
            self.proxyCache[proxy.id] = proxy
        }
    }
    
    func getCachedProxy(_ id: UUID) -> ProxyConfig? {
        return cacheQueue.sync {
            return proxyCache[id]
        }
    }
    
    func invalidateProxyCache(_ id: UUID) {
        cacheQueue.async(flags: .barrier) {
            self.proxyCache.removeValue(forKey: id)
        }
    }
    
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.proxyCache.removeAll()
            self.subscriptionCache.removeAll()
        }
    }
}
```

## 🔒 数据安全

### 1. 敏感数据加密

```swift
// MARK: - 敏感数据处理
extension ProxyConfig {
    // 加密敏感字段
    mutating func encryptSensitiveData() throws {
        if let password = password {
            self.password = try EncryptionService.shared.encrypt(password)
        }
        if let userId = userId {
            self.userId = try EncryptionService.shared.encrypt(userId)
        }
    }
    
    // 解密敏感字段
    mutating func decryptSensitiveData() throws {
        if let encryptedPassword = password {
            self.password = try EncryptionService.shared.decrypt(encryptedPassword)
        }
        if let encryptedUserId = userId {
            self.userId = try EncryptionService.shared.decrypt(encryptedUserId)
        }
    }
}
```

### 2. 数据备份与恢复

```swift
// MARK: - 数据备份管理器
class DatabaseBackupManager {
    private let database: DatabaseManager
    private let backupDirectory: URL
    
    init(database: DatabaseManager = DatabaseManager.shared) {
        self.database = database
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask).first!
        self.backupDirectory = appSupport.appendingPathComponent("V2rayU/Backups")
        
        try? FileManager.default.createDirectory(at: backupDirectory,
                                                withIntermediateDirectories: true)
    }
    
    func createBackup() async throws -> URL {
        let timestamp = DateFormatter.backupFormatter.string(from: Date())
        let backupFileName = "v2rayu_backup_\(timestamp).db"
        let backupURL = backupDirectory.appendingPathComponent(backupFileName)
        
        try await database.write { db in
            try db.backup(to: DatabaseQueue(path: backupURL.path))
        }
        
        return backupURL
    }
    
    func restoreBackup(from url: URL) async throws {
        // 创建当前数据库的备份
        _ = try await createBackup()
        
        // 恢复数据库
        try await database.write { db in
            let backupDB = try DatabaseQueue(path: url.path)
            try backupDB.backup(to: db)
        }
    }
    
    func listBackups() -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: backupDirectory,
                                                                   includingPropertiesForKeys: [.creationDateKey],
                                                                   options: .skipsHiddenFiles)
            return files.filter { $0.pathExtension == "db" }
                       .sorted { url1, url2 in
                           let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate
                           let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate
                           return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
                       }
        } catch {
            return []
        }
    }
}

// MARK: - 日期格式化器扩展
extension DateFormatter {
    static let backupFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
```

## 📚 相关文档

- [应用架构模块](app-architecture.md)
- [处理器层模块](handler-layer.md)
- [协议层模块](protocol-layer.md)
- [视图层模块](view-layer.md)
- [基础工具模块](base-utilities.md)

---

*本文档详细介绍了V2rayU数据库层的设计与实现，为开发者提供了完整的数据持久化解决方案。*
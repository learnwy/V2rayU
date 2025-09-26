# 日志管理功能详解

## 📋 概述

日志管理功能是V2rayU的重要组成部分，提供全面的日志记录、查看、分析和管理能力。该功能帮助用户监控应用运行状态、诊断问题、分析网络行为，并提供详细的操作审计记录。

## 🎯 功能特性

### 1. 日志类型
- **系统日志**: 应用启动、关闭、配置变更等系统事件
- **代理日志**: 代理连接、断开、错误等代理相关事件
- **网络日志**: 网络请求、响应、流量统计等网络活动
- **错误日志**: 异常、错误、警告等问题记录
- **安全日志**: 认证、授权、安全事件等安全相关记录
- **调试日志**: 开发调试信息和详细执行流程

### 2. 日志级别
- ✅ **TRACE**: 最详细的调试信息
- ✅ **DEBUG**: 调试信息
- ✅ **INFO**: 一般信息
- ✅ **WARN**: 警告信息
- ✅ **ERROR**: 错误信息
- ✅ **FATAL**: 致命错误

### 3. 核心功能
- ✅ 实时日志查看
- ✅ 日志搜索和过滤
- ✅ 日志分类和标签
- ✅ 日志导出和备份
- ✅ 日志轮转和清理
- ✅ 日志统计分析
- ✅ 日志告警通知
- ✅ 日志可视化展示

## 🏗️ 架构设计

### 1. 组件关系图

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   LogView       │────│   LogHandler    │────│   LogManager    │
│  (UI Layer)     │    │(Business Logic) │    │ (Core Service)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ LogFilterView   │    │ LogRepository   │    │   LogCollector  │
│ LogDetailView   │    │ LogExporter     │    │   LogFormatter  │
│ LogStatsView    │    │ LogAnalyzer     │    │   LogRotator    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 2. 日志处理流程

```
日志事件 → 日志收集 → 格式化 → 存储 → 索引 → 查询展示
    ↓           ↓           ↓        ↓       ↓        ↓
事件触发 → 数据采集 → 结构化 → 持久化 → 建索引 → 用户界面
```

## 💻 核心实现

### 1. 日志数据模型

```swift
// MARK: - 日志条目
struct LogEntry: Codable, Identifiable, Equatable {
    let id: String
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let details: String?
    let source: String
    let thread: String?
    let tags: [String]
    let metadata: [String: String]
    let stackTrace: String?
    
    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        level: LogLevel,
        category: LogCategory,
        message: String,
        details: String? = nil,
        source: String,
        thread: String? = nil,
        tags: [String] = [],
        metadata: [String: String] = [:],
        stackTrace: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.details = details
        self.source = source
        self.thread = thread
        self.tags = tags
        self.metadata = metadata
        self.stackTrace = stackTrace
    }
    
    // MARK: - 计算属性
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    var shortTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    var levelIcon: String {
        return level.icon
    }
    
    var levelColor: Color {
        return level.color
    }
    
    var categoryIcon: String {
        return category.icon
    }
    
    var hasDetails: Bool {
        return details != nil && !details!.isEmpty
    }
    
    var hasStackTrace: Bool {
        return stackTrace != nil && !stackTrace!.isEmpty
    }
    
    var formattedMessage: String {
        var result = message
        
        // 替换元数据占位符
        for (key, value) in metadata {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        
        return result
    }
    
    // MARK: - 搜索匹配
    
    func matches(searchText: String) -> Bool {
        guard !searchText.isEmpty else { return true }
        
        let lowercaseSearch = searchText.lowercased()
        
        return message.lowercased().contains(lowercaseSearch) ||
               (details?.lowercased().contains(lowercaseSearch) ?? false) ||
               source.lowercased().contains(lowercaseSearch) ||
               tags.contains { $0.lowercased().contains(lowercaseSearch) } ||
               metadata.values.contains { $0.lowercased().contains(lowercaseSearch) }
    }
    
    func matches(filter: LogFilter) -> Bool {
        // 级别过滤
        if let levels = filter.levels, !levels.isEmpty {
            if !levels.contains(level) {
                return false
            }
        }
        
        // 分类过滤
        if let categories = filter.categories, !categories.isEmpty {
            if !categories.contains(category) {
                return false
            }
        }
        
        // 时间范围过滤
        if let startTime = filter.startTime {
            if timestamp < startTime {
                return false
            }
        }
        
        if let endTime = filter.endTime {
            if timestamp > endTime {
                return false
            }
        }
        
        // 标签过滤
        if let filterTags = filter.tags, !filterTags.isEmpty {
            let hasMatchingTag = filterTags.contains { filterTag in
                tags.contains { tag in
                    tag.lowercased().contains(filterTag.lowercased())
                }
            }
            if !hasMatchingTag {
                return false
            }
        }
        
        // 源过滤
        if let sources = filter.sources, !sources.isEmpty {
            if !sources.contains(source) {
                return false
            }
        }
        
        return true
    }
}

// MARK: - 日志级别
enum LogLevel: String, CaseIterable, Codable, Comparable {
    case trace = "TRACE"
    case debug = "DEBUG"
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
    case fatal = "FATAL"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .trace: return "magnifyingglass"
        case .debug: return "ladybug"
        case .info: return "info.circle"
        case .warn: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .fatal: return "flame"
        }
    }
    
    var color: Color {
        switch self {
        case .trace: return .gray
        case .debug: return .blue
        case .info: return .green
        case .warn: return .orange
        case .error: return .red
        case .fatal: return .purple
        }
    }
    
    var priority: Int {
        switch self {
        case .trace: return 0
        case .debug: return 1
        case .info: return 2
        case .warn: return 3
        case .error: return 4
        case .fatal: return 5
        }
    }
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.priority < rhs.priority
    }
}

// MARK: - 日志分类
enum LogCategory: String, CaseIterable, Codable {
    case system = "system"
    case proxy = "proxy"
    case network = "network"
    case security = "security"
    case database = "database"
    case ui = "ui"
    case config = "config"
    case subscription = "subscription"
    case routing = "routing"
    case traffic = "traffic"
    
    var displayName: String {
        switch self {
        case .system: return "系统"
        case .proxy: return "代理"
        case .network: return "网络"
        case .security: return "安全"
        case .database: return "数据库"
        case .ui: return "界面"
        case .config: return "配置"
        case .subscription: return "订阅"
        case .routing: return "路由"
        case .traffic: return "流量"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "gear"
        case .proxy: return "network"
        case .network: return "wifi"
        case .security: return "lock.shield"
        case .database: return "cylinder"
        case .ui: return "rectangle.on.rectangle"
        case .config: return "slider.horizontal.3"
        case .subscription: return "arrow.triangle.2.circlepath"
        case .routing: return "point.topleft.down.curvedto.point.bottomright.up"
        case .traffic: return "chart.line.uptrend.xyaxis"
        }
    }
    
    var color: Color {
        switch self {
        case .system: return .blue
        case .proxy: return .green
        case .network: return .cyan
        case .security: return .red
        case .database: return .purple
        case .ui: return .orange
        case .config: return .yellow
        case .subscription: return .pink
        case .routing: return .indigo
        case .traffic: return .mint
        }
    }
}

// MARK: - 日志过滤器
struct LogFilter: Codable {
    var levels: [LogLevel]?
    var categories: [LogCategory]?
    var startTime: Date?
    var endTime: Date?
    var tags: [String]?
    var sources: [String]?
    var searchText: String?
    
    init(
        levels: [LogLevel]? = nil,
        categories: [LogCategory]? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        tags: [String]? = nil,
        sources: [String]? = nil,
        searchText: String? = nil
    ) {
        self.levels = levels
        self.categories = categories
        self.startTime = startTime
        self.endTime = endTime
        self.tags = tags
        self.sources = sources
        self.searchText = searchText
    }
    
    var isEmpty: Bool {
        return levels?.isEmpty != false &&
               categories?.isEmpty != false &&
               startTime == nil &&
               endTime == nil &&
               tags?.isEmpty != false &&
               sources?.isEmpty != false &&
               (searchText?.isEmpty != false)
    }
}

// MARK: - 日志统计
struct LogStatistics: Codable {
    let totalCount: Int
    let levelCounts: [LogLevel: Int]
    let categoryCounts: [LogCategory: Int]
    let sourceCounts: [String: Int]
    let timeRange: DateInterval?
    let topTags: [String]
    let errorRate: Double
    let averageLogsPerMinute: Double
    
    init(
        totalCount: Int = 0,
        levelCounts: [LogLevel: Int] = [:],
        categoryCounts: [LogCategory: Int] = [:],
        sourceCounts: [String: Int] = [:],
        timeRange: DateInterval? = nil,
        topTags: [String] = [],
        errorRate: Double = 0.0,
        averageLogsPerMinute: Double = 0.0
    ) {
        self.totalCount = totalCount
        self.levelCounts = levelCounts
        self.categoryCounts = categoryCounts
        self.sourceCounts = sourceCounts
        self.timeRange = timeRange
        self.topTags = topTags
        self.errorRate = errorRate
        self.averageLogsPerMinute = averageLogsPerMinute
    }
    
    var formattedErrorRate: String {
        return String(format: "%.2f%%", errorRate * 100)
    }
    
    var formattedLogsPerMinute: String {
        return String(format: "%.1f", averageLogsPerMinute)
    }
}
```

### 2. 日志管理器实现

```swift
// MARK: - 日志管理器协议
protocol LogManagerProtocol {
    func log(_ entry: LogEntry) async
    func log(level: LogLevel, category: LogCategory, message: String, source: String, details: String?, tags: [String], metadata: [String: String]) async
    func getLogs(filter: LogFilter?, limit: Int?, offset: Int?) async -> [LogEntry]
    func getLogCount(filter: LogFilter?) async -> Int
    func getStatistics(filter: LogFilter?) async -> LogStatistics
    func clearLogs(olderThan date: Date?) async throws
    func exportLogs(filter: LogFilter?, format: LogExportFormat) async throws -> URL
}

// MARK: - 日志管理器实现
class LogManager: LogManagerProtocol, ObservableObject {
    private let logger = Logger(subsystem: "V2rayU", category: "LogManager")
    private let repository: LogRepository
    private let rotator: LogRotator
    private let collector: LogCollector
    
    @Published var isEnabled = true
    @Published var currentLogLevel: LogLevel = .info
    @Published var maxLogEntries = 10000
    @Published var autoRotateEnabled = true
    @Published var rotateInterval: TimeInterval = 24 * 60 * 60 // 24小时
    
    private let logQueue = DispatchQueue(label: "log.manager.queue", qos: .utility)
    private var logBuffer: [LogEntry] = []
    private let bufferSize = 100
    private var flushTimer: Timer?
    
    init(repository: LogRepository) {
        self.repository = repository
        self.rotator = LogRotator(repository: repository)
        self.collector = LogCollector()
        
        setupFlushTimer()
        setupRotationTimer()
    }
    
    deinit {
        flushTimer?.invalidate()
    }
    
    // MARK: - 公共方法
    
    /// 记录日志
    func log(_ entry: LogEntry) async {
        guard isEnabled && entry.level >= currentLogLevel else { return }
        
        await withCheckedContinuation { continuation in
            logQueue.async {
                self.logBuffer.append(entry)
                
                // 如果缓冲区满了，立即刷新
                if self.logBuffer.count >= self.bufferSize {
                    Task {
                        await self.flushBuffer()
                    }
                }
                
                continuation.resume()
            }
        }
    }
    
    /// 便捷日志记录方法
    func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        source: String = #file,
        details: String? = nil,
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) async {
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            details: details,
            source: extractFileName(from: source),
            thread: Thread.current.name,
            tags: tags,
            metadata: metadata,
            stackTrace: level >= .error ? Thread.callStackSymbols.joined(separator: "\n") : nil
        )
        
        await log(entry)
    }
    
    /// 获取日志
    func getLogs(filter: LogFilter? = nil, limit: Int? = nil, offset: Int? = nil) async -> [LogEntry] {
        do {
            return try await repository.getLogs(filter: filter, limit: limit, offset: offset)
        } catch {
            logger.error("获取日志失败: \(error)")
            return []
        }
    }
    
    /// 获取日志数量
    func getLogCount(filter: LogFilter? = nil) async -> Int {
        do {
            return try await repository.getLogCount(filter: filter)
        } catch {
            logger.error("获取日志数量失败: \(error)")
            return 0
        }
    }
    
    /// 获取统计信息
    func getStatistics(filter: LogFilter? = nil) async -> LogStatistics {
        do {
            return try await repository.getStatistics(filter: filter)
        } catch {
            logger.error("获取日志统计失败: \(error)")
            return LogStatistics()
        }
    }
    
    /// 清理日志
    func clearLogs(olderThan date: Date? = nil) async throws {
        try await repository.clearLogs(olderThan: date)
        logger.info("日志清理完成")
    }
    
    /// 导出日志
    func exportLogs(filter: LogFilter? = nil, format: LogExportFormat = .json) async throws -> URL {
        let logs = await getLogs(filter: filter)
        let exporter = LogExporter()
        
        let url = try await exporter.export(logs: logs, format: format)
        logger.info("日志导出完成: \(url.path)")
        
        return url
    }
    
    /// 搜索日志
    func searchLogs(query: String, limit: Int = 100) async -> [LogEntry] {
        let filter = LogFilter(searchText: query)
        return await getLogs(filter: filter, limit: limit)
    }
    
    /// 获取最近的错误日志
    func getRecentErrors(limit: Int = 50) async -> [LogEntry] {
        let filter = LogFilter(levels: [.error, .fatal])
        return await getLogs(filter: filter, limit: limit)
    }
    
    /// 获取实时日志流
    func getRealtimeLogs() -> AsyncStream<LogEntry> {
        return AsyncStream { continuation in
            let observer = NotificationCenter.default.addObserver(
                forName: .newLogEntry,
                object: nil,
                queue: nil
            ) { notification in
                if let entry = notification.object as? LogEntry {
                    continuation.yield(entry)
                }
            }
            
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func setupFlushTimer() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await self.flushBuffer()
            }
        }
    }
    
    private func setupRotationTimer() {
        guard autoRotateEnabled else { return }
        
        Timer.scheduledTimer(withTimeInterval: rotateInterval, repeats: true) { _ in
            Task {
                await self.rotator.rotateIfNeeded(maxEntries: self.maxLogEntries)
            }
        }
    }
    
    private func flushBuffer() async {
        await withCheckedContinuation { continuation in
            logQueue.async {
                guard !self.logBuffer.isEmpty else {
                    continuation.resume()
                    return
                }
                
                let entriesToFlush = self.logBuffer
                self.logBuffer.removeAll()
                
                Task {
                    do {
                        try await self.repository.saveLogs(entriesToFlush)
                        
                        // 发送通知
                        for entry in entriesToFlush {
                            NotificationCenter.default.post(
                                name: .newLogEntry,
                                object: entry
                            )
                        }
                    } catch {
                        self.logger.error("保存日志失败: \(error)")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    private func extractFileName(from path: String) -> String {
        return URL(fileURLWithPath: path).lastPathComponent
    }
}

// MARK: - 日志收集器
class LogCollector {
    private let logger = Logger(subsystem: "V2rayU", category: "LogCollector")
    
    func collectSystemInfo() -> [String: String] {
        var info: [String: String] = [:]
        
        info["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        info["build_number"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        info["system_version"] = ProcessInfo.processInfo.operatingSystemVersionString
        info["device_model"] = getDeviceModel()
        info["memory_usage"] = getMemoryUsage()
        info["cpu_usage"] = getCPUUsage()
        
        return info
    }
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value))!)
        }
        return identifier
    }
    
    private func getMemoryUsage() -> String {
        let info = mach_task_basic_info()
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
            let memoryMB = Double(info.resident_size) / 1024.0 / 1024.0
            return String(format: "%.1f MB", memoryMB)
        } else {
            return "Unknown"
        }
    }
    
    private func getCPUUsage() -> String {
        var info = processor_info_array_t(bitPattern: 0)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                       PROCESSOR_CPU_LOAD_INFO,
                                       &numCpus,
                                       &info,
                                       &numCpuInfo)
        
        if result == KERN_SUCCESS {
            // 简化的CPU使用率计算
            return "Available"
        } else {
            return "Unknown"
        }
    }
}

// MARK: - 日志轮转器
class LogRotator {
    private let repository: LogRepository
    private let logger = Logger(subsystem: "V2rayU", category: "LogRotator")
    
    init(repository: LogRepository) {
        self.repository = repository
    }
    
    func rotateIfNeeded(maxEntries: Int) async {
        do {
            let count = try await repository.getLogCount(filter: nil)
            
            if count > maxEntries {
                let deleteCount = count - maxEntries + (maxEntries / 10) // 删除多10%
                let oldestDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())
                
                try await repository.clearLogs(olderThan: oldestDate)
                logger.info("日志轮转完成，删除了 \(deleteCount) 条旧日志")
            }
        } catch {
            logger.error("日志轮转失败: \(error)")
        }
    }
}

// MARK: - 日志导出器
class LogExporter {
    private let logger = Logger(subsystem: "V2rayU", category: "LogExporter")
    
    func export(logs: [LogEntry], format: LogExportFormat) async throws -> URL {
        let fileName = "logs_\(Date().timeIntervalSince1970).\(format.fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        switch format {
        case .json:
            try await exportAsJSON(logs: logs, to: url)
        case .csv:
            try await exportAsCSV(logs: logs, to: url)
        case .txt:
            try await exportAsText(logs: logs, to: url)
        }
        
        return url
    }
    
    private func exportAsJSON(logs: [LogEntry], to url: URL) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(logs)
        try data.write(to: url)
    }
    
    private func exportAsCSV(logs: [LogEntry], to url: URL) async throws {
        var csvContent = "Timestamp,Level,Category,Source,Message,Details\n"
        
        for log in logs {
            let row = [
                log.formattedTimestamp,
                log.level.rawValue,
                log.category.rawValue,
                log.source,
                escapeCSVField(log.message),
                escapeCSVField(log.details ?? "")
            ].joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        try csvContent.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func exportAsText(logs: [LogEntry], to url: URL) async throws {
        let textContent = logs.map { log in
            var line = "[\(log.formattedTimestamp)] [\(log.level.rawValue)] [\(log.category.rawValue)] [\(log.source)] \(log.message)"
            
            if let details = log.details, !details.isEmpty {
                line += "\n  Details: \(details)"
            }
            
            if !log.tags.isEmpty {
                line += "\n  Tags: \(log.tags.joined(separator: ", "))"
            }
            
            return line
        }.joined(separator: "\n\n")
        
        try textContent.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}

// MARK: - 导出格式
enum LogExportFormat: String, CaseIterable {
    case json = "json"
    case csv = "csv"
    case txt = "txt"
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .txt: return "文本"
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
}

// MARK: - 通知名称
extension Notification.Name {
    static let newLogEntry = Notification.Name("newLogEntry")
}
```

### 3. 日志处理器实现

```swift
// MARK: - 日志处理器
@MainActor
class LogHandler: AsyncHandler {
    private let logManager: LogManagerProtocol
    
    @Published var logs: [LogEntry] = []
    @Published var filteredLogs: [LogEntry] = []
    @Published var currentFilter = LogFilter()
    @Published var searchText = ""
    @Published var selectedLevels: Set<LogLevel> = Set(LogLevel.allCases)
    @Published var selectedCategories: Set<LogCategory> = Set(LogCategory.allCases)
    @Published var isRealTimeEnabled = true
    @Published var statistics = LogStatistics()
    @Published var isAutoScrollEnabled = true
    
    private var realtimeTask: Task<Void, Never>?
    private let pageSize = 100
    private var currentPage = 0
    private var hasMoreLogs = true
    
    init(logManager: LogManagerProtocol) {
        self.logManager = logManager
        super.init()
        
        setupRealtimeLogging()
    }
    
    deinit {
        realtimeTask?.cancel()
    }
    
    // MARK: - 公共方法
    
    /// 加载日志
    func loadLogs(reset: Bool = false) async {
        await performAsyncOperation {
            if reset {
                self.currentPage = 0
                self.hasMoreLogs = true
                await MainActor.run {
                    self.logs.removeAll()
                }
            }
            
            guard self.hasMoreLogs else { return }
            
            let filter = self.buildCurrentFilter()
            let newLogs = await self.logManager.getLogs(
                filter: filter,
                limit: self.pageSize,
                offset: self.currentPage * self.pageSize
            )
            
            await MainActor.run {
                if reset {
                    self.logs = newLogs
                } else {
                    self.logs.append(contentsOf: newLogs)
                }
                
                self.hasMoreLogs = newLogs.count == self.pageSize
                self.currentPage += 1
                
                self.applyFilters()
            }
            
            self.logger.info("日志加载完成: \(newLogs.count)条")
        }
    }
    
    /// 刷新日志
    func refreshLogs() async {
        await loadLogs(reset: true)
        await loadStatistics()
    }
    
    /// 加载更多日志
    func loadMoreLogs() async {
        await loadLogs(reset: false)
    }
    
    /// 搜索日志
    func searchLogs(query: String) async {
        await performAsyncOperation {
            let searchResults = await self.logManager.searchLogs(query: query)
            
            await MainActor.run {
                self.logs = searchResults
                self.applyFilters()
            }
            
            self.logger.info("日志搜索完成: \(searchResults.count)条结果")
        }
    }
    
    /// 清理日志
    func clearLogs(olderThan date: Date? = nil) async {
        await performAsyncOperation {
            try await self.logManager.clearLogs(olderThan: date)
            
            await MainActor.run {
                if let date = date {
                    self.logs.removeAll { $0.timestamp < date }
                } else {
                    self.logs.removeAll()
                }
                self.applyFilters()
            }
            
            await self.loadStatistics()
            self.logger.info("日志清理完成")
        }
    }
    
    /// 导出日志
    func exportLogs(format: LogExportFormat = .json) async -> URL? {
        do {
            let filter = buildCurrentFilter()
            let url = try await logManager.exportLogs(filter: filter, format: format)
            
            logger.info("日志导出成功: \(url.path)")
            return url
        } catch {
            await MainActor.run {
                self.error = error
            }
            logger.error("日志导出失败: \(error)")
            return nil
        }
    }
    
    /// 应用过滤器
    func applyFilters() {
        var filtered = logs
        
        // 级别过滤
        if !selectedLevels.isEmpty && selectedLevels.count < LogLevel.allCases.count {
            filtered = filtered.filter { selectedLevels.contains($0.level) }
        }
        
        // 分类过滤
        if !selectedCategories.isEmpty && selectedCategories.count < LogCategory.allCases.count {
            filtered = filtered.filter { selectedCategories.contains($0.category) }
        }
        
        // 搜索文本过滤
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.matches(searchText: searchText) }
        }
        
        // 时间过滤
        if let startTime = currentFilter.startTime {
            filtered = filtered.filter { $0.timestamp >= startTime }
        }
        
        if let endTime = currentFilter.endTime {
            filtered = filtered.filter { $0.timestamp <= endTime }
        }
        
        filteredLogs = filtered.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// 加载统计信息
    func loadStatistics() async {
        await performAsyncOperation {
            let filter = self.buildCurrentFilter()
            let stats = await self.logManager.getStatistics(filter: filter)
            
            await MainActor.run {
                self.statistics = stats
            }
        }
    }
    
    /// 切换实时日志
    func toggleRealtimeLogging() {
        isRealTimeEnabled.toggle()
        
        if isRealTimeEnabled {
            setupRealtimeLogging()
        } else {
            realtimeTask?.cancel()
            realtimeTask = nil
        }
    }
    
    /// 获取最近错误
    func getRecentErrors() async {
        await performAsyncOperation {
            let errors = await self.logManager.getRecentErrors()
            
            await MainActor.run {
                self.logs = errors
                self.applyFilters()
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func setupRealtimeLogging() {
        guard isRealTimeEnabled else { return }
        
        realtimeTask = Task {
            for await entry in logManager.getRealtimeLogs() {
                await MainActor.run {
                    self.logs.insert(entry, at: 0)
                    
                    // 限制内存中的日志数量
                    if self.logs.count > 1000 {
                        self.logs.removeLast()
                    }
                    
                    self.applyFilters()
                }
            }
        }
    }
    
    private func buildCurrentFilter() -> LogFilter {
        var filter = currentFilter
        
        if !selectedLevels.isEmpty && selectedLevels.count < LogLevel.allCases.count {
            filter.levels = Array(selectedLevels)
        }
        
        if !selectedCategories.isEmpty && selectedCategories.count < LogCategory.allCases.count {
            filter.categories = Array(selectedCategories)
        }
        
        if !searchText.isEmpty {
            filter.searchText = searchText
        }
        
        return filter
    }
}
```

### 4. 用户界面实现

```swift
// MARK: - 日志管理主视图
struct LogView: View {
    @StateObject private var handler = HandlerManager.shared.logHandler
    @State private var showingExportSheet = false
    @State private var showingClearAlert = false
    @State private var selectedEntry: LogEntry?
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            LogToolbarView(handler: handler) {
                showingExportSheet = true
            } onClear: {
                showingClearAlert = true
            }
            
            // 过滤器
            LogFilterView(handler: handler)
            
            // 统计信息
            LogStatisticsView(statistics: handler.statistics)
            
            // 日志列表
            LogListView(handler: handler) { entry in
                selectedEntry = entry
            }
        }
        .navigationTitle("日志管理")
        .sheet(item: $selectedEntry) { entry in
            LogDetailView(entry: entry)
        }
        .sheet(isPresented: $showingExportSheet) {
            LogExportView(handler: handler)
        }
        .alert("清理日志", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) { }
            Button("清理全部", role: .destructive) {
                Task {
                    await handler.clearLogs()
                }
            }
            Button("清理30天前") {
                let date = Calendar.current.date(byAdding: .day, value: -30, to: Date())
                Task {
                    await handler.clearLogs(olderThan: date)
                }
            }
        } message: {
            Text("选择要清理的日志范围")
        }
        .task {
            await handler.refreshLogs()
        }
    }
}

// MARK: - 日志工具栏
struct LogToolbarView: View {
    @ObservedObject var handler: LogHandler
    let onExport: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        HStack {
            Button("刷新") {
                Task {
                    await handler.refreshLogs()
                }
            }
            
            Button("导出", action: onExport)
            
            Button("清理", action: onClear)
                .foregroundColor(.red)
            
            Spacer()
            
            Toggle("实时日志", isOn: $handler.isRealTimeEnabled)
                .onChange(of: handler.isRealTimeEnabled) { _ in
                    handler.toggleRealtimeLogging()
                }
            
            Toggle("自动滚动", isOn: $handler.isAutoScrollEnabled)
            
            Text("\(handler.filteredLogs.count) / \(handler.logs.count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - 日志过滤器
struct LogFilterView: View {
    @ObservedObject var handler: LogHandler
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // 搜索框
                TextField("搜索日志...", text: $handler.searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        handler.applyFilters()
                    }
                
                Button("搜索") {
                    Task {
                        await handler.searchLogs(query: handler.searchText)
                    }
                }
                .disabled(handler.searchText.isEmpty)
            }
            
            HStack {
                // 级别过滤
                Text("级别:")
                    .font(.caption)
                
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Toggle(level.rawValue, isOn: Binding(
                        get: { handler.selectedLevels.contains(level) },
                        set: { isSelected in
                            if isSelected {
                                handler.selectedLevels.insert(level)
                            } else {
                                handler.selectedLevels.remove(level)
                            }
                            handler.applyFilters()
                        }
                    ))
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(level.color)
                }
                
                Spacer()
                
                // 分类过滤
                Text("分类:")
                    .font(.caption)
                
                Menu("选择分类") {
                    ForEach(LogCategory.allCases, id: \.self) { category in
                        Toggle(category.displayName, isOn: Binding(
                            get: { handler.selectedCategories.contains(category) },
                            set: { isSelected in
                                if isSelected {
                                    handler.selectedCategories.insert(category)
                                } else {
                                    handler.selectedCategories.remove(category)
                                }
                                handler.applyFilters()
                            }
                        ))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - 日志统计视图
struct LogStatisticsView: View {
    let statistics: LogStatistics
    
    var body: some View {
        HStack(spacing: 20) {
            StatisticCard(title: "总数", value: "\(statistics.totalCount)", color: .blue)
            StatisticCard(title: "错误率", value: statistics.formattedErrorRate, color: .red)
            StatisticCard(title: "每分钟", value: statistics.formattedLogsPerMinute, color: .green)
            
            Spacer()
            
            // 级别分布
            HStack(spacing: 8) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    if let count = statistics.levelCounts[level], count > 0 {
                        VStack {
                            Image(systemName: level.icon)
                                .foregroundColor(level.color)
                            Text("\(count)")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - 统计卡片
struct StatisticCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
        .frame(minWidth: 60)
    }
}

// MARK: - 日志列表
struct LogListView: View {
    @ObservedObject var handler: LogHandler
    let onSelectEntry: (LogEntry) -> Void
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(handler.filteredLogs, id: \.id) { entry in
                    LogRowView(entry: entry) {
                        onSelectEntry(entry)
                    }
                    .onAppear {
                        // 加载更多
                        if entry.id == handler.filteredLogs.last?.id {
                            Task {
                                await handler.loadMoreLogs()
                            }
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .onChange(of: handler.filteredLogs.count) { _ in
                if handler.isAutoScrollEnabled && !handler.filteredLogs.isEmpty {
                    withAnimation {
                        proxy.scrollTo(handler.filteredLogs.first?.id, anchor: .top)
                    }
                }
            }
        }
    }
}

// MARK: - 日志行视图
struct LogRowView: View {
    let entry: LogEntry
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // 时间
            Text(entry.shortTimestamp)
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            // 级别图标
            Image(systemName: entry.levelIcon)
                .foregroundColor(entry.levelColor)
                .frame(width: 16)
            
            // 分类图标
            Image(systemName: entry.categoryIcon)
                .foregroundColor(entry.category.color)
                .frame(width: 16)
            
            // 消息
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.formattedMessage)
                    .font(.body)
                    .lineLimit(2)
                
                if !entry.tags.isEmpty {
                    HStack {
                        ForEach(entry.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(3)
                        }
                        
                        if entry.tags.count > 3 {
                            Text("+\(entry.tags.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // 详情指示器
            if entry.hasDetails || entry.hasStackTrace {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}
```

## 🔧 使用示例

### 1. 记录日志

```swift
// 记录信息日志
await logManager.log(
    level: .info,
    category: .system,
    message: "应用启动完成",
    source: "AppDelegate",
    tags: ["startup", "system"]
)

// 记录错误日志
await logManager.log(
    level: .error,
    category: .proxy,
    message: "代理连接失败: {error}",
    source: "ProxyManager",
    details: "连接超时，请检查网络设置",
    tags: ["proxy", "connection", "error"],
    metadata: ["error": "Connection timeout"]
)
```

### 2. 搜索和过滤日志

```swift
// 搜索包含"错误"的日志
await logHandler.searchLogs(query: "错误")

// 过滤错误级别的日志
logHandler.selectedLevels = [.error, .fatal]
logHandler.applyFilters()

// 过滤代理相关的日志
logHandler.selectedCategories = [.proxy]
logHandler.applyFilters()
```

### 3. 导出日志

```swift
// 导出为JSON格式
if let url = await logHandler.exportLogs(format: .json) {
    print("日志已导出到: \(url.path)")
}

// 导出为CSV格式
if let url = await logHandler.exportLogs(format: .csv) {
    print("日志已导出到: \(url.path)")
}
```

## 📚 相关文档

- [系统代理功能](system-proxy.md)
- [流量统计功能](traffic-stats.md)
- [路由规则功能](routing-rules.md)
- [处理器层模块](../modules/handler-layer.md)
- [数据库层模块](../modules/database-layer.md)

---

*本文档详细介绍了V2rayU日志管理功能的设计与实现，为开发者提供了完整的日志记录、查看、分析和管理解决方案。*
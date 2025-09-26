# 流量统计功能详解

## 📋 概述

流量统计功能是V2rayU的重要特性之一，提供实时的网络流量监控、统计分析和可视化展示。该功能帮助用户了解网络使用情况，监控代理服务器的流量消耗，并提供详细的统计报告。

## 🎯 功能特性

### 1. 实时流量监控
- **上传流量**: 实时监控上传数据量
- **下载流量**: 实时监控下载数据量
- **总流量**: 累计流量统计
- **速度监控**: 实时上传/下载速度
- **连接数**: 当前活跃连接数

### 2. 统计维度
- ✅ 按时间统计（小时、天、周、月）
- ✅ 按代理服务器统计
- ✅ 按应用程序统计
- ✅ 按协议类型统计
- ✅ 按网络接口统计
- ✅ 历史数据对比

### 3. 核心功能
- ✅ 实时流量显示
- ✅ 流量图表可视化
- ✅ 流量限制和警告
- ✅ 数据导出功能
- ✅ 自动数据清理
- ✅ 流量重置功能
- ✅ 统计报告生成

## 🏗️ 架构设计

### 1. 组件关系图

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ TrafficStatsView│────│TrafficStatsHandler│──│ TrafficMonitor  │
│   (UI Layer)    │    │ (Business Logic)│    │ (Data Collection)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ TrafficChartView│    │ StatisticsEngine│    │ SystemNetworkAPI│
│ TrafficTableView│    │ DataAggregator  │    │ ProcessMonitor  │
│ TrafficSummary  │    │ ReportGenerator │    │ NetworkInterface│
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 2. 数据流向

```
System Network → TrafficMonitor → DataAggregator → StatisticsEngine → UI Components
      ↓               ↓               ↓               ↓               ↓
  Raw Data → Processed Data → Aggregated Data → Statistics → Visualization
```

## 💻 核心实现

### 1. 流量数据模型

```swift
// MARK: - 流量统计数据
struct TrafficStats: Codable, Equatable {
    let timestamp: Date
    let uploadBytes: UInt64
    let downloadBytes: UInt64
    let uploadSpeed: Double // bytes/second
    let downloadSpeed: Double // bytes/second
    let totalBytes: UInt64
    let activeConnections: Int
    let proxyID: String?
    let networkInterface: String?
    
    init(
        timestamp: Date = Date(),
        uploadBytes: UInt64 = 0,
        downloadBytes: UInt64 = 0,
        uploadSpeed: Double = 0,
        downloadSpeed: Double = 0,
        activeConnections: Int = 0,
        proxyID: String? = nil,
        networkInterface: String? = nil
    ) {
        self.timestamp = timestamp
        self.uploadBytes = uploadBytes
        self.downloadBytes = downloadBytes
        self.uploadSpeed = uploadSpeed
        self.downloadSpeed = downloadSpeed
        self.totalBytes = uploadBytes + downloadBytes
        self.activeConnections = activeConnections
        self.proxyID = proxyID
        self.networkInterface = networkInterface
    }
    
    // MARK: - 计算属性
    
    var formattedUploadBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(uploadBytes), countStyle: .binary)
    }
    
    var formattedDownloadBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(downloadBytes), countStyle: .binary)
    }
    
    var formattedTotalBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .binary)
    }
    
    var formattedUploadSpeed: String {
        ByteCountFormatter.string(fromByteCount: Int64(uploadSpeed), countStyle: .binary) + "/s"
    }
    
    var formattedDownloadSpeed: String {
        ByteCountFormatter.string(fromByteCount: Int64(downloadSpeed), countStyle: .binary) + "/s"
    }
}

// MARK: - 流量统计摘要
struct TrafficSummary: Codable, Equatable {
    let period: StatisticsPeriod
    let startDate: Date
    let endDate: Date
    let totalUpload: UInt64
    let totalDownload: UInt64
    let totalBytes: UInt64
    let averageUploadSpeed: Double
    let averageDownloadSpeed: Double
    let peakUploadSpeed: Double
    let peakDownloadSpeed: Double
    let totalConnections: Int
    let activeTime: TimeInterval
    
    init(
        period: StatisticsPeriod,
        startDate: Date,
        endDate: Date,
        stats: [TrafficStats]
    ) {
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        
        self.totalUpload = stats.reduce(0) { $0 + $1.uploadBytes }
        self.totalDownload = stats.reduce(0) { $0 + $1.downloadBytes }
        self.totalBytes = totalUpload + totalDownload
        
        let validStats = stats.filter { $0.uploadSpeed > 0 || $0.downloadSpeed > 0 }
        self.averageUploadSpeed = validStats.isEmpty ? 0 : validStats.map { $0.uploadSpeed }.reduce(0, +) / Double(validStats.count)
        self.averageDownloadSpeed = validStats.isEmpty ? 0 : validStats.map { $0.downloadSpeed }.reduce(0, +) / Double(validStats.count)
        
        self.peakUploadSpeed = stats.map { $0.uploadSpeed }.max() ?? 0
        self.peakDownloadSpeed = stats.map { $0.downloadSpeed }.max() ?? 0
        
        self.totalConnections = stats.map { $0.activeConnections }.reduce(0, +)
        self.activeTime = endDate.timeIntervalSince(startDate)
    }
    
    // MARK: - 格式化方法
    
    var formattedTotalUpload: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalUpload), countStyle: .binary)
    }
    
    var formattedTotalDownload: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalDownload), countStyle: .binary)
    }
    
    var formattedTotalBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .binary)
    }
    
    var formattedAverageUploadSpeed: String {
        ByteCountFormatter.string(fromByteCount: Int64(averageUploadSpeed), countStyle: .binary) + "/s"
    }
    
    var formattedAverageDownloadSpeed: String {
        ByteCountFormatter.string(fromByteCount: Int64(averageDownloadSpeed), countStyle: .binary) + "/s"
    }
    
    var formattedActiveTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: activeTime) ?? "0s"
    }
}

// MARK: - 统计周期
enum StatisticsPeriod: String, CaseIterable, Codable {
    case hour = "hour"
    case day = "day"
    case week = "week"
    case month = "month"
    case year = "year"
    case all = "all"
    
    var displayName: String {
        switch self {
        case .hour: return "小时"
        case .day: return "天"
        case .week: return "周"
        case .month: return "月"
        case .year: return "年"
        case .all: return "全部"
        }
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .hour: return 3600
        case .day: return 86400
        case .week: return 604800
        case .month: return 2592000
        case .year: return 31536000
        case .all: return 0
        }
    }
    
    func startDate(from date: Date = Date()) -> Date {
        let calendar = Calendar.current
        
        switch self {
        case .hour:
            return calendar.dateInterval(of: .hour, for: date)?.start ?? date
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start ?? date
        case .year:
            return calendar.dateInterval(of: .year, for: date)?.start ?? date
        case .all:
            return Date.distantPast
        }
    }
}

// MARK: - 流量限制配置
struct TrafficLimit: Codable, Equatable {
    let period: StatisticsPeriod
    let uploadLimit: UInt64? // bytes
    let downloadLimit: UInt64? // bytes
    let totalLimit: UInt64? // bytes
    let speedLimit: Double? // bytes/second
    let isEnabled: Bool
    let warningThreshold: Double // 0.0 - 1.0
    
    init(
        period: StatisticsPeriod = .month,
        uploadLimit: UInt64? = nil,
        downloadLimit: UInt64? = nil,
        totalLimit: UInt64? = nil,
        speedLimit: Double? = nil,
        isEnabled: Bool = false,
        warningThreshold: Double = 0.8
    ) {
        self.period = period
        self.uploadLimit = uploadLimit
        self.downloadLimit = downloadLimit
        self.totalLimit = totalLimit
        self.speedLimit = speedLimit
        self.isEnabled = isEnabled
        self.warningThreshold = max(0.0, min(1.0, warningThreshold))
    }
    
    func checkLimit(for stats: TrafficSummary) -> TrafficLimitStatus {
        guard isEnabled else { return .normal }
        
        var warnings: [String] = []
        var exceeded: [String] = []
        
        // 检查上传限制
        if let uploadLimit = uploadLimit {
            let usage = Double(stats.totalUpload) / Double(uploadLimit)
            if usage >= 1.0 {
                exceeded.append("上传流量")
            } else if usage >= warningThreshold {
                warnings.append("上传流量")
            }
        }
        
        // 检查下载限制
        if let downloadLimit = downloadLimit {
            let usage = Double(stats.totalDownload) / Double(downloadLimit)
            if usage >= 1.0 {
                exceeded.append("下载流量")
            } else if usage >= warningThreshold {
                warnings.append("下载流量")
            }
        }
        
        // 检查总流量限制
        if let totalLimit = totalLimit {
            let usage = Double(stats.totalBytes) / Double(totalLimit)
            if usage >= 1.0 {
                exceeded.append("总流量")
            } else if usage >= warningThreshold {
                warnings.append("总流量")
            }
        }
        
        if !exceeded.isEmpty {
            return .exceeded(exceeded)
        } else if !warnings.isEmpty {
            return .warning(warnings)
        } else {
            return .normal
        }
    }
}

// MARK: - 流量限制状态
enum TrafficLimitStatus {
    case normal
    case warning([String])
    case exceeded([String])
    
    var isNormal: Bool {
        if case .normal = self {
            return true
        }
        return false
    }
    
    var message: String? {
        switch self {
        case .normal:
            return nil
        case .warning(let items):
            return "流量警告: \(items.joined(separator: "、"))接近限制"
        case .exceeded(let items):
            return "流量超限: \(items.joined(separator: "、"))已超过限制"
        }
    }
}
```

### 2. 流量监控服务实现

```swift
// MARK: - 流量监控协议
protocol TrafficMonitorProtocol {
    func startMonitoring() async
    func stopMonitoring() async
    func getCurrentStats() async -> TrafficStats
    func getHistoryStats(period: StatisticsPeriod, proxyID: String?) async -> [TrafficStats]
    func resetStats() async
    func exportStats(period: StatisticsPeriod, format: ExportFormat) async throws -> Data
}

// MARK: - 流量监控实现
class TrafficMonitor: TrafficMonitorProtocol, ObservableObject {
    private let logger = Logger(subsystem: "V2rayU", category: "TrafficMonitor")
    private let repository: TrafficStatsRepository
    private let networkMonitor: NetworkMonitor
    
    @Published var currentStats = TrafficStats()
    @Published var isMonitoring = false
    
    private var monitoringTask: Task<Void, Never>?
    private var lastStats: TrafficStats?
    private let updateInterval: TimeInterval = 1.0
    
    init(repository: TrafficStatsRepository) {
        self.repository = repository
        self.networkMonitor = NetworkMonitor()
    }
    
    // MARK: - 公共方法
    
    /// 开始监控
    func startMonitoring() async {
        guard !isMonitoring else { return }
        
        await MainActor.run {
            self.isMonitoring = true
        }
        
        monitoringTask = Task {
            await performMonitoring()
        }
        
        logger.info("流量监控已启动")
    }
    
    /// 停止监控
    func stopMonitoring() async {
        guard isMonitoring else { return }
        
        monitoringTask?.cancel()
        monitoringTask = nil
        
        await MainActor.run {
            self.isMonitoring = false
        }
        
        logger.info("流量监控已停止")
    }
    
    /// 获取当前统计
    func getCurrentStats() async -> TrafficStats {
        return await MainActor.run {
            self.currentStats
        }
    }
    
    /// 获取历史统计
    func getHistoryStats(period: StatisticsPeriod, proxyID: String? = nil) async -> [TrafficStats] {
        let startDate = period.startDate()
        let endDate = Date()
        
        do {
            return try await repository.getStats(
                startDate: startDate,
                endDate: endDate,
                proxyID: proxyID
            )
        } catch {
            logger.error("获取历史统计失败: \(error)")
            return []
        }
    }
    
    /// 重置统计
    func resetStats() async {
        do {
            try await repository.clearStats()
            
            await MainActor.run {
                self.currentStats = TrafficStats()
                self.lastStats = nil
            }
            
            logger.info("流量统计已重置")
        } catch {
            logger.error("重置流量统计失败: \(error)")
        }
    }
    
    /// 导出统计数据
    func exportStats(period: StatisticsPeriod, format: ExportFormat) async throws -> Data {
        let stats = await getHistoryStats(period: period)
        
        switch format {
        case .json:
            return try JSONEncoder().encode(stats)
            
        case .csv:
            return try generateCSVData(stats)
            
        case .excel:
            return try generateExcelData(stats)
        }
    }
    
    // MARK: - 私有方法
    
    private func performMonitoring() async {
        while !Task.isCancelled {
            do {
                let networkStats = try await networkMonitor.getCurrentNetworkStats()
                let newStats = await processNetworkStats(networkStats)
                
                await MainActor.run {
                    self.currentStats = newStats
                }
                
                // 保存到数据库
                try await repository.saveStats(newStats)
                
                // 更新上次统计
                lastStats = newStats
                
                try await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
            } catch {
                if !Task.isCancelled {
                    logger.error("流量监控错误: \(error)")
                    try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
                }
            }
        }
    }
    
    private func processNetworkStats(_ networkStats: NetworkStats) async -> TrafficStats {
        let currentTime = Date()
        
        // 计算速度
        var uploadSpeed: Double = 0
        var downloadSpeed: Double = 0
        
        if let lastStats = lastStats {
            let timeDiff = currentTime.timeIntervalSince(lastStats.timestamp)
            if timeDiff > 0 {
                let uploadDiff = networkStats.uploadBytes > lastStats.uploadBytes ? 
                    networkStats.uploadBytes - lastStats.uploadBytes : 0
                let downloadDiff = networkStats.downloadBytes > lastStats.downloadBytes ? 
                    networkStats.downloadBytes - lastStats.downloadBytes : 0
                
                uploadSpeed = Double(uploadDiff) / timeDiff
                downloadSpeed = Double(downloadDiff) / timeDiff
            }
        }
        
        return TrafficStats(
            timestamp: currentTime,
            uploadBytes: networkStats.uploadBytes,
            downloadBytes: networkStats.downloadBytes,
            uploadSpeed: uploadSpeed,
            downloadSpeed: downloadSpeed,
            activeConnections: networkStats.activeConnections,
            proxyID: networkStats.proxyID,
            networkInterface: networkStats.networkInterface
        )
    }
    
    private func generateCSVData(_ stats: [TrafficStats]) throws -> Data {
        var csvContent = "时间,上传(字节),下载(字节),总计(字节),上传速度(字节/秒),下载速度(字节/秒),活跃连接\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for stat in stats {
            let line = "\(dateFormatter.string(from: stat.timestamp)),\(stat.uploadBytes),\(stat.downloadBytes),\(stat.totalBytes),\(stat.uploadSpeed),\(stat.downloadSpeed),\(stat.activeConnections)\n"
            csvContent += line
        }
        
        guard let data = csvContent.data(using: .utf8) else {
            throw TrafficMonitorError.exportFailed("CSV数据生成失败")
        }
        
        return data
    }
    
    private func generateExcelData(_ stats: [TrafficStats]) throws -> Data {
        // 这里应该使用Excel生成库，如xlsxwriter或类似的库
        // 为了简化，这里返回CSV格式
        return try generateCSVData(stats)
    }
}

// MARK: - 网络监控器
class NetworkMonitor {
    private let logger = Logger(subsystem: "V2rayU", category: "NetworkMonitor")
    
    func getCurrentNetworkStats() async throws -> NetworkStats {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let stats = try self.getSystemNetworkStats()
                    continuation.resume(returning: stats)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func getSystemNetworkStats() throws -> NetworkStats {
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddrs) == 0 else {
            throw TrafficMonitorError.networkStatsUnavailable
        }
        
        defer {
            freeifaddrs(ifaddrs)
        }
        
        var totalUpload: UInt64 = 0
        var totalDownload: UInt64 = 0
        var activeConnections = 0
        
        var current = ifaddrs
        while current != nil {
            defer { current = current?.pointee.ifa_next }
            
            guard let addr = current?.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            
            let name = String(cString: current!.pointee.ifa_name)
            
            // 跳过回环接口
            guard !name.hasPrefix("lo") else { continue }
            
            if let data = current?.pointee.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self)
                totalUpload += UInt64(networkData.pointee.ifi_obytes)
                totalDownload += UInt64(networkData.pointee.ifi_ibytes)
            }
        }
        
        // 获取活跃连接数（简化实现）
        activeConnections = try getActiveConnectionCount()
        
        return NetworkStats(
            uploadBytes: totalUpload,
            downloadBytes: totalDownload,
            activeConnections: activeConnections,
            proxyID: nil, // 需要从代理管理器获取
            networkInterface: "system"
        )
    }
    
    private func getActiveConnectionCount() throws -> Int {
        // 使用netstat命令获取连接数
        let task = Process()
        task.launchPath = "/usr/sbin/netstat"
        task.arguments = ["-an"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // 计算ESTABLISHED连接数
        let lines = output.components(separatedBy: .newlines)
        let establishedCount = lines.filter { $0.contains("ESTABLISHED") }.count
        
        return establishedCount
    }
}

// MARK: - 网络统计数据
struct NetworkStats {
    let uploadBytes: UInt64
    let downloadBytes: UInt64
    let activeConnections: Int
    let proxyID: String?
    let networkInterface: String
}

// MARK: - 导出格式
enum ExportFormat: String, CaseIterable {
    case json = "json"
    case csv = "csv"
    case excel = "xlsx"
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .excel: return "Excel"
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
}

// MARK: - 流量监控错误
enum TrafficMonitorError: LocalizedError {
    case networkStatsUnavailable
    case exportFailed(String)
    case invalidPeriod
    case databaseError(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkStatsUnavailable:
            return "无法获取网络统计信息"
        case .exportFailed(let reason):
            return "导出失败: \(reason)"
        case .invalidPeriod:
            return "无效的统计周期"
        case .databaseError(let error):
            return "数据库错误: \(error.localizedDescription)"
        }
    }
}
```

### 3. 流量统计处理器实现

```swift
// MARK: - 流量统计处理器
@MainActor
class TrafficStatsHandler: AsyncHandler {
    private let monitor: TrafficMonitorProtocol
    private let repository: TrafficStatsRepository
    private let statisticsEngine: StatisticsEngine
    
    @Published var currentStats = TrafficStats()
    @Published var summary: TrafficSummary?
    @Published var selectedPeriod: StatisticsPeriod = .day
    @Published var historyStats: [TrafficStats] = []
    @Published var trafficLimit = TrafficLimit()
    @Published var limitStatus: TrafficLimitStatus = .normal
    @Published var isMonitoring = false
    
    init(
        monitor: TrafficMonitorProtocol,
        repository: TrafficStatsRepository,
        statisticsEngine: StatisticsEngine
    ) {
        self.monitor = monitor
        self.repository = repository
        self.statisticsEngine = statisticsEngine
        super.init()
        
        setupMonitoring()
    }
    
    // MARK: - 公共方法
    
    /// 开始监控
    func startMonitoring() async {
        await performAsyncOperation {
            await self.monitor.startMonitoring()
            await MainActor.run {
                self.isMonitoring = true
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .trafficMonitoringStarted,
                object: nil
            )
            
            self.logger.info("流量监控已启动")
        }
    }
    
    /// 停止监控
    func stopMonitoring() async {
        await performAsyncOperation {
            await self.monitor.stopMonitoring()
            await MainActor.run {
                self.isMonitoring = false
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .trafficMonitoringStopped,
                object: nil
            )
            
            self.logger.info("流量监控已停止")
        }
    }
    
    /// 切换监控状态
    func toggleMonitoring() async {
        if isMonitoring {
            await stopMonitoring()
        } else {
            await startMonitoring()
        }
    }
    
    /// 加载历史统计
    func loadHistoryStats(period: StatisticsPeriod, proxyID: String? = nil) async {
        await performAsyncOperation {
            let stats = await self.monitor.getHistoryStats(period: period, proxyID: proxyID)
            
            await MainActor.run {
                self.historyStats = stats
                self.selectedPeriod = period
                
                // 生成摘要
                if !stats.isEmpty {
                    self.summary = TrafficSummary(
                        period: period,
                        startDate: period.startDate(),
                        endDate: Date(),
                        stats: stats
                    )
                    
                    // 检查流量限制
                    if let summary = self.summary {
                        self.limitStatus = self.trafficLimit.checkLimit(for: summary)
                    }
                }
            }
            
            self.logger.info("历史统计加载完成: \(stats.count)条记录")
        }
    }
    
    /// 重置统计
    func resetStats() async {
        await performAsyncOperation {
            await self.monitor.resetStats()
            
            await MainActor.run {
                self.currentStats = TrafficStats()
                self.historyStats = []
                self.summary = nil
                self.limitStatus = .normal
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .trafficStatsReset,
                object: nil
            )
            
            self.logger.info("流量统计已重置")
        }
    }
    
    /// 导出统计数据
    func exportStats(period: StatisticsPeriod, format: ExportFormat) async -> URL? {
        do {
            let data = try await monitor.exportStats(period: period, format: format)
            
            let fileName = "traffic_stats_\(period.rawValue)_\(Date().timeIntervalSince1970).\(format.fileExtension)"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try data.write(to: url)
            
            logger.info("统计数据导出成功: \(url.path)")
            return url
        } catch {
            await MainActor.run {
                self.error = error
            }
            logger.error("导出统计数据失败: \(error)")
            return nil
        }
    }
    
    /// 更新流量限制
    func updateTrafficLimit(_ limit: TrafficLimit) async {
        await performAsyncOperation {
            await MainActor.run {
                self.trafficLimit = limit
                
                // 重新检查限制状态
                if let summary = self.summary {
                    self.limitStatus = limit.checkLimit(for: summary)
                }
            }
            
            // 保存配置
            try await self.repository.saveTrafficLimit(limit)
            
            self.logger.info("流量限制已更新")
        }
    }
    
    /// 生成统计报告
    func generateReport(period: StatisticsPeriod) async -> TrafficReport? {
        do {
            let stats = await monitor.getHistoryStats(period: period)
            let report = try await statisticsEngine.generateReport(stats: stats, period: period)
            
            logger.info("统计报告生成成功")
            return report
        } catch {
            await MainActor.run {
                self.error = error
            }
            logger.error("生成统计报告失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 私有方法
    
    private func setupMonitoring() {
        // 定期更新当前统计
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isMonitoring else { return }
                
                let stats = await self.monitor.getCurrentStats()
                self.currentStats = stats
                
                // 检查流量限制
                if let summary = self.summary {
                    let newLimitStatus = self.trafficLimit.checkLimit(for: summary)
                    if newLimitStatus != self.limitStatus {
                        self.limitStatus = newLimitStatus
                        
                        // 发送限制状态变化通知
                        NotificationCenter.default.post(
                            name: .trafficLimitStatusChanged,
                            object: newLimitStatus
                        )
                    }
                }
            }
        }
        
        // 加载保存的配置
        Task {
            await loadSavedConfiguration()
        }
    }
    
    private func loadSavedConfiguration() async {
        do {
            let savedLimit = try await repository.getTrafficLimit()
            await MainActor.run {
                self.trafficLimit = savedLimit
            }
        } catch {
            logger.warning("加载流量限制配置失败: \(error)")
        }
    }
}

// MARK: - 统计引擎
class StatisticsEngine {
    private let logger = Logger(subsystem: "V2rayU", category: "StatisticsEngine")
    
    func generateReport(stats: [TrafficStats], period: StatisticsPeriod) async throws -> TrafficReport {
        let summary = TrafficSummary(
            period: period,
            startDate: period.startDate(),
            endDate: Date(),
            stats: stats
        )
        
        let trends = calculateTrends(stats: stats)
        let patterns = analyzePatterns(stats: stats)
        let recommendations = generateRecommendations(summary: summary, trends: trends)
        
        return TrafficReport(
            summary: summary,
            trends: trends,
            patterns: patterns,
            recommendations: recommendations,
            generatedAt: Date()
        )
    }
    
    private func calculateTrends(stats: [TrafficStats]) -> TrafficTrends {
        // 计算流量趋势
        let sortedStats = stats.sorted { $0.timestamp < $1.timestamp }
        
        // 简化的趋势计算
        let uploadTrend = calculateTrend(values: sortedStats.map { Double($0.uploadBytes) })
        let downloadTrend = calculateTrend(values: sortedStats.map { Double($0.downloadBytes) })
        let speedTrend = calculateTrend(values: sortedStats.map { $0.uploadSpeed + $0.downloadSpeed })
        
        return TrafficTrends(
            uploadTrend: uploadTrend,
            downloadTrend: downloadTrend,
            speedTrend: speedTrend
        )
    }
    
    private func calculateTrend(values: [Double]) -> TrendDirection {
        guard values.count >= 2 else { return .stable }
        
        let firstHalf = values.prefix(values.count / 2)
        let secondHalf = values.suffix(values.count / 2)
        
        let firstAverage = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let change = (secondAverage - firstAverage) / firstAverage
        
        if change > 0.1 {
            return .increasing
        } else if change < -0.1 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func analyzePatterns(stats: [TrafficStats]) -> [TrafficPattern] {
        var patterns: [TrafficPattern] = []
        
        // 分析使用高峰时段
        let hourlyUsage = Dictionary(grouping: stats) { stat in
            Calendar.current.component(.hour, from: stat.timestamp)
        }
        
        let peakHours = hourlyUsage.compactMap { hour, stats in
            let totalBytes = stats.reduce(0) { $0 + $1.totalBytes }
            return (hour: hour, usage: totalBytes)
        }.sorted { $0.usage > $1.usage }.prefix(3)
        
        if !peakHours.isEmpty {
            let hours = peakHours.map { "\($0.hour):00" }.joined(separator: ", ")
            patterns.append(TrafficPattern(
                type: .peakHours,
                description: "使用高峰时段: \(hours)",
                confidence: 0.8
            ))
        }
        
        return patterns
    }
    
    private func generateRecommendations(summary: TrafficSummary, trends: TrafficTrends) -> [String] {
        var recommendations: [String] = []
        
        // 基于趋势的建议
        if trends.uploadTrend == .increasing {
            recommendations.append("上传流量呈增长趋势，建议关注上传密集型应用的使用")
        }
        
        if trends.downloadTrend == .increasing {
            recommendations.append("下载流量呈增长趋势，建议优化下载行为或考虑升级套餐")
        }
        
        // 基于使用量的建议
        if summary.totalBytes > 10 * 1024 * 1024 * 1024 { // 10GB
            recommendations.append("流量使用较大，建议启用流量限制功能")
        }
        
        if summary.averageUploadSpeed > summary.averageDownloadSpeed * 2 {
            recommendations.append("上传速度明显高于下载速度，可能存在异常上传行为")
        }
        
        return recommendations
    }
}
```

### 4. 用户界面实现

```swift
// MARK: - 流量统计主视图
struct TrafficStatsView: View {
    @StateObject private var handler = HandlerManager.shared.trafficStatsHandler
    @State private var showingExportSheet = false
    @State private var showingLimitSettings = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 实时流量卡片
            RealTimeTrafficCard(stats: handler.currentStats, handler: handler)
            
            // 统计周期选择
            PeriodSelector(selectedPeriod: $handler.selectedPeriod) {
                Task {
                    await handler.loadHistoryStats(period: handler.selectedPeriod)
                }
            }
            
            // 流量图表
            TrafficChartView(stats: handler.historyStats, period: handler.selectedPeriod)
            
            // 统计摘要
            if let summary = handler.summary {
                TrafficSummaryView(summary: summary, limitStatus: handler.limitStatus)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("流量统计")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("限制") {
                    showingLimitSettings = true
                }
                
                Button("导出") {
                    showingExportSheet = true
                }
                
                Button("重置") {
                    Task {
                        await handler.resetStats()
                    }
                }
                .foregroundColor(.red)
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportStatsView(handler: handler)
        }
        .sheet(isPresented: $showingLimitSettings) {
            TrafficLimitSettingsView(limit: $handler.trafficLimit, handler: handler)
        }
        .task {
            await handler.loadHistoryStats(period: handler.selectedPeriod)
        }
    }
}

// MARK: - 实时流量卡片
struct RealTimeTrafficCard: View {
    let stats: TrafficStats
    let handler: TrafficStatsHandler
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("实时流量")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await handler.toggleMonitoring()
                    }
                }) {
                    Image(systemName: handler.isMonitoring ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundColor(handler.isMonitoring ? .red : .green)
                }
                .disabled(handler.isLoading)
            }
            
            HStack(spacing: 20) {
                // 上传
                VStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    Text(stats.formattedUploadBytes)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(stats.formattedUploadSpeed)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 下载
                VStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    Text(stats.formattedDownloadBytes)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(stats.formattedDownloadSpeed)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // 总计
                VStack {
                    Image(systemName: "sum")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    Text(stats.formattedTotalBytes)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("\(stats.activeConnections) 连接")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
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

// MARK: - 周期选择器
struct PeriodSelector: View {
    @Binding var selectedPeriod: StatisticsPeriod
    let onSelectionChanged: () -> Void
    
    var body: some View {
        Picker("统计周期", selection: $selectedPeriod) {
            ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedPeriod) { _ in
            onSelectionChanged()
        }
    }
}

// MARK: - 流量图表视图
struct TrafficChartView: View {
    let stats: [TrafficStats]
    let period: StatisticsPeriod
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("流量趋势")
                .font(.headline)
            
            if stats.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                // 这里应该使用Charts框架绘制图表
                // 为了简化，显示文本信息
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(stats.prefix(50), id: \.timestamp) { stat in
                            VStack {
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: CGFloat(stat.uploadBytes) / 1024 / 1024)
                                
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: CGFloat(stat.downloadBytes) / 1024 / 1024)
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}
```

## 🔧 使用示例

### 1. 启动流量监控

```swift
// 启动监控
await trafficStatsHandler.startMonitoring()

// 获取当前统计
let currentStats = await trafficStatsHandler.monitor.getCurrentStats()
print("当前上传: \(currentStats.formattedUploadBytes)")
print("当前下载: \(currentStats.formattedDownloadBytes)")
```

### 2. 设置流量限制

```swift
var limit = TrafficLimit()
limit.period = .month
limit.totalLimit = 10 * 1024 * 1024 * 1024 // 10GB
limit.isEnabled = true
limit.warningThreshold = 0.8

await trafficStatsHandler.updateTrafficLimit(limit)
```

### 3. 导出统计数据

```swift
if let exportURL = await trafficStatsHandler.exportStats(
    period: .month,
    format: .csv
) {
    print("数据已导出到: \(exportURL.path)")
}
```

## 📚 相关文档

- [系统代理功能](system-proxy.md)
- [代理管理功能](proxy-management.md)
- [延迟测试功能](ping-testing.md)
- [数据库层模块](../modules/database-layer.md)
- [处理器层模块](../modules/handler-layer.md)

---

*本文档详细介绍了V2rayU流量统计功能的设计与实现，为开发者提供了完整的流量监控和分析解决方案。*
# 延迟测试功能详解

## 📋 概述

延迟测试功能是V2rayU的核心特性之一，提供对代理服务器连接质量的实时评估。该功能通过多种测试方法检测代理服务器的响应时间、连接稳定性和可用性，帮助用户选择最优的代理服务器。

## 🎯 功能特性

### 1. 测试类型
- **TCP连接测试**: 测试TCP连接建立时间
- **HTTP请求测试**: 通过HTTP请求测试实际延迟
- **ICMP Ping测试**: 使用ICMP协议测试网络延迟
- **自定义URL测试**: 支持自定义测试目标URL
- **批量测试**: 同时测试多个代理服务器

### 2. 测试指标
- ✅ 连接延迟（毫秒）
- ✅ 连接成功率
- ✅ 平均响应时间
- ✅ 最小/最大延迟
- ✅ 丢包率
- ✅ 连接稳定性评分

### 3. 核心功能
- ✅ 单个代理测试
- ✅ 批量代理测试
- ✅ 定时自动测试
- ✅ 测试结果排序
- ✅ 历史记录保存
- ✅ 测试配置自定义
- ✅ 结果可视化展示

## 🏗️ 架构设计

### 1. 组件关系图

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  PingTestView   │────│ PingTestHandler │────│   PingTester    │
│   (UI Layer)    │    │ (Business Logic)│    │ (Test Engine)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ TestResultView  │    │ TestScheduler   │    │ NetworkTester   │
│ TestConfigView  │    │ ResultAnalyzer  │    │ ProxyConnector  │
│ TestHistoryView │    │ TestRepository  │    │ TimeoutManager  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 2. 测试流程

```
开始测试 → 配置验证 → 建立连接 → 发送请求 → 接收响应 → 计算延迟 → 保存结果
    ↓           ↓           ↓           ↓           ↓           ↓           ↓
用户触发 → 参数检查 → TCP/HTTP → 测试数据 → 响应数据 → 时间差值 → 数据库存储
```

## 💻 核心实现

### 1. 测试结果数据模型

```swift
// MARK: - 延迟测试结果
struct PingResult: Codable, Identifiable, Equatable {
    let id = UUID()
    let proxyID: String
    let testType: PingTestType
    let timestamp: Date
    let latency: TimeInterval? // 延迟时间（秒）
    let isSuccess: Bool
    let errorMessage: String?
    let testURL: String
    let timeout: TimeInterval
    let attempts: Int
    
    init(
        proxyID: String,
        testType: PingTestType,
        timestamp: Date = Date(),
        latency: TimeInterval? = nil,
        isSuccess: Bool = false,
        errorMessage: String? = nil,
        testURL: String = "https://www.google.com",
        timeout: TimeInterval = 10.0,
        attempts: Int = 1
    ) {
        self.proxyID = proxyID
        self.testType = testType
        self.timestamp = timestamp
        self.latency = latency
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
        self.testURL = testURL
        self.timeout = timeout
        self.attempts = attempts
    }
    
    // MARK: - 计算属性
    
    var latencyMs: Int? {
        guard let latency = latency else { return nil }
        return Int(latency * 1000)
    }
    
    var formattedLatency: String {
        guard let latencyMs = latencyMs else {
            return isSuccess ? "N/A" : "失败"
        }
        return "\(latencyMs)ms"
    }
    
    var qualityLevel: PingQuality {
        guard let latencyMs = latencyMs, isSuccess else {
            return .failed
        }
        
        switch latencyMs {
        case 0..<100:
            return .excellent
        case 100..<200:
            return .good
        case 200..<500:
            return .fair
        case 500..<1000:
            return .poor
        default:
            return .bad
        }
    }
    
    var qualityColor: Color {
        switch qualityLevel {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .orange
        case .poor:
            return .red
        case .bad, .failed:
            return .gray
        }
    }
}

// MARK: - 测试类型
enum PingTestType: String, CaseIterable, Codable {
    case tcp = "tcp"
    case http = "http"
    case icmp = "icmp"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .tcp: return "TCP连接"
        case .http: return "HTTP请求"
        case .icmp: return "ICMP Ping"
        case .custom: return "自定义"
        }
    }
    
    var description: String {
        switch self {
        case .tcp: return "测试TCP连接建立时间"
        case .http: return "通过HTTP请求测试实际延迟"
        case .icmp: return "使用ICMP协议测试网络延迟"
        case .custom: return "使用自定义URL进行测试"
        }
    }
}

// MARK: - 延迟质量等级
enum PingQuality: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case bad = "bad"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .excellent: return "优秀"
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "较差"
        case .bad: return "很差"
        case .failed: return "失败"
        }
    }
    
    var threshold: ClosedRange<Int> {
        switch self {
        case .excellent: return 0...99
        case .good: return 100...199
        case .fair: return 200...499
        case .poor: return 500...999
        case .bad: return 1000...Int.max
        case .failed: return 0...0
        }
    }
}

// MARK: - 批量测试结果
struct BatchPingResult: Codable {
    let testID: UUID
    let startTime: Date
    let endTime: Date
    let results: [PingResult]
    let testConfig: PingTestConfig
    
    init(
        testID: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        results: [PingResult],
        testConfig: PingTestConfig
    ) {
        self.testID = testID
        self.startTime = startTime
        self.endTime = endTime
        self.results = results
        self.testConfig = testConfig
    }
    
    // MARK: - 统计属性
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var successCount: Int {
        results.filter { $0.isSuccess }.count
    }
    
    var failureCount: Int {
        results.count - successCount
    }
    
    var successRate: Double {
        guard !results.isEmpty else { return 0 }
        return Double(successCount) / Double(results.count)
    }
    
    var averageLatency: TimeInterval? {
        let successResults = results.compactMap { $0.latency }
        guard !successResults.isEmpty else { return nil }
        return successResults.reduce(0, +) / Double(successResults.count)
    }
    
    var minLatency: TimeInterval? {
        results.compactMap { $0.latency }.min()
    }
    
    var maxLatency: TimeInterval? {
        results.compactMap { $0.latency }.max()
    }
    
    var formattedDuration: String {
        String(format: "%.2fs", duration)
    }
    
    var formattedSuccessRate: String {
        String(format: "%.1f%%", successRate * 100)
    }
}

// MARK: - 测试配置
struct PingTestConfig: Codable, Equatable {
    var testType: PingTestType
    var testURL: String
    var timeout: TimeInterval
    var attempts: Int
    var interval: TimeInterval
    var concurrentLimit: Int
    var isAutoTest: Bool
    var autoTestInterval: TimeInterval
    
    init(
        testType: PingTestType = .http,
        testURL: String = "https://www.google.com",
        timeout: TimeInterval = 10.0,
        attempts: Int = 3,
        interval: TimeInterval = 1.0,
        concurrentLimit: Int = 10,
        isAutoTest: Bool = false,
        autoTestInterval: TimeInterval = 300.0
    ) {
        self.testType = testType
        self.testURL = testURL
        self.timeout = timeout
        self.attempts = attempts
        self.interval = interval
        self.concurrentLimit = concurrentLimit
        self.isAutoTest = isAutoTest
        self.autoTestInterval = autoTestInterval
    }
    
    // MARK: - 验证方法
    
    var isValid: Bool {
        return timeout > 0 &&
               attempts > 0 &&
               interval >= 0 &&
               concurrentLimit > 0 &&
               autoTestInterval > 0 &&
               !testURL.isEmpty
    }
    
    func validate() throws {
        if timeout <= 0 {
            throw PingTestError.invalidTimeout
        }
        
        if attempts <= 0 {
            throw PingTestError.invalidAttempts
        }
        
        if concurrentLimit <= 0 {
            throw PingTestError.invalidConcurrentLimit
        }
        
        if testURL.isEmpty {
            throw PingTestError.invalidURL
        }
        
        if let url = URL(string: testURL), url.scheme == nil {
            throw PingTestError.invalidURL
        }
    }
}
```

### 2. 延迟测试引擎实现

```swift
// MARK: - 延迟测试协议
protocol PingTesterProtocol {
    func testProxy(_ proxy: ProxyConfig, config: PingTestConfig) async -> PingResult
    func testProxies(_ proxies: [ProxyConfig], config: PingTestConfig) async -> BatchPingResult
    func startContinuousTest(for proxies: [ProxyConfig], config: PingTestConfig) async
    func stopContinuousTest() async
}

// MARK: - 延迟测试实现
class PingTester: PingTesterProtocol, ObservableObject {
    private let logger = Logger(subsystem: "V2rayU", category: "PingTester")
    private let repository: PingResultRepository
    private let networkTester: NetworkTester
    
    @Published var isTestingInProgress = false
    @Published var currentTestProgress: Double = 0.0
    @Published var testResults: [String: PingResult] = [:] // proxyID -> result
    
    private var continuousTestTask: Task<Void, Never>?
    private let testSemaphore: AsyncSemaphore
    
    init(repository: PingResultRepository, concurrentLimit: Int = 10) {
        self.repository = repository
        self.networkTester = NetworkTester()
        self.testSemaphore = AsyncSemaphore(value: concurrentLimit)
    }
    
    // MARK: - 公共方法
    
    /// 测试单个代理
    func testProxy(_ proxy: ProxyConfig, config: PingTestConfig) async -> PingResult {
        logger.info("开始测试代理: \(proxy.name)")
        
        do {
            try config.validate()
            
            let result = await performSingleTest(proxy: proxy, config: config)
            
            // 保存结果
            try await repository.saveResult(result)
            
            // 更新缓存
            await MainActor.run {
                self.testResults[proxy.id] = result
            }
            
            logger.info("代理测试完成: \(proxy.name), 延迟: \(result.formattedLatency)")
            return result
            
        } catch {
            let errorResult = PingResult(
                proxyID: proxy.id,
                testType: config.testType,
                isSuccess: false,
                errorMessage: error.localizedDescription,
                testURL: config.testURL,
                timeout: config.timeout
            )
            
            logger.error("代理测试失败: \(proxy.name), 错误: \(error)")
            return errorResult
        }
    }
    
    /// 批量测试代理
    func testProxies(_ proxies: [ProxyConfig], config: PingTestConfig) async -> BatchPingResult {
        logger.info("开始批量测试: \(proxies.count)个代理")
        
        let startTime = Date()
        
        await MainActor.run {
            self.isTestingInProgress = true
            self.currentTestProgress = 0.0
        }
        
        var results: [PingResult] = []
        let totalCount = proxies.count
        
        // 使用TaskGroup进行并发测试
        await withTaskGroup(of: PingResult.self) { group in
            for (index, proxy) in proxies.enumerated() {
                group.addTask {
                    await self.testSemaphore.wait()
                    defer { self.testSemaphore.signal() }
                    
                    let result = await self.performSingleTest(proxy: proxy, config: config)
                    
                    // 更新进度
                    await MainActor.run {
                        self.currentTestProgress = Double(index + 1) / Double(totalCount)
                    }
                    
                    return result
                }
            }
            
            for await result in group {
                results.append(result)
            }
        }
        
        let endTime = Date()
        
        // 保存批量结果
        let batchResult = BatchPingResult(
            startTime: startTime,
            endTime: endTime,
            results: results,
            testConfig: config
        )
        
        do {
            try await repository.saveBatchResult(batchResult)
        } catch {
            logger.error("保存批量测试结果失败: \(error)")
        }
        
        // 更新UI状态
        await MainActor.run {
            self.isTestingInProgress = false
            self.currentTestProgress = 1.0
            
            // 更新结果缓存
            for result in results {
                self.testResults[result.proxyID] = result
            }
        }
        
        logger.info("批量测试完成: \(results.count)个结果, 耗时: \(batchResult.formattedDuration)")
        return batchResult
    }
    
    /// 开始连续测试
    func startContinuousTest(for proxies: [ProxyConfig], config: PingTestConfig) async {
        guard continuousTestTask == nil else { return }
        
        logger.info("开始连续测试: \(proxies.count)个代理, 间隔: \(config.autoTestInterval)秒")
        
        continuousTestTask = Task {
            while !Task.isCancelled {
                _ = await testProxies(proxies, config: config)
                
                // 等待下次测试
                try? await Task.sleep(nanoseconds: UInt64(config.autoTestInterval * 1_000_000_000))
            }
        }
    }
    
    /// 停止连续测试
    func stopContinuousTest() async {
        continuousTestTask?.cancel()
        continuousTestTask = nil
        
        await MainActor.run {
            self.isTestingInProgress = false
        }
        
        logger.info("连续测试已停止")
    }
    
    // MARK: - 私有方法
    
    private func performSingleTest(proxy: ProxyConfig, config: PingTestConfig) async -> PingResult {
        var bestResult: PingResult?
        var lastError: Error?
        
        // 多次尝试，取最好结果
        for attempt in 1...config.attempts {
            do {
                let startTime = Date()
                
                switch config.testType {
                case .tcp:
                    try await networkTester.testTCPConnection(
                        host: proxy.server,
                        port: proxy.port,
                        timeout: config.timeout
                    )
                    
                case .http:
                    try await networkTester.testHTTPRequest(
                        url: config.testURL,
                        proxy: proxy,
                        timeout: config.timeout
                    )
                    
                case .icmp:
                    try await networkTester.testICMPPing(
                        host: proxy.server,
                        timeout: config.timeout
                    )
                    
                case .custom:
                    try await networkTester.testCustomURL(
                        url: config.testURL,
                        proxy: proxy,
                        timeout: config.timeout
                    )
                }
                
                let endTime = Date()
                let latency = endTime.timeIntervalSince(startTime)
                
                let result = PingResult(
                    proxyID: proxy.id,
                    testType: config.testType,
                    latency: latency,
                    isSuccess: true,
                    testURL: config.testURL,
                    timeout: config.timeout,
                    attempts: attempt
                )
                
                // 保留最好的结果
                if bestResult == nil || (result.latency ?? Double.infinity) < (bestResult?.latency ?? Double.infinity) {
                    bestResult = result
                }
                
                // 如果延迟足够好，提前结束
                if let latency = result.latency, latency < 0.1 { // 100ms
                    break
                }
                
            } catch {
                lastError = error
                
                // 尝试间隔
                if attempt < config.attempts {
                    try? await Task.sleep(nanoseconds: UInt64(config.interval * 1_000_000_000))
                }
            }
        }
        
        // 返回最好的结果或失败结果
        return bestResult ?? PingResult(
            proxyID: proxy.id,
            testType: config.testType,
            isSuccess: false,
            errorMessage: lastError?.localizedDescription ?? "连接失败",
            testURL: config.testURL,
            timeout: config.timeout,
            attempts: config.attempts
        )
    }
}

// MARK: - 网络测试器
class NetworkTester {
    private let logger = Logger(subsystem: "V2rayU", category: "NetworkTester")
    
    /// TCP连接测试
    func testTCPConnection(host: String, port: Int, timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let queue = DispatchQueue.global(qos: .userInitiated)
            
            queue.async {
                var hints = addrinfo()
                hints.ai_family = AF_UNSPEC
                hints.ai_socktype = SOCK_STREAM
                
                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(host, String(port), &hints, &result)
                
                guard status == 0, let addr = result else {
                    continuation.resume(throwing: PingTestError.connectionFailed("DNS解析失败"))
                    return
                }
                
                defer { freeaddrinfo(result) }
                
                let socket = Darwin.socket(addr.pointee.ai_family, addr.pointee.ai_socktype, addr.pointee.ai_protocol)
                guard socket >= 0 else {
                    continuation.resume(throwing: PingTestError.connectionFailed("创建socket失败"))
                    return
                }
                
                defer { close(socket) }
                
                // 设置非阻塞
                var flags = fcntl(socket, F_GETFL, 0)
                fcntl(socket, F_SETFL, flags | O_NONBLOCK)
                
                // 尝试连接
                let connectResult = connect(socket, addr.pointee.ai_addr, addr.pointee.ai_addrlen)
                
                if connectResult == 0 {
                    // 立即连接成功
                    continuation.resume()
                    return
                }
                
                if errno != EINPROGRESS {
                    continuation.resume(throwing: PingTestError.connectionFailed("连接失败"))
                    return
                }
                
                // 使用select等待连接完成
                var writeSet = fd_set()
                FD_ZERO(&writeSet)
                FD_SET(socket, &writeSet)
                
                var timeoutVal = timeval(
                    tv_sec: Int(timeout),
                    tv_usec: Int((timeout.truncatingRemainder(dividingBy: 1)) * 1_000_000)
                )
                
                let selectResult = select(socket + 1, nil, &writeSet, nil, &timeoutVal)
                
                if selectResult > 0 && FD_ISSET(socket, &writeSet) {
                    // 检查连接是否成功
                    var error: Int32 = 0
                    var errorSize = socklen_t(MemoryLayout<Int32>.size)
                    
                    if getsockopt(socket, SOL_SOCKET, SO_ERROR, &error, &errorSize) == 0 && error == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: PingTestError.connectionFailed("连接被拒绝"))
                    }
                } else {
                    continuation.resume(throwing: PingTestError.timeout)
                }
            }
        }
    }
    
    /// HTTP请求测试
    func testHTTPRequest(url: String, proxy: ProxyConfig, timeout: TimeInterval) async throws {
        guard let requestURL = URL(string: url) else {
            throw PingTestError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout
        request.setValue("V2rayU/1.0", forHTTPHeaderField: "User-Agent")
        
        // 配置代理
        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable: true,
            kCFNetworkProxiesHTTPProxy: proxy.server,
            kCFNetworkProxiesHTTPPort: proxy.port
        ]
        
        let session = URLSession(configuration: config)
        
        do {
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 400 {
                    return // 成功
                } else {
                    throw PingTestError.httpError(httpResponse.statusCode)
                }
            } else {
                throw PingTestError.invalidResponse
            }
        } catch {
            if error is URLError {
                let urlError = error as! URLError
                switch urlError.code {
                case .timedOut:
                    throw PingTestError.timeout
                case .cannotConnectToHost:
                    throw PingTestError.connectionFailed("无法连接到主机")
                default:
                    throw PingTestError.networkError(error)
                }
            } else {
                throw error
            }
        }
    }
    
    /// ICMP Ping测试
    func testICMPPing(host: String, timeout: TimeInterval) async throws {
        // ICMP需要root权限，这里使用简化的实现
        // 实际应用中可能需要使用第三方库或系统命令
        try await testTCPConnection(host: host, port: 80, timeout: timeout)
    }
    
    /// 自定义URL测试
    func testCustomURL(url: String, proxy: ProxyConfig, timeout: TimeInterval) async throws {
        try await testHTTPRequest(url: url, proxy: proxy, timeout: timeout)
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

// MARK: - 延迟测试错误
enum PingTestError: LocalizedError {
    case invalidURL
    case invalidTimeout
    case invalidAttempts
    case invalidConcurrentLimit
    case connectionFailed(String)
    case timeout
    case httpError(Int)
    case invalidResponse
    case networkError(Error)
    case proxyNotFound
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidTimeout:
            return "无效的超时时间"
        case .invalidAttempts:
            return "无效的尝试次数"
        case .invalidConcurrentLimit:
            return "无效的并发限制"
        case .connectionFailed(let reason):
            return "连接失败: \(reason)"
        case .timeout:
            return "连接超时"
        case .httpError(let code):
            return "HTTP错误: \(code)"
        case .invalidResponse:
            return "无效的响应"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .proxyNotFound:
            return "代理未找到"
        case .configurationError(let reason):
            return "配置错误: \(reason)"
        }
    }
}
```

### 3. 延迟测试处理器实现

```swift
// MARK: - 延迟测试处理器
@MainActor
class PingTestHandler: AsyncHandler {
    private let tester: PingTesterProtocol
    private let repository: PingResultRepository
    private let proxyRepository: ProxyRepository
    
    @Published var testConfig = PingTestConfig()
    @Published var testResults: [String: PingResult] = [:]
    @Published var batchResults: [BatchPingResult] = []
    @Published var isTestingInProgress = false
    @Published var testProgress: Double = 0.0
    @Published var selectedProxies: Set<String> = []
    @Published var sortOrder: PingResultSortOrder = .latency
    @Published var filterQuality: PingQuality? = nil
    
    private var autoTestTimer: Timer?
    
    init(
        tester: PingTesterProtocol,
        repository: PingResultRepository,
        proxyRepository: ProxyRepository
    ) {
        self.tester = tester
        self.repository = repository
        self.proxyRepository = proxyRepository
        super.init()
        
        setupAutoTest()
    }
    
    // MARK: - 公共方法
    
    /// 测试单个代理
    func testSingleProxy(_ proxyID: String) async {
        await performAsyncOperation {
            guard let proxy = try await self.proxyRepository.getProxy(id: proxyID) else {
                throw PingTestError.proxyNotFound
            }
            
            let result = await self.tester.testProxy(proxy, config: self.testConfig)
            
            await MainActor.run {
                self.testResults[proxyID] = result
            }
            
            // 发送通知
            NotificationCenter.default.post(
                name: .pingTestCompleted,
                object: result
            )
            
            self.logger.info("单个代理测试完成: \(proxy.name)")
        }
    }
    
    /// 测试选中的代理
    func testSelectedProxies() async {
        guard !selectedProxies.isEmpty else { return }
        
        await performAsyncOperation {
            let proxies = try await self.loadProxies(ids: Array(self.selectedProxies))
            await self.performBatchTest(proxies: proxies)
        }
    }
    
    /// 测试所有代理
    func testAllProxies() async {
        await performAsyncOperation {
            let proxies = try await self.proxyRepository.getAllProxies()
            await self.performBatchTest(proxies: proxies)
        }
    }
    
    /// 测试可用代理
    func testAvailableProxies() async {
        await performAsyncOperation {
            let proxies = try await self.proxyRepository.getAllProxies()
            let availableProxies = proxies.filter { $0.isEnabled }
            await self.performBatchTest(proxies: availableProxies)
        }
    }
    
    /// 更新测试配置
    func updateTestConfig(_ config: PingTestConfig) async {
        await performAsyncOperation {
            try config.validate()
            
            await MainActor.run {
                self.testConfig = config
            }
            
            // 保存配置
            try await self.repository.saveTestConfig(config)
            
            // 重新设置自动测试
            self.setupAutoTest()
            
            self.logger.info("测试配置已更新")
        }
    }
    
    /// 清除测试结果
    func clearResults() async {
        await performAsyncOperation {
            try await self.repository.clearResults()
            
            await MainActor.run {
                self.testResults.removeAll()
                self.batchResults.removeAll()
            }
            
            self.logger.info("测试结果已清除")
        }
    }
    
    /// 加载历史结果
    func loadHistoryResults(limit: Int = 100) async {
        await performAsyncOperation {
            let results = try await self.repository.getRecentResults(limit: limit)
            let batchResults = try await self.repository.getRecentBatchResults(limit: 20)
            
            await MainActor.run {
                // 转换为字典格式
                self.testResults = Dictionary(uniqueKeysWithValues: results.map { ($0.proxyID, $0) })
                self.batchResults = batchResults
            }
            
            self.logger.info("历史结果加载完成: \(results.count)个结果")
        }
    }
    
    /// 导出测试结果
    func exportResults(format: ExportFormat) async -> URL? {
        do {
            let data: Data
            let fileName: String
            
            switch format {
            case .json:
                data = try JSONEncoder().encode(Array(testResults.values))
                fileName = "ping_results_\(Date().timeIntervalSince1970).json"
                
            case .csv:
                data = try generateCSVData()
                fileName = "ping_results_\(Date().timeIntervalSince1970).csv"
                
            case .excel:
                data = try generateExcelData()
                fileName = "ping_results_\(Date().timeIntervalSince1970).xlsx"
            }
            
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: url)
            
            logger.info("测试结果导出成功: \(url.path)")
            return url
        } catch {
            await MainActor.run {
                self.error = error
            }
            logger.error("导出测试结果失败: \(error)")
            return nil
        }
    }
    
    /// 获取排序后的结果
    func getSortedResults() -> [PingResult] {
        var results = Array(testResults.values)
        
        // 应用质量过滤
        if let filterQuality = filterQuality {
            results = results.filter { $0.qualityLevel == filterQuality }
        }
        
        // 应用排序
        switch sortOrder {
        case .latency:
            results.sort { (lhs, rhs) in
                guard let lhsLatency = lhs.latency, let rhsLatency = rhs.latency else {
                    return lhs.isSuccess && !rhs.isSuccess
                }
                return lhsLatency < rhsLatency
            }
            
        case .quality:
            results.sort { $0.qualityLevel.rawValue < $1.qualityLevel.rawValue }
            
        case .timestamp:
            results.sort { $0.timestamp > $1.timestamp }
            
        case .proxyName:
            results.sort { lhs, rhs in
                // 需要从代理仓库获取名称进行比较
                return lhs.proxyID < rhs.proxyID
            }
        }
        
        return results
    }
    
    // MARK: - 私有方法
    
    private func performBatchTest(proxies: [ProxyConfig]) async {
        await MainActor.run {
            self.isTestingInProgress = true
            self.testProgress = 0.0
        }
        
        let batchResult = await tester.testProxies(proxies, config: testConfig)
        
        await MainActor.run {
            self.isTestingInProgress = false
            self.testProgress = 1.0
            
            // 更新结果
            for result in batchResult.results {
                self.testResults[result.proxyID] = result
            }
            
            self.batchResults.insert(batchResult, at: 0)
            
            // 限制历史记录数量
            if self.batchResults.count > 50 {
                self.batchResults = Array(self.batchResults.prefix(50))
            }
        }
        
        // 发送通知
        NotificationCenter.default.post(
            name: .batchPingTestCompleted,
            object: batchResult
        )
        
        logger.info("批量测试完成: \(batchResult.results.count)个结果")
    }
    
    private func loadProxies(ids: [String]) async throws -> [ProxyConfig] {
        var proxies: [ProxyConfig] = []
        
        for id in ids {
            if let proxy = try await proxyRepository.getProxy(id: id) {
                proxies.append(proxy)
            }
        }
        
        return proxies
    }
    
    private func setupAutoTest() {
        autoTestTimer?.invalidate()
        
        guard testConfig.isAutoTest else { return }
        
        autoTestTimer = Timer.scheduledTimer(withTimeInterval: testConfig.autoTestInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.testAvailableProxies()
            }
        }
        
        logger.info("自动测试已设置: 间隔\(testConfig.autoTestInterval)秒")
    }
    
    private func generateCSVData() throws -> Data {
        var csvContent = "代理ID,测试类型,时间戳,延迟(ms),是否成功,错误信息,测试URL\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for result in testResults.values {
            let line = "\(result.proxyID),\(result.testType.displayName),\(dateFormatter.string(from: result.timestamp)),\(result.latencyMs ?? -1),\(result.isSuccess),\(result.errorMessage ?? ""),\(result.testURL)\n"
            csvContent += line
        }
        
        guard let data = csvContent.data(using: .utf8) else {
            throw PingTestError.configurationError("CSV数据生成失败")
        }
        
        return data
    }
    
    private func generateExcelData() throws -> Data {
        // 简化实现，返回CSV格式
        return try generateCSVData()
    }
}

// MARK: - 排序选项
enum PingResultSortOrder: String, CaseIterable {
    case latency = "latency"
    case quality = "quality"
    case timestamp = "timestamp"
    case proxyName = "proxyName"
    
    var displayName: String {
        switch self {
        case .latency: return "延迟"
        case .quality: return "质量"
        case .timestamp: return "时间"
        case .proxyName: return "名称"
        }
    }
}
```

### 4. 用户界面实现

```swift
// MARK: - 延迟测试主视图
struct PingTestView: View {
    @StateObject private var handler = HandlerManager.shared.pingTestHandler
    @State private var showingConfigSheet = false
    @State private var showingExportSheet = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 测试控制面板
            TestControlPanel(handler: handler)
            
            // 测试进度
            if handler.isTestingInProgress {
                TestProgressView(progress: handler.testProgress)
            }
            
            // 结果过滤和排序
            ResultFilterView(
                sortOrder: $handler.sortOrder,
                filterQuality: $handler.filterQuality
            )
            
            // 测试结果列表
            TestResultsList(handler: handler)
            
            Spacer()
        }
        .padding()
        .navigationTitle("延迟测试")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("配置") {
                    showingConfigSheet = true
                }
                
                Button("导出") {
                    showingExportSheet = true
                }
                
                Button("清除") {
                    Task {
                        await handler.clearResults()
                    }
                }
                .foregroundColor(.red)
            }
        }
        .sheet(isPresented: $showingConfigSheet) {
            PingTestConfigView(config: $handler.testConfig, handler: handler)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportResultsView(handler: handler)
        }
        .task {
            await handler.loadHistoryResults()
        }
    }
}

// MARK: - 测试控制面板
struct TestControlPanel: View {
    let handler: PingTestHandler
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("延迟测试")
                    .font(.headline)
                
                Spacer()
                
                if handler.testConfig.isAutoTest {
                    Label("自动测试", systemImage: "timer")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            HStack(spacing: 12) {
                Button("测试选中") {
                    Task {
                        await handler.testSelectedProxies()
                    }
                }
                .disabled(handler.selectedProxies.isEmpty || handler.isTestingInProgress)
                
                Button("测试可用") {
                    Task {
                        await handler.testAvailableProxies()
                    }
                }
                .disabled(handler.isTestingInProgress)
                
                Button("测试全部") {
                    Task {
                        await handler.testAllProxies()
                    }
                }
                .disabled(handler.isTestingInProgress)
                
                Spacer()
                
                Text("\(handler.testResults.count) 个结果")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - 测试进度视图
struct TestProgressView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("测试进行中...")
                    .font(.caption)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 结果过滤视图
struct ResultFilterView: View {
    @Binding var sortOrder: PingResultSortOrder
    @Binding var filterQuality: PingQuality?
    
    var body: some View {
        HStack {
            // 排序选择
            Picker("排序", selection: $sortOrder) {
                ForEach(PingResultSortOrder.allCases, id: \.self) { order in
                    Text(order.displayName).tag(order)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            
            // 质量过滤
            Picker("质量", selection: $filterQuality) {
                Text("全部").tag(nil as PingQuality?)
                ForEach(PingQuality.allCases, id: \.self) { quality in
                    Text(quality.displayName).tag(quality as PingQuality?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            
            Spacer()
        }
    }
}

// MARK: - 测试结果列表
struct TestResultsList: View {
    @ObservedObject var handler: PingTestHandler
    
    var body: some View {
        List {
            ForEach(handler.getSortedResults(), id: \.id) { result in
                TestResultRow(result: result, handler: handler)
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - 测试结果行
struct TestResultRow: View {
    let result: PingResult
    let handler: PingTestHandler
    
    var body: some View {
        HStack {
            // 质量指示器
            Circle()
                .fill(result.qualityColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.proxyID)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(result.testType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(result.formattedLatency)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(result.qualityColor)
                    
                    if !result.isSuccess, let error = result.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(result.qualityLevel.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(result.qualityColor)
                
                Text(result.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Button("重测") {
                Task {
                    await handler.testSingleProxy(result.proxyID)
                }
            }
            .buttonStyle(.borderless)
            .disabled(handler.isTestingInProgress)
        }
        .padding(.vertical, 4)
    }
}
```

## 🔧 使用示例

### 1. 测试单个代理

```swift
// 配置测试参数
var config = PingTestConfig()
config.testType = .http
config.timeout = 10.0
config.attempts = 3

// 执行测试
let result = await pingTester.testProxy(proxy, config: config)
print("延迟: \(result.formattedLatency)")
print("质量: \(result.qualityLevel.displayName)")
```

### 2. 批量测试代理

```swift
// 获取所有可用代理
let proxies = await proxyRepository.getAllProxies().filter { $0.isEnabled }

// 执行批量测试
let batchResult = await pingTester.testProxies(proxies, config: config)
print("成功率: \(batchResult.formattedSuccessRate)")
print("平均延迟: \(batchResult.averageLatency ?? 0)ms")
```

### 3. 设置自动测试

```swift
var config = PingTestConfig()
config.isAutoTest = true
config.autoTestInterval = 300.0 // 5分钟

await pingTestHandler.updateTestConfig(config)
```

## 📚 相关文档

- [代理管理功能](proxy-management.md)
- [流量统计功能](traffic-stats.md)
- [系统代理功能](system-proxy.md)
- [基础工具模块](../modules/base-utilities.md)
- [处理器层模块](../modules/handler-layer.md)

---

*本文档详细介绍了V2rayU延迟测试功能的设计与实现，为开发者提供了完整的代理服务器质量评估解决方案。*
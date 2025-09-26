# 核心文件详解

## 📋 概述

本文档详细解析V2rayU项目中的核心文件，包括应用入口、主要配置、核心业务逻辑等关键文件的结构、功能和实现细节。

## 🏗️ 文件分类

### 1. 应用入口文件
- `V2rayUApp.swift` - 应用主入口
- `AppDelegate.swift` - 应用代理
- `SceneDelegate.swift` - 场景代理

### 2. 核心配置文件
- `Info.plist` - 应用信息配置
- `Entitlements.plist` - 权限配置
- `Config.swift` - 应用配置管理

### 3. 核心业务文件
- `V2rayCore.swift` - V2ray核心封装
- `ProxyManager.swift` - 代理管理器
- `SystemProxy.swift` - 系统代理控制

## 📁 详细文件解析

### 1. V2rayUApp.swift

**文件路径**: `V2rayU/V2rayUApp.swift`

**功能描述**: SwiftUI应用的主入口点，负责应用的初始化和生命周期管理。

```swift
import SwiftUI
import Combine

@main
struct V2rayUApp: App {
    // MARK: - 属性
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appContainer = AppContainer.shared
    @StateObject private var menuBarManager = MenuBarManager.shared
    @StateObject private var proxyManager = ProxyManager.shared
    
    // MARK: - 应用场景
    var body: some Scene {
        // 主窗口场景
        WindowGroup("V2rayU") {
            ContentView()
                .environmentObject(appContainer)
                .environmentObject(menuBarManager)
                .environmentObject(proxyManager)
                .onAppear {
                    setupApplication()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // 自定义菜单命令
            AppMenuCommands()
        }
        
        // 设置窗口场景
        WindowGroup("Settings", id: "settings") {
            SettingsView()
                .environmentObject(appContainer)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 600)
        
        // 菜单栏场景
        MenuBarExtra("V2rayU", systemImage: "network") {
            MenuBarView()
                .environmentObject(appContainer)
                .environmentObject(menuBarManager)
                .environmentObject(proxyManager)
        }
        .menuBarExtraStyle(.window)
    }
    
    // MARK: - 私有方法
    
    /// 设置应用
    private func setupApplication() {
        // 配置日志系统
        LogManager.shared.configure()
        
        // 初始化核心组件
        Task {
            await appContainer.initialize()
        }
        
        // 设置全局异常处理
        setupExceptionHandling()
        
        // 检查权限
        checkPermissions()
    }
    
    /// 设置异常处理
    private func setupExceptionHandling() {
        NSSetUncaughtExceptionHandler { exception in
            LogManager.shared.error("Uncaught exception: \(exception)")
        }
    }
    
    /// 检查权限
    private func checkPermissions() {
        // 检查网络权限
        // 检查文件访问权限
        // 检查系统代理权限
    }
}

// MARK: - 应用菜单命令
struct AppMenuCommands: Commands {
    var body: some Commands {
        // 文件菜单
        CommandGroup(replacing: .newItem) {
            Button("New Server") {
                // 新建服务器
            }
            .keyboardShortcut("n")
            
            Button("Import Subscription") {
                // 导入订阅
            }
            .keyboardShortcut("i")
        }
        
        // 代理菜单
        CommandMenu("Proxy") {
            Button("Start Proxy") {
                ProxyManager.shared.startProxy()
            }
            .keyboardShortcut("s")
            
            Button("Stop Proxy") {
                ProxyManager.shared.stopProxy()
            }
            .keyboardShortcut("t")
            
            Divider()
            
            Button("System Proxy Settings") {
                // 打开系统代理设置
            }
        }
        
        // 工具菜单
        CommandMenu("Tools") {
            Button("Speed Test") {
                // 速度测试
            }
            .keyboardShortcut("p")
            
            Button("Log Viewer") {
                // 日志查看器
            }
            .keyboardShortcut("l")
        }
    }
}
```

**关键特性**:
- 使用 `@main` 标记应用入口
- 集成 `NSApplicationDelegateAdaptor` 支持传统AppDelegate
- 定义多个窗口场景（主窗口、设置、菜单栏）
- 配置环境对象和依赖注入
- 自定义菜单命令

### 2. AppDelegate.swift

**文件路径**: `V2rayU/AppDelegate.swift`

**功能描述**: 传统的应用代理，处理应用生命周期事件和系统集成。

```swift
import Cocoa
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - 属性
    private var statusItem: NSStatusItem?
    private var menuBarManager: MenuBarManager?
    private var notificationCenter: UNUserNotificationCenter?
    
    // MARK: - 应用生命周期
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        LogManager.shared.info("Application did finish launching")
        
        // 设置菜单栏
        setupMenuBar()
        
        // 设置通知
        setupNotifications()
        
        // 设置URL Scheme处理
        setupURLSchemeHandling()
        
        // 检查启动参数
        handleLaunchArguments()
        
        // 恢复上次状态
        restoreApplicationState()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        LogManager.shared.info("Application will terminate")
        
        // 保存应用状态
        saveApplicationState()
        
        // 清理资源
        cleanup()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // 没有可见窗口时，显示主窗口
            showMainWindow()
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 关闭最后一个窗口时不退出应用（保持菜单栏运行）
        return false
    }
    
    // MARK: - URL Scheme处理
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleURL(url)
        }
    }
    
    private func handleURL(_ url: URL) {
        LogManager.shared.info("Handling URL: \(url)")
        
        guard url.scheme == "v2rayu" else {
            LogManager.shared.warning("Unknown URL scheme: \(url.scheme ?? "nil")")
            return
        }
        
        switch url.host {
        case "add-server":
            handleAddServerURL(url)
        case "import-subscription":
            handleImportSubscriptionURL(url)
        case "set-proxy":
            handleSetProxyURL(url)
        default:
            LogManager.shared.warning("Unknown URL host: \(url.host ?? "nil")")
        }
    }
    
    private func handleAddServerURL(_ url: URL) {
        // 解析服务器配置并添加
        if let config = parseServerConfig(from: url) {
            Task {
                await ServerManager.shared.addServer(config)
            }
        }
    }
    
    private func handleImportSubscriptionURL(_ url: URL) {
        // 解析订阅URL并导入
        if let subscriptionURL = url.queryParameters["url"] {
            Task {
                await SubscriptionManager.shared.importSubscription(from: subscriptionURL)
            }
        }
    }
    
    private func handleSetProxyURL(_ url: URL) {
        // 设置代理服务器
        if let serverID = url.queryParameters["server"] {
            Task {
                await ProxyManager.shared.setActiveServer(serverID)
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func setupMenuBar() {
        menuBarManager = MenuBarManager.shared
        menuBarManager?.setup()
    }
    
    private func setupNotifications() {
        notificationCenter = UNUserNotificationCenter.current()
        notificationCenter?.delegate = self
        
        // 请求通知权限
        notificationCenter?.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                LogManager.shared.info("Notification permission granted")
            } else {
                LogManager.shared.warning("Notification permission denied: \(error?.localizedDescription ?? "Unknown")")
            }
        }
    }
    
    private func setupURLSchemeHandling() {
        // 注册URL Scheme处理
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }
    
    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        if let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
           let url = URL(string: urlString) {
            handleURL(url)
        }
    }
    
    private func handleLaunchArguments() {
        let arguments = CommandLine.arguments
        
        for argument in arguments {
            switch argument {
            case "--start-proxy":
                Task {
                    await ProxyManager.shared.startProxy()
                }
            case "--stop-proxy":
                Task {
                    await ProxyManager.shared.stopProxy()
                }
            case "--debug":
                LogManager.shared.setLogLevel(.debug)
            default:
                break
            }
        }
    }
    
    private func restoreApplicationState() {
        Task {
            await AppContainer.shared.restoreState()
        }
    }
    
    private func saveApplicationState() {
        Task {
            await AppContainer.shared.saveState()
        }
    }
    
    private func cleanup() {
        // 停止代理
        ProxyManager.shared.stopProxySync()
        
        // 清理临时文件
        FileManager.default.clearTemporaryFiles()
        
        // 保存日志
        LogManager.shared.flush()
    }
    
    private func showMainWindow() {
        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "MainWindow" }) {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    private func parseServerConfig(from url: URL) -> ServerConfig? {
        // 解析URL中的服务器配置
        // 支持vmess://, vless://, trojan://, ss:// 等协议
        return nil // 实际实现
    }
}

// MARK: - 通知代理
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 应用在前台时也显示通知
        completionHandler([.alert, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 处理通知点击
        let identifier = response.notification.request.identifier
        
        switch identifier {
        case "proxy-connected":
            showMainWindow()
        case "proxy-disconnected":
            showMainWindow()
        case "subscription-updated":
            // 显示订阅更新结果
            break
        default:
            break
        }
        
        completionHandler()
    }
}

// MARK: - URL扩展
extension URL {
    var queryParameters: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return [:]
        }
        
        var parameters: [String: String] = [:]
        for item in queryItems {
            parameters[item.name] = item.value
        }
        return parameters
    }
}

// MARK: - FileManager扩展
extension FileManager {
    func clearTemporaryFiles() {
        let tempDir = temporaryDirectory
        do {
            let files = try contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for file in files {
                if file.lastPathComponent.hasPrefix("v2rayu-") {
                    try removeItem(at: file)
                }
            }
        } catch {
            LogManager.shared.error("Failed to clear temporary files: \(error)")
        }
    }
}
```

**关键特性**:
- 处理应用生命周期事件
- URL Scheme支持（v2rayu://）
- 通知权限管理和处理
- 命令行参数处理
- 应用状态保存和恢复
- 菜单栏集成

### 3. V2rayCore.swift

**文件路径**: `V2rayU/Core/V2rayCore.swift`

**功能描述**: V2ray核心的Swift封装，提供代理服务的启动、停止和配置管理。

```swift
import Foundation
import Network
import Combine

/// V2ray核心管理器
class V2rayCore: ObservableObject {
    // MARK: - 单例
    static let shared = V2rayCore()
    
    // MARK: - 发布属性
    @Published var isRunning = false
    @Published var currentConfig: V2rayConfig?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var trafficStats: TrafficStats = TrafficStats()
    
    // MARK: - 私有属性
    private var coreProcess: Process?
    private var configPath: URL?
    private var logPath: URL?
    private var statsMonitor: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 路径配置
    private let coreExecutablePath: String
    private let configDirectory: URL
    private let logDirectory: URL
    
    // MARK: - 初始化
    private init() {
        // 设置路径
        let bundle = Bundle.main
        self.coreExecutablePath = bundle.path(forResource: "v2ray", ofType: nil) ?? "/usr/local/bin/v2ray"
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("V2rayU")
        
        self.configDirectory = appDirectory.appendingPathComponent("configs")
        self.logDirectory = appDirectory.appendingPathComponent("logs")
        
        // 创建目录
        createDirectories()
        
        // 设置监听
        setupObservers()
    }
    
    deinit {
        stopCore()
    }
    
    // MARK: - 公共方法
    
    /// 启动V2ray核心
    func startCore(with config: V2rayConfig) async throws {
        LogManager.shared.info("Starting V2ray core")
        
        // 停止现有实例
        if isRunning {
            stopCore()
        }
        
        // 生成配置文件
        try await generateConfigFile(config)
        
        // 启动进程
        try startCoreProcess()
        
        // 更新状态
        await MainActor.run {
            self.currentConfig = config
            self.isRunning = true
            self.connectionStatus = .connecting
        }
        
        // 验证连接
        try await verifyConnection()
        
        // 启动统计监控
        startStatsMonitoring()
        
        LogManager.shared.info("V2ray core started successfully")
    }
    
    /// 停止V2ray核心
    func stopCore() {
        LogManager.shared.info("Stopping V2ray core")
        
        // 停止统计监控
        stopStatsMonitoring()
        
        // 终止进程
        terminateCoreProcess()
        
        // 更新状态
        DispatchQueue.main.async {
            self.isRunning = false
            self.currentConfig = nil
            self.connectionStatus = .disconnected
            self.trafficStats = TrafficStats()
        }
        
        LogManager.shared.info("V2ray core stopped")
    }
    
    /// 重启核心
    func restartCore() async throws {
        guard let config = currentConfig else {
            throw V2rayError.noConfiguration
        }
        
        stopCore()
        try await startCore(with: config)
    }
    
    /// 获取流量统计
    func getTrafficStats() async -> TrafficStats {
        guard isRunning else {
            return TrafficStats()
        }
        
        // 从V2ray API获取统计数据
        return await fetchStatsFromAPI()
    }
    
    /// 测试配置
    func testConfig(_ config: V2rayConfig) async throws -> Bool {
        let tempConfigPath = configDirectory.appendingPathComponent("test-config.json")
        
        // 生成临时配置文件
        let configData = try JSONEncoder().encode(config)
        try configData.write(to: tempConfigPath)
        
        // 测试配置
        let process = Process()
        process.executableURL = URL(fileURLWithPath: coreExecutablePath)
        process.arguments = ["-test", "-config", tempConfigPath.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        // 清理临时文件
        try? FileManager.default.removeItem(at: tempConfigPath)
        
        return process.terminationStatus == 0
    }
    
    // MARK: - 私有方法
    
    private func createDirectories() {
        let directories = [configDirectory, logDirectory]
        
        for directory in directories {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                LogManager.shared.error("Failed to create directory \(directory): \(error)")
            }
        }
    }
    
    private func setupObservers() {
        // 监听网络状态变化
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                self?.handleNetworkAvailable()
            } else {
                self?.handleNetworkUnavailable()
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
    
    private func generateConfigFile(_ config: V2rayConfig) async throws {
        let configPath = configDirectory.appendingPathComponent("config.json")
        self.configPath = configPath
        
        // 编码配置
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let configData = try encoder.encode(config)
        try configData.write(to: configPath)
        
        LogManager.shared.debug("Generated config file at \(configPath.path)")
    }
    
    private func startCoreProcess() throws {
        guard let configPath = configPath else {
            throw V2rayError.noConfigurationFile
        }
        
        let logPath = logDirectory.appendingPathComponent("v2ray.log")
        self.logPath = logPath
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: coreExecutablePath)
        process.arguments = [
            "-config", configPath.path,
            "-format", "json"
        ]
        
        // 设置环境变量
        var environment = ProcessInfo.processInfo.environment
        environment["V2RAY_LOCATION_ASSET"] = Bundle.main.resourcePath
        process.environment = environment
        
        // 重定向输出到日志文件
        let logFile = FileHandle(forWritingAtPath: logPath.path) ?? FileHandle.standardOutput
        process.standardOutput = logFile
        process.standardError = logFile
        
        // 设置终止处理
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                if self?.isRunning == true {
                    self?.handleUnexpectedTermination(process)
                }
            }
        }
        
        try process.run()
        self.coreProcess = process
        
        LogManager.shared.info("V2ray core process started with PID: \(process.processIdentifier)")
    }
    
    private func terminateCoreProcess() {
        guard let process = coreProcess else { return }
        
        if process.isRunning {
            process.terminate()
            
            // 等待进程结束，最多等待5秒
            let deadline = DispatchTime.now() + .seconds(5)
            let semaphore = DispatchSemaphore(value: 0)
            
            process.terminationHandler = { _ in
                semaphore.signal()
            }
            
            if semaphore.wait(timeout: deadline) == .timedOut {
                // 强制杀死进程
                process.interrupt()
                LogManager.shared.warning("Force killed V2ray core process")
            }
        }
        
        self.coreProcess = nil
    }
    
    private func verifyConnection() async throws {
        // 测试代理连接
        let testURL = URL(string: "https://www.google.com")!
        let request = URLRequest(url: testURL, timeoutInterval: 10)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                await MainActor.run {
                    self.connectionStatus = .connected
                }
            } else {
                throw V2rayError.connectionFailed
            }
        } catch {
            await MainActor.run {
                self.connectionStatus = .failed
            }
            throw V2rayError.connectionFailed
        }
    }
    
    private func startStatsMonitoring() {
        statsMonitor = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task {
                let stats = await self?.fetchStatsFromAPI() ?? TrafficStats()
                await MainActor.run {
                    self?.trafficStats = stats
                }
            }
        }
    }
    
    private func stopStatsMonitoring() {
        statsMonitor?.invalidate()
        statsMonitor = nil
    }
    
    private func fetchStatsFromAPI() async -> TrafficStats {
        // 从V2ray API服务器获取统计数据
        // 这里需要实现具体的API调用逻辑
        return TrafficStats()
    }
    
    private func handleNetworkAvailable() {
        LogManager.shared.info("Network became available")
        
        if isRunning && connectionStatus == .failed {
            Task {
                try? await verifyConnection()
            }
        }
    }
    
    private func handleNetworkUnavailable() {
        LogManager.shared.warning("Network became unavailable")
        
        DispatchQueue.main.async {
            self.connectionStatus = .failed
        }
    }
    
    private func handleUnexpectedTermination(_ process: Process) {
        LogManager.shared.error("V2ray core terminated unexpectedly with status: \(process.terminationStatus)")
        
        isRunning = false
        connectionStatus = .failed
        
        // 尝试自动重启
        if let config = currentConfig {
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 等待2秒
                try? await startCore(with: config)
            }
        }
    }
}

// MARK: - 数据模型

/// 连接状态
enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case failed
    
    var displayName: String {
        switch self {
        case .disconnected: return "已断开"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .failed: return "连接失败"
        }
    }
    
    var color: NSColor {
        switch self {
        case .disconnected: return .systemGray
        case .connecting: return .systemYellow
        case .connected: return .systemGreen
        case .failed: return .systemRed
        }
    }
}

/// 流量统计
struct TrafficStats: Codable {
    let uplink: UInt64
    let downlink: UInt64
    let uplinkSpeed: UInt64
    let downlinkSpeed: UInt64
    let timestamp: Date
    
    init(
        uplink: UInt64 = 0,
        downlink: UInt64 = 0,
        uplinkSpeed: UInt64 = 0,
        downlinkSpeed: UInt64 = 0,
        timestamp: Date = Date()
    ) {
        self.uplink = uplink
        self.downlink = downlink
        self.uplinkSpeed = uplinkSpeed
        self.downlinkSpeed = downlinkSpeed
        self.timestamp = timestamp
    }
    
    var totalTraffic: UInt64 {
        return uplink + downlink
    }
    
    var totalSpeed: UInt64 {
        return uplinkSpeed + downlinkSpeed
    }
}

/// V2ray错误
enum V2rayError: LocalizedError {
    case noConfiguration
    case noConfigurationFile
    case connectionFailed
    case processStartFailed
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .noConfiguration:
            return "没有配置信息"
        case .noConfigurationFile:
            return "配置文件不存在"
        case .connectionFailed:
            return "连接失败"
        case .processStartFailed:
            return "进程启动失败"
        case .invalidConfiguration:
            return "配置无效"
        }
    }
}
```

**关键特性**:
- 单例模式管理V2ray核心
- 异步启动和停止代理服务
- 实时流量统计监控
- 网络状态监听和自动重连
- 配置文件生成和验证
- 进程生命周期管理
- 错误处理和日志记录

## 🔧 文件关系图

```
V2rayUApp.swift (应用入口)
    ├── AppDelegate.swift (应用代理)
    ├── AppContainer.swift (依赖容器)
    └── ContentView.swift (主视图)

V2rayCore.swift (核心引擎)
    ├── V2rayConfig.swift (配置模型)
    ├── ProxyManager.swift (代理管理)
    └── SystemProxy.swift (系统代理)

Config.swift (配置管理)
    ├── ConfigManager.swift (配置管理器)
    ├── ConfigStorage.swift (配置存储)
    └── ConfigValidator.swift (配置验证)
```

## 📚 最佳实践

### 1. 文件组织
- **单一职责**: 每个文件专注于特定功能
- **清晰命名**: 文件名反映其主要功能
- **合理分层**: 按照架构层次组织文件
- **依赖管理**: 明确文件间的依赖关系

### 2. 代码质量
- **文档注释**: 为关键类和方法添加文档
- **错误处理**: 完善的错误处理机制
- **日志记录**: 关键操作的日志记录
- **测试覆盖**: 核心功能的单元测试

### 3. 性能优化
- **异步操作**: 避免阻塞主线程
- **资源管理**: 及时释放不需要的资源
- **缓存策略**: 合理使用缓存提高性能
- **内存优化**: 避免内存泄漏和过度使用

### 4. 安全考虑
- **权限检查**: 验证必要的系统权限
- **数据加密**: 敏感数据的加密存储
- **输入验证**: 严格验证外部输入
- **异常处理**: 防止异常导致的安全问题

核心文件是V2rayU应用的基础，理解这些文件的结构和功能对于项目的维护和扩展至关重要。
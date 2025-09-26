# 系统框架使用

## 📋 概述

本文档详细分析V2rayU应用中使用的macOS系统框架，包括Foundation、AppKit、SwiftUI、Network、Security等核心框架的使用方式和最佳实践。

---

## 🏗️ 核心系统框架

### Foundation Framework

**作用**：提供基础数据类型和系统服务  
**使用范围**：全应用  
**关键组件**：NSUserDefaults、FileManager、URLSession、Timer等

#### 文件系统操作

```swift
import Foundation

// 应用目录管理
class AppDirectoryManager {
    static let shared = AppDirectoryManager()
    
    private let fileManager = FileManager.default
    
    // 应用支持目录
    lazy var applicationSupportDirectory: URL = {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[0].appendingPathComponent("V2rayU")
        
        if !fileManager.fileExists(atPath: appSupportURL.path) {
            try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        }
        
        return appSupportURL
    }()
    
    // 配置文件目录
    lazy var configDirectory: URL = {
        let configURL = applicationSupportDirectory.appendingPathComponent("configs")
        
        if !fileManager.fileExists(atPath: configURL.path) {
            try? fileManager.createDirectory(at: configURL, withIntermediateDirectories: true)
        }
        
        return configURL
    }()
    
    // 日志目录
    lazy var logDirectory: URL = {
        let logURL = applicationSupportDirectory.appendingPathComponent("logs")
        
        if !fileManager.fileExists(atPath: logURL.path) {
            try? fileManager.createDirectory(at: logURL, withIntermediateDirectories: true)
        }
        
        return logURL
    }()
    
    // 备份目录
    lazy var backupDirectory: URL = {
        let backupURL = applicationSupportDirectory.appendingPathComponent("backups")
        
        if !fileManager.fileExists(atPath: backupURL.path) {
            try? fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)
        }
        
        return backupURL
    }()
    
    // 清理过期文件
    func cleanupExpiredFiles() {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date())!
        
        cleanupDirectory(logDirectory, olderThan: cutoffDate)
        cleanupDirectory(backupDirectory, olderThan: cutoffDate)
    }
    
    private func cleanupDirectory(_ directory: URL, olderThan date: Date) {
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.creationDateKey])
                if let creationDate = resourceValues.creationDate, creationDate < date {
                    try fileManager.removeItem(at: fileURL)
                }
            } catch {
                LogManager.shared.error("清理文件失败: \(error.localizedDescription)")
            }
        }
    }
}

// 用户偏好设置管理
class PreferencesManager {
    static let shared = PreferencesManager()
    private let userDefaults = UserDefaults.standard
    
    // 应用设置
    @UserDefault("launchAtLogin", defaultValue: false)
    var launchAtLogin: Bool
    
    @UserDefault("startMinimized", defaultValue: false)
    var startMinimized: Bool
    
    @UserDefault("autoUpdateSubscriptions", defaultValue: true)
    var autoUpdateSubscriptions: Bool
    
    @UserDefault("updateInterval", defaultValue: 86400)
    var updateInterval: Int
    
    @UserDefault("logLevel", defaultValue: "info")
    var logLevel: String
    
    @UserDefault("theme", defaultValue: "auto")
    var theme: String
    
    @UserDefault("language", defaultValue: "auto")
    var language: String
    
    // 网络设置
    @UserDefault("httpPort", defaultValue: 8080)
    var httpPort: Int
    
    @UserDefault("socksPort", defaultValue: 1080)
    var socksPort: Int
    
    @UserDefault("enableUDP", defaultValue: true)
    var enableUDP: Bool
    
    @UserDefault("dnsServers", defaultValue: ["8.8.8.8", "8.8.4.4"])
    var dnsServers: [String]
    
    // 导出设置
    func exportSettings() -> [String: Any] {
        return [
            "launchAtLogin": launchAtLogin,
            "startMinimized": startMinimized,
            "autoUpdateSubscriptions": autoUpdateSubscriptions,
            "updateInterval": updateInterval,
            "logLevel": logLevel,
            "theme": theme,
            "language": language,
            "httpPort": httpPort,
            "socksPort": socksPort,
            "enableUDP": enableUDP,
            "dnsServers": dnsServers
        ]
    }
    
    // 导入设置
    func importSettings(_ settings: [String: Any]) {
        launchAtLogin = settings["launchAtLogin"] as? Bool ?? false
        startMinimized = settings["startMinimized"] as? Bool ?? false
        autoUpdateSubscriptions = settings["autoUpdateSubscriptions"] as? Bool ?? true
        updateInterval = settings["updateInterval"] as? Int ?? 86400
        logLevel = settings["logLevel"] as? String ?? "info"
        theme = settings["theme"] as? String ?? "auto"
        language = settings["language"] as? String ?? "auto"
        httpPort = settings["httpPort"] as? Int ?? 8080
        socksPort = settings["socksPort"] as? Int ?? 1080
        enableUDP = settings["enableUDP"] as? Bool ?? true
        dnsServers = settings["dnsServers"] as? [String] ?? ["8.8.8.8", "8.8.4.4"]
    }
}

// UserDefault属性包装器
@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    
    var wrappedValue: T {
        get {
            return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}
```

#### 定时器和调度

```swift
// 定时任务管理器
class SchedulerManager {
    static let shared = SchedulerManager()
    
    private var timers: [String: Timer] = [:]
    private let queue = DispatchQueue(label: "com.yanue.V2rayU.scheduler", qos: .utility)
    
    // 订阅更新定时器
    func scheduleSubscriptionUpdate() {
        let interval = TimeInterval(PreferencesManager.shared.updateInterval)
        
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                await SubscriptionManager.shared.updateAllSubscriptions()
            }
        }
        
        timers["subscriptionUpdate"] = timer
    }
    
    // 统计数据收集定时器
    func scheduleStatsCollection() {
        let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            StatsManager.shared.collectCurrentStats()
        }
        
        timers["statsCollection"] = timer
    }
    
    // 日志清理定时器
    func scheduleLogCleanup() {
        let timer = Timer.scheduledTimer(withTimeInterval: 3600.0, repeats: true) { _ in
            AppDirectoryManager.shared.cleanupExpiredFiles()
        }
        
        timers["logCleanup"] = timer
    }
    
    // 停止定时器
    func stopTimer(_ name: String) {
        timers[name]?.invalidate()
        timers.removeValue(forKey: name)
    }
    
    // 停止所有定时器
    func stopAllTimers() {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
    }
}
```

---

### AppKit Framework

**作用**：macOS应用程序界面框架  
**使用范围**：菜单栏、窗口管理、系统集成  
**关键组件**：NSApplication、NSStatusBar、NSMenu、NSWindow等

#### 菜单栏应用实现

```swift
import AppKit

// 状态栏管理器
class StatusBarManager: NSObject {
    static let shared = StatusBarManager()
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: EventMonitor?
    
    override init() {
        super.init()
        setupStatusBar()
        setupPopover()
        setupEventMonitor()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(named: "StatusBarIcon")
            button.image?.isTemplate = true
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 360, height: 500)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MainContentView())
    }
    
    private func setupEventMonitor() {
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let popover = self?.popover, popover.isShown {
                self?.closePopover()
            }
        }
    }
    
    @objc private func statusBarButtonClicked() {
        guard let event = NSApp.currentEvent else { return }
        
        switch event.type {
        case .leftMouseUp:
            togglePopover()
        case .rightMouseUp:
            showContextMenu()
        default:
            break
        }
    }
    
    private func togglePopover() {
        if let popover = popover {
            if popover.isShown {
                closePopover()
            } else {
                showPopover()
            }
        }
    }
    
    private func showPopover() {
        if let button = statusItem?.button, let popover = popover {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor?.start()
        }
    }
    
    private func closePopover() {
        popover?.performClose(nil)
        eventMonitor?.stop()
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "显示主窗口", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let connectItem = NSMenuItem(title: "连接", action: #selector(toggleConnection), keyEquivalent: "")
        connectItem.state = ConnectionManager.shared.isConnected ? .on : .off
        menu.addItem(connectItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "偏好设置", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "关于 V2rayU", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc private func toggleConnection() {
        Task {
            if ConnectionManager.shared.isConnected {
                await ConnectionManager.shared.disconnect()
            } else {
                await ConnectionManager.shared.connect()
            }
        }
    }
    
    @objc private func showPreferences() {
        PreferencesWindowController.shared.showWindow(nil)
    }
    
    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
    
    // 更新状态栏图标
    func updateStatusBarIcon(connected: Bool) {
        DispatchQueue.main.async {
            let iconName = connected ? "StatusBarIconConnected" : "StatusBarIcon"
            self.statusItem?.button?.image = NSImage(named: iconName)
        }
    }
}

// 事件监控器
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }
}
```

#### 窗口管理

```swift
// 窗口管理器
class WindowManager {
    static let shared = WindowManager()
    
    private var mainWindow: NSWindow?
    private var preferencesWindow: NSWindow?
    
    func setupMainWindow() {
        let contentView = MainContentView()
        
        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        mainWindow?.title = "V2rayU"
        mainWindow?.contentView = NSHostingView(rootView: contentView)
        mainWindow?.center()
        mainWindow?.setFrameAutosaveName("MainWindow")
        
        // 设置窗口委托
        mainWindow?.delegate = self
    }
    
    func showMainWindow() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideMainWindow() {
        mainWindow?.orderOut(nil)
    }
    
    func setupPreferencesWindow() {
        let contentView = PreferencesView()
        
        preferencesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        preferencesWindow?.title = "偏好设置"
        preferencesWindow?.contentView = NSHostingView(rootView: contentView)
        preferencesWindow?.center()
    }
    
    func showPreferencesWindow() {
        if preferencesWindow == nil {
            setupPreferencesWindow()
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }
}

// 窗口委托
extension WindowManager: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == mainWindow {
            // 主窗口关闭时隐藏而不是退出
            hideMainWindow()
            return false
        }
        return true
    }
    
    func windowDidMiniaturize(_ notification: Notification) {
        // 窗口最小化时的处理
    }
    
    func windowDidDeminiaturize(_ notification: Notification) {
        // 窗口恢复时的处理
    }
}
```

---

### Network Framework

**作用**：现代网络编程框架  
**使用范围**：网络连接监控、代理检测  
**关键组件**：NWPathMonitor、NWConnection等

#### 网络状态监控

```swift
import Network

// 网络监控器
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive = false
    @Published var isConstrained = false
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func updateNetworkStatus(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
        
        LogManager.shared.info("网络状态更新: 连接=\(isConnected), 类型=\(connectionType)")
    }
    
    deinit {
        monitor.cancel()
    }
}

enum ConnectionType {
    case wifi
    case cellular
    case ethernet
    case unknown
    
    var description: String {
        switch self {
        case .wifi: return "Wi-Fi"
        case .cellular: return "蜂窝网络"
        case .ethernet: return "以太网"
        case .unknown: return "未知"
        }
    }
}

// 连接测试器
class ConnectionTester {
    static func testConnection(to host: String, port: UInt16) async -> ConnectionTestResult {
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        
        return await withCheckedContinuation { continuation in
            let startTime = Date()
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let latency = Date().timeIntervalSince(startTime) * 1000
                    connection.cancel()
                    continuation.resume(returning: ConnectionTestResult(
                        success: true,
                        latency: latency,
                        error: nil
                    ))
                case .failed(let error):
                    connection.cancel()
                    continuation.resume(returning: ConnectionTestResult(
                        success: false,
                        latency: 0,
                        error: error
                    ))
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            // 超时处理
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                connection.cancel()
                continuation.resume(returning: ConnectionTestResult(
                    success: false,
                    latency: 0,
                    error: ConnectionTestError.timeout
                ))
            }
        }
    }
}

struct ConnectionTestResult {
    let success: Bool
    let latency: TimeInterval
    let error: Error?
}

enum ConnectionTestError: Error {
    case timeout
    case unreachable
    case invalidHost
}
```

---

### Security Framework

**作用**：安全服务和加密功能  
**使用范围**：证书验证、密钥管理、系统代理  
**关键组件**：SecKeychain、SecCertificate、Authorization等

#### 系统代理管理

```swift
import Security
import SystemConfiguration

// 系统代理管理器
class SystemProxyManager {
    static let shared = SystemProxyManager()
    
    private let authRef: AuthorizationRef?
    
    init() {
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(nil, nil, [], &authRef)
        
        if status == errAuthorizationSuccess {
            self.authRef = authRef
        } else {
            self.authRef = nil
            LogManager.shared.error("授权创建失败: \(status)")
        }
    }
    
    deinit {
        if let authRef = authRef {
            AuthorizationFree(authRef, [])
        }
    }
    
    // 设置HTTP代理
    func setHTTPProxy(host: String, port: Int, enabled: Bool = true) -> Bool {
        guard let authRef = authRef else { return false }
        
        let proxySettings: [String: Any] = [
            kCFNetworkProxiesHTTPEnable as String: enabled,
            kCFNetworkProxiesHTTPProxy as String: host,
            kCFNetworkProxiesHTTPPort as String: port
        ]
        
        return setProxySettings(proxySettings, authRef: authRef)
    }
    
    // 设置SOCKS代理
    func setSOCKSProxy(host: String, port: Int, enabled: Bool = true) -> Bool {
        guard let authRef = authRef else { return false }
        
        let proxySettings: [String: Any] = [
            kCFNetworkProxiesSOCKSEnable as String: enabled,
            kCFNetworkProxiesSOCKSProxy as String: host,
            kCFNetworkProxiesSOCKSPort as String: port
        ]
        
        return setProxySettings(proxySettings, authRef: authRef)
    }
    
    // 清除代理设置
    func clearProxy() -> Bool {
        guard let authRef = authRef else { return false }
        
        let proxySettings: [String: Any] = [
            kCFNetworkProxiesHTTPEnable as String: false,
            kCFNetworkProxiesHTTPSEnable as String: false,
            kCFNetworkProxiesSOCKSEnable as String: false
        ]
        
        return setProxySettings(proxySettings, authRef: authRef)
    }
    
    private func setProxySettings(_ settings: [String: Any], authRef: AuthorizationRef) -> Bool {
        guard let dynamicStore = SCDynamicStoreCreate(nil, "V2rayU" as CFString, nil, nil) else {
            return false
        }
        
        let key = SCDynamicStoreKeyCreateNetworkGlobalEntity(nil, kSCDynamicStoreDomainState, kSCEntNetProxies)
        
        let success = SCDynamicStoreSetValue(dynamicStore, key, settings as CFDictionary)
        
        if success {
            LogManager.shared.info("代理设置已更新")
        } else {
            LogManager.shared.error("代理设置更新失败")
        }
        
        return success
    }
    
    // 获取当前代理设置
    func getCurrentProxySettings() -> [String: Any]? {
        guard let dynamicStore = SCDynamicStoreCreate(nil, "V2rayU" as CFString, nil, nil) else {
            return nil
        }
        
        let key = SCDynamicStoreKeyCreateNetworkGlobalEntity(nil, kSCDynamicStoreDomainState, kSCEntNetProxies)
        
        guard let settings = SCDynamicStoreCopyValue(dynamicStore, key) else {
            return nil
        }
        
        return settings as? [String: Any]
    }
}
```

#### 钥匙串管理

```swift
// 钥匙串管理器
class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.yanue.V2rayU"
    
    // 存储密码
    func storePassword(_ password: String, for account: String) -> Bool {
        let passwordData = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData
        ]
        
        // 删除现有项目
        SecItemDelete(query as CFDictionary)
        
        // 添加新项目
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            LogManager.shared.info("密码已存储到钥匙串")
            return true
        } else {
            LogManager.shared.error("密码存储失败: \(status)")
            return false
        }
    }
    
    // 获取密码
    func getPassword(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let passwordData = result as? Data,
           let password = String(data: passwordData, encoding: .utf8) {
            return password
        } else {
            LogManager.shared.error("密码获取失败: \(status)")
            return nil
        }
    }
    
    // 删除密码
    func deletePassword(for account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            LogManager.shared.info("密码已从钥匙串删除")
            return true
        } else {
            LogManager.shared.error("密码删除失败: \(status)")
            return false
        }
    }
    
    // 更新密码
    func updatePassword(_ password: String, for account: String) -> Bool {
        let passwordData = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: passwordData
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if status == errSecSuccess {
            LogManager.shared.info("密码已更新")
            return true
        } else {
            // 如果更新失败，尝试添加新项目
            return storePassword(password, for: account)
        }
    }
}
```

---

### SwiftUI Framework

**作用**：声明式用户界面框架  
**使用范围**：主要用户界面  
**关键组件**：View、State、ObservableObject等

#### 主题和外观管理

```swift
import SwiftUI

// 主题管理器
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme = .auto {
        didSet {
            applyTheme()
            PreferencesManager.shared.theme = currentTheme.rawValue
        }
    }
    
    @Published var isDarkMode: Bool = false
    
    private init() {
        let savedTheme = PreferencesManager.shared.theme
        currentTheme = AppTheme(rawValue: savedTheme) ?? .auto
        updateTheme()
    }
    
    private func applyTheme() {
        switch currentTheme {
        case .light:
            isDarkMode = false
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            isDarkMode = true
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .auto:
            updateSystemTheme()
        }
    }
    
    private func updateSystemTheme() {
        let systemAppearance = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        isDarkMode = systemAppearance == .darkAqua
        NSApp.appearance = nil // 使用系统外观
    }
    
    private func updateTheme() {
        applyTheme()
        
        // 监听系统外观变化
        DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if self?.currentTheme == .auto {
                self?.updateSystemTheme()
            }
        }
    }
}

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"
    
    var displayName: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        case .auto: return "跟随系统"
        }
    }
}

// 自定义颜色
extension Color {
    static let primaryBackground = Color("PrimaryBackground")
    static let secondaryBackground = Color("SecondaryBackground")
    static let primaryText = Color("PrimaryText")
    static let secondaryText = Color("SecondaryText")
    static let accent = Color("AccentColor")
    static let success = Color("SuccessColor")
    static let warning = Color("WarningColor")
    static let error = Color("ErrorColor")
}
```

---

## 🔗 相关文档

- [Swift包依赖分析](swift-packages.md)
- [第三方库分析](third-party-libs.md)
- [应用架构模块](../modules/app-architecture.md)
- [视图层模块](../modules/view-layer.md)

---

## 📝 总结

V2rayU应用充分利用了macOS系统框架的强大功能，通过合理的架构设计和最佳实践，实现了高效、安全、用户友好的代理管理应用。

### 框架使用特点

1. **系统集成**：深度集成macOS系统功能
2. **安全优先**：充分利用系统安全框架
3. **性能优化**：使用现代异步编程模式
4. **用户体验**：遵循macOS设计规范
5. **可维护性**：清晰的架构和代码组织

### 最佳实践

1. **权限管理**：合理请求和使用系统权限
2. **资源管理**：及时释放系统资源
3. **错误处理**：完善的错误处理机制
4. **性能监控**：持续监控应用性能
5. **安全防护**：多层次的安全保护措施

通过系统框架的合理使用，V2rayU应用在功能完整性、性能表现、安全性等方面都达到了较高的水准。
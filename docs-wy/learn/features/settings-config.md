# 设置配置功能详解

## 📋 概述

设置配置功能是V2rayU的核心管理模块，提供全面的应用配置管理能力。该功能涵盖代理设置、网络配置、界面定制、安全选项、高级参数等各个方面，为用户提供灵活的个性化配置体验。

## 🎯 功能特性

### 1. 配置分类
- **通用设置**: 启动选项、语言、主题、通知等基础配置
- **代理设置**: 默认代理、自动切换、负载均衡等代理相关配置
- **网络设置**: DNS、路由、超时、重试等网络参数配置
- **安全设置**: 认证、加密、证书验证等安全相关配置
- **界面设置**: 主题、字体、布局、快捷键等界面定制配置
- **高级设置**: 调试选项、实验性功能、性能优化等高级配置

### 2. 配置管理
- ✅ 配置导入导出
- ✅ 配置备份恢复
- ✅ 配置同步
- ✅ 配置验证
- ✅ 配置重置
- ✅ 配置历史记录
- ✅ 配置模板
- ✅ 实时配置应用

### 3. 核心功能
- ✅ 分类配置管理
- ✅ 配置搜索过滤
- ✅ 配置依赖检查
- ✅ 配置冲突检测
- ✅ 配置性能优化
- ✅ 配置安全验证
- ✅ 配置变更通知
- ✅ 配置预设方案

## 🏗️ 架构设计

### 1. 组件关系图

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  SettingsView   │────│ SettingsHandler │────│ ConfigManager   │
│  (UI Layer)     │    │(Business Logic) │    │ (Core Service)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ CategoryView    │    │ ConfigValidator │    │ ConfigStorage   │
│ SettingRowView  │    │ ConfigExporter  │    │ ConfigMigrator  │
│ AdvancedView    │    │ ConfigImporter  │    │ ConfigWatcher   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 2. 配置处理流程

```
用户输入 → 配置验证 → 依赖检查 → 冲突检测 → 应用配置 → 持久化存储
    ↓           ↓           ↓           ↓           ↓           ↓
界面交互 → 数据校验 → 关联验证 → 冲突解决 → 实时生效 → 文件保存
```

## 💻 核心实现

### 1. 配置数据模型

```swift
// MARK: - 应用配置
struct AppConfig: Codable, Equatable {
    var general: GeneralConfig
    var proxy: ProxyConfig
    var network: NetworkConfig
    var security: SecurityConfig
    var ui: UIConfig
    var advanced: AdvancedConfig
    
    // 元数据
    let version: String
    let createdAt: Date
    var updatedAt: Date
    var configId: String
    
    init() {
        self.general = GeneralConfig()
        self.proxy = ProxyConfig()
        self.network = NetworkConfig()
        self.security = SecurityConfig()
        self.ui = UIConfig()
        self.advanced = AdvancedConfig()
        
        self.version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        self.createdAt = Date()
        self.updatedAt = Date()
        self.configId = UUID().uuidString
    }
    
    // MARK: - 配置验证
    
    func validate() throws {
        try general.validate()
        try proxy.validate()
        try network.validate()
        try security.validate()
        try ui.validate()
        try advanced.validate()
        
        // 跨配置验证
        try validateCrossConfig()
    }
    
    private func validateCrossConfig() throws {
        // 检查代理和网络配置的兼容性
        if proxy.enableLoadBalancing && network.connectionTimeout < 5 {
            throw ConfigError.invalidConfiguration("负载均衡模式下连接超时不能小于5秒")
        }
        
        // 检查安全和代理配置的兼容性
        if security.strictTLSVerification && proxy.allowInsecureConnections {
            throw ConfigError.conflictingSettings("严格TLS验证与允许不安全连接冲突")
        }
    }
    
    // MARK: - 配置合并
    
    mutating func merge(with other: AppConfig) {
        general.merge(with: other.general)
        proxy.merge(with: other.proxy)
        network.merge(with: other.network)
        security.merge(with: other.security)
        ui.merge(with: other.ui)
        advanced.merge(with: other.advanced)
        
        updatedAt = Date()
    }
    
    // MARK: - 配置重置
    
    mutating func reset(category: ConfigCategory? = nil) {
        if let category = category {
            switch category {
            case .general:
                general = GeneralConfig()
            case .proxy:
                proxy = ProxyConfig()
            case .network:
                network = NetworkConfig()
            case .security:
                security = SecurityConfig()
            case .ui:
                ui = UIConfig()
            case .advanced:
                advanced = AdvancedConfig()
            }
        } else {
            // 重置所有配置
            general = GeneralConfig()
            proxy = ProxyConfig()
            network = NetworkConfig()
            security = SecurityConfig()
            ui = UIConfig()
            advanced = AdvancedConfig()
        }
        
        updatedAt = Date()
    }
}

// MARK: - 通用配置
struct GeneralConfig: Codable, Equatable {
    var launchAtStartup: Bool = false
    var startMinimized: Bool = false
    var showInDock: Bool = true
    var showInMenuBar: Bool = true
    var language: AppLanguage = .system
    var theme: AppTheme = .system
    var enableNotifications: Bool = true
    var notificationSound: Bool = true
    var checkUpdatesAutomatically: Bool = true
    var updateChannel: UpdateChannel = .stable
    var enableAnalytics: Bool = false
    var enableCrashReporting: Bool = true
    
    func validate() throws {
        // 验证通用配置
        if !showInDock && !showInMenuBar {
            throw ConfigError.invalidConfiguration("必须至少显示在Dock或菜单栏中的一个")
        }
    }
    
    mutating func merge(with other: GeneralConfig) {
        launchAtStartup = other.launchAtStartup
        startMinimized = other.startMinimized
        showInDock = other.showInDock
        showInMenuBar = other.showInMenuBar
        language = other.language
        theme = other.theme
        enableNotifications = other.enableNotifications
        notificationSound = other.notificationSound
        checkUpdatesAutomatically = other.checkUpdatesAutomatically
        updateChannel = other.updateChannel
        enableAnalytics = other.enableAnalytics
        enableCrashReporting = other.enableCrashReporting
    }
}

// MARK: - 代理配置
struct ProxyConfig: Codable, Equatable {
    var defaultProxyId: String?
    var enableAutoSwitch: Bool = false
    var autoSwitchInterval: TimeInterval = 300 // 5分钟
    var enableLoadBalancing: Bool = false
    var loadBalancingStrategy: LoadBalancingStrategy = .roundRobin
    var enableFailover: Bool = true
    var failoverTimeout: TimeInterval = 10
    var maxRetryAttempts: Int = 3
    var retryInterval: TimeInterval = 5
    var allowInsecureConnections: Bool = false
    var enableProxyChain: Bool = false
    var proxyChainOrder: [String] = []
    var enableTrafficShaping: Bool = false
    var maxBandwidth: Int = 0 // 0表示无限制，单位KB/s
    
    func validate() throws {
        if autoSwitchInterval < 60 {
            throw ConfigError.invalidValue("自动切换间隔不能小于60秒")
        }
        
        if failoverTimeout < 1 || failoverTimeout > 60 {
            throw ConfigError.invalidValue("故障转移超时必须在1-60秒之间")
        }
        
        if maxRetryAttempts < 0 || maxRetryAttempts > 10 {
            throw ConfigError.invalidValue("最大重试次数必须在0-10之间")
        }
        
        if retryInterval < 1 || retryInterval > 30 {
            throw ConfigError.invalidValue("重试间隔必须在1-30秒之间")
        }
        
        if maxBandwidth < 0 {
            throw ConfigError.invalidValue("最大带宽不能为负数")
        }
    }
    
    mutating func merge(with other: ProxyConfig) {
        defaultProxyId = other.defaultProxyId
        enableAutoSwitch = other.enableAutoSwitch
        autoSwitchInterval = other.autoSwitchInterval
        enableLoadBalancing = other.enableLoadBalancing
        loadBalancingStrategy = other.loadBalancingStrategy
        enableFailover = other.enableFailover
        failoverTimeout = other.failoverTimeout
        maxRetryAttempts = other.maxRetryAttempts
        retryInterval = other.retryInterval
        allowInsecureConnections = other.allowInsecureConnections
        enableProxyChain = other.enableProxyChain
        proxyChainOrder = other.proxyChainOrder
        enableTrafficShaping = other.enableTrafficShaping
        maxBandwidth = other.maxBandwidth
    }
}

// MARK: - 网络配置
struct NetworkConfig: Codable, Equatable {
    var dnsServers: [String] = ["8.8.8.8", "8.8.4.4"]
    var enableDoH: Bool = false
    var dohURL: String = "https://cloudflare-dns.com/dns-query"
    var enableDoT: Bool = false
    var dotServer: String = "cloudflare-dns.com"
    var connectionTimeout: TimeInterval = 10
    var readTimeout: TimeInterval = 30
    var writeTimeout: TimeInterval = 30
    var keepAliveInterval: TimeInterval = 60
    var maxConcurrentConnections: Int = 100
    var enableTCPFastOpen: Bool = false
    var enableMultipath: Bool = false
    var mtu: Int = 1500
    var bufferSize: Int = 32768
    var enableIPv6: Bool = true
    var preferIPv4: Bool = false
    
    func validate() throws {
        // 验证DNS服务器
        for dns in dnsServers {
            if !isValidIPAddress(dns) {
                throw ConfigError.invalidValue("无效的DNS服务器地址: \(dns)")
            }
        }
        
        // 验证DoH URL
        if enableDoH {
            guard URL(string: dohURL) != nil else {
                throw ConfigError.invalidValue("无效的DoH URL: \(dohURL)")
            }
        }
        
        // 验证超时设置
        if connectionTimeout < 1 || connectionTimeout > 120 {
            throw ConfigError.invalidValue("连接超时必须在1-120秒之间")
        }
        
        if readTimeout < 1 || readTimeout > 300 {
            throw ConfigError.invalidValue("读取超时必须在1-300秒之间")
        }
        
        if writeTimeout < 1 || writeTimeout > 300 {
            throw ConfigError.invalidValue("写入超时必须在1-300秒之间")
        }
        
        // 验证连接数
        if maxConcurrentConnections < 1 || maxConcurrentConnections > 1000 {
            throw ConfigError.invalidValue("最大并发连接数必须在1-1000之间")
        }
        
        // 验证MTU
        if mtu < 576 || mtu > 9000 {
            throw ConfigError.invalidValue("MTU必须在576-9000之间")
        }
        
        // 验证缓冲区大小
        if bufferSize < 1024 || bufferSize > 1048576 {
            throw ConfigError.invalidValue("缓冲区大小必须在1KB-1MB之间")
        }
    }
    
    private func isValidIPAddress(_ ip: String) -> Bool {
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()
        
        return ip.withCString { cstring in
            inet_pton(AF_INET, cstring, &sin.sin_addr) == 1 ||
            inet_pton(AF_INET6, cstring, &sin6.sin6_addr) == 1
        }
    }
    
    mutating func merge(with other: NetworkConfig) {
        dnsServers = other.dnsServers
        enableDoH = other.enableDoH
        dohURL = other.dohURL
        enableDoT = other.enableDoT
        dotServer = other.dotServer
        connectionTimeout = other.connectionTimeout
        readTimeout = other.readTimeout
        writeTimeout = other.writeTimeout
        keepAliveInterval = other.keepAliveInterval
        maxConcurrentConnections = other.maxConcurrentConnections
        enableTCPFastOpen = other.enableTCPFastOpen
        enableMultipath = other.enableMultipath
        mtu = other.mtu
        bufferSize = other.bufferSize
        enableIPv6 = other.enableIPv6
        preferIPv4 = other.preferIPv4
    }
}

// MARK: - 安全配置
struct SecurityConfig: Codable, Equatable {
    var enableTLSVerification: Bool = true
    var strictTLSVerification: Bool = false
    var allowSelfSignedCertificates: Bool = false
    var customCertificatePath: String?
    var enableCertificatePinning: Bool = false
    var pinnedCertificates: [String] = []
    var enableOCSP: Bool = true
    var enableCRL: Bool = false
    var minTLSVersion: TLSVersion = .v1_2
    var maxTLSVersion: TLSVersion = .v1_3
    var cipherSuites: [String] = []
    var enablePerfectForwardSecrecy: Bool = true
    var enableHSTS: Bool = true
    var enableDNSSEC: Bool = false
    var enableFirewall: Bool = false
    var firewallRules: [FirewallRule] = []
    
    func validate() throws {
        // 验证证书路径
        if let certPath = customCertificatePath, !certPath.isEmpty {
            if !FileManager.default.fileExists(atPath: certPath) {
                throw ConfigError.invalidValue("证书文件不存在: \(certPath)")
            }
        }
        
        // 验证TLS版本
        if minTLSVersion.rawValue > maxTLSVersion.rawValue {
            throw ConfigError.invalidConfiguration("最小TLS版本不能大于最大TLS版本")
        }
        
        // 验证证书固定
        if enableCertificatePinning && pinnedCertificates.isEmpty {
            throw ConfigError.invalidConfiguration("启用证书固定时必须提供至少一个证书")
        }
    }
    
    mutating func merge(with other: SecurityConfig) {
        enableTLSVerification = other.enableTLSVerification
        strictTLSVerification = other.strictTLSVerification
        allowSelfSignedCertificates = other.allowSelfSignedCertificates
        customCertificatePath = other.customCertificatePath
        enableCertificatePinning = other.enableCertificatePinning
        pinnedCertificates = other.pinnedCertificates
        enableOCSP = other.enableOCSP
        enableCRL = other.enableCRL
        minTLSVersion = other.minTLSVersion
        maxTLSVersion = other.maxTLSVersion
        cipherSuites = other.cipherSuites
        enablePerfectForwardSecrecy = other.enablePerfectForwardSecrecy
        enableHSTS = other.enableHSTS
        enableDNSSEC = other.enableDNSSEC
        enableFirewall = other.enableFirewall
        firewallRules = other.firewallRules
    }
}

// MARK: - 界面配置
struct UIConfig: Codable, Equatable {
    var theme: AppTheme = .system
    var accentColor: String = "blue"
    var fontSize: FontSize = .medium
    var fontFamily: String = "system"
    var showStatusInMenuBar: Bool = true
    var menuBarDisplayMode: MenuBarDisplayMode = .icon
    var showNotificationBadge: Bool = true
    var enableAnimations: Bool = true
    var animationSpeed: AnimationSpeed = .normal
    var windowOpacity: Double = 1.0
    var enableBlur: Bool = false
    var compactMode: Bool = false
    var showAdvancedOptions: Bool = false
    var customCSS: String = ""
    var shortcuts: [String: String] = [:]
    
    func validate() throws {
        // 验证透明度
        if windowOpacity < 0.1 || windowOpacity > 1.0 {
            throw ConfigError.invalidValue("窗口透明度必须在0.1-1.0之间")
        }
        
        // 验证自定义CSS
        if !customCSS.isEmpty {
            // 简单的CSS语法检查
            if customCSS.contains("<script") || customCSS.contains("javascript:") {
                throw ConfigError.invalidValue("自定义CSS不能包含脚本代码")
            }
        }
    }
    
    mutating func merge(with other: UIConfig) {
        theme = other.theme
        accentColor = other.accentColor
        fontSize = other.fontSize
        fontFamily = other.fontFamily
        showStatusInMenuBar = other.showStatusInMenuBar
        menuBarDisplayMode = other.menuBarDisplayMode
        showNotificationBadge = other.showNotificationBadge
        enableAnimations = other.enableAnimations
        animationSpeed = other.animationSpeed
        windowOpacity = other.windowOpacity
        enableBlur = other.enableBlur
        compactMode = other.compactMode
        showAdvancedOptions = other.showAdvancedOptions
        customCSS = other.customCSS
        shortcuts = other.shortcuts
    }
}

// MARK: - 高级配置
struct AdvancedConfig: Codable, Equatable {
    var enableDebugMode: Bool = false
    var logLevel: LogLevel = .info
    var maxLogFileSize: Int = 10 // MB
    var logRetentionDays: Int = 7
    var enablePerformanceMonitoring: Bool = false
    var enableMemoryOptimization: Bool = true
    var enableExperimentalFeatures: Bool = false
    var experimentalFeatures: [String] = []
    var customV2rayPath: String?
    var v2rayConfigTemplate: String = ""
    var enableAPIServer: Bool = false
    var apiServerPort: Int = 8080
    var apiServerToken: String = ""
    var enableWebUI: Bool = false
    var webUIPort: Int = 8081
    var enableMetrics: Bool = false
    var metricsPort: Int = 8082
    
    func validate() throws {
        // 验证日志文件大小
        if maxLogFileSize < 1 || maxLogFileSize > 100 {
            throw ConfigError.invalidValue("日志文件大小必须在1-100MB之间")
        }
        
        // 验证日志保留天数
        if logRetentionDays < 1 || logRetentionDays > 365 {
            throw ConfigError.invalidValue("日志保留天数必须在1-365天之间")
        }
        
        // 验证V2ray路径
        if let v2rayPath = customV2rayPath, !v2rayPath.isEmpty {
            if !FileManager.default.fileExists(atPath: v2rayPath) {
                throw ConfigError.invalidValue("V2ray可执行文件不存在: \(v2rayPath)")
            }
        }
        
        // 验证端口号
        if enableAPIServer {
            if apiServerPort < 1024 || apiServerPort > 65535 {
                throw ConfigError.invalidValue("API服务器端口必须在1024-65535之间")
            }
        }
        
        if enableWebUI {
            if webUIPort < 1024 || webUIPort > 65535 {
                throw ConfigError.invalidValue("Web UI端口必须在1024-65535之间")
            }
        }
        
        if enableMetrics {
            if metricsPort < 1024 || metricsPort > 65535 {
                throw ConfigError.invalidValue("指标端口必须在1024-65535之间")
            }
        }
        
        // 检查端口冲突
        let ports = [apiServerPort, webUIPort, metricsPort]
        let uniquePorts = Set(ports)
        if ports.count != uniquePorts.count {
            throw ConfigError.invalidConfiguration("端口配置存在冲突")
        }
    }
    
    mutating func merge(with other: AdvancedConfig) {
        enableDebugMode = other.enableDebugMode
        logLevel = other.logLevel
        maxLogFileSize = other.maxLogFileSize
        logRetentionDays = other.logRetentionDays
        enablePerformanceMonitoring = other.enablePerformanceMonitoring
        enableMemoryOptimization = other.enableMemoryOptimization
        enableExperimentalFeatures = other.enableExperimentalFeatures
        experimentalFeatures = other.experimentalFeatures
        customV2rayPath = other.customV2rayPath
        v2rayConfigTemplate = other.v2rayConfigTemplate
        enableAPIServer = other.enableAPIServer
        apiServerPort = other.apiServerPort
        apiServerToken = other.apiServerToken
        enableWebUI = other.enableWebUI
        webUIPort = other.webUIPort
        enableMetrics = other.enableMetrics
        metricsPort = other.metricsPort
    }
}

// MARK: - 枚举定义

enum ConfigCategory: String, CaseIterable {
    case general = "general"
    case proxy = "proxy"
    case network = "network"
    case security = "security"
    case ui = "ui"
    case advanced = "advanced"
    
    var displayName: String {
        switch self {
        case .general: return "通用"
        case .proxy: return "代理"
        case .network: return "网络"
        case .security: return "安全"
        case .ui: return "界面"
        case .advanced: return "高级"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .proxy: return "network"
        case .network: return "wifi"
        case .security: return "lock.shield"
        case .ui: return "paintbrush"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}

enum AppLanguage: String, CaseIterable, Codable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .english: return "English"
        case .chinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }
}

enum AppTheme: String, CaseIterable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

enum UpdateChannel: String, CaseIterable, Codable {
    case stable = "stable"
    case beta = "beta"
    case alpha = "alpha"
    
    var displayName: String {
        switch self {
        case .stable: return "稳定版"
        case .beta: return "测试版"
        case .alpha: return "开发版"
        }
    }
}

enum LoadBalancingStrategy: String, CaseIterable, Codable {
    case roundRobin = "round_robin"
    case leastConnections = "least_connections"
    case random = "random"
    case weighted = "weighted"
    
    var displayName: String {
        switch self {
        case .roundRobin: return "轮询"
        case .leastConnections: return "最少连接"
        case .random: return "随机"
        case .weighted: return "加权"
        }
    }
}

enum TLSVersion: Int, CaseIterable, Codable {
    case v1_0 = 10
    case v1_1 = 11
    case v1_2 = 12
    case v1_3 = 13
    
    var displayName: String {
        switch self {
        case .v1_0: return "TLS 1.0"
        case .v1_1: return "TLS 1.1"
        case .v1_2: return "TLS 1.2"
        case .v1_3: return "TLS 1.3"
        }
    }
}

enum FontSize: String, CaseIterable, Codable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extra_large"
    
    var displayName: String {
        switch self {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        case .extraLarge: return "特大"
        }
    }
    
    var size: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 14
        case .large: return 16
        case .extraLarge: return 18
        }
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Codable {
    case icon = "icon"
    case text = "text"
    case both = "both"
    
    var displayName: String {
        switch self {
        case .icon: return "仅图标"
        case .text: return "仅文字"
        case .both: return "图标+文字"
        }
    }
}

enum AnimationSpeed: String, CaseIterable, Codable {
    case slow = "slow"
    case normal = "normal"
    case fast = "fast"
    case disabled = "disabled"
    
    var displayName: String {
        switch self {
        case .slow: return "慢"
        case .normal: return "正常"
        case .fast: return "快"
        case .disabled: return "禁用"
        }
    }
    
    var duration: TimeInterval {
        switch self {
        case .slow: return 0.5
        case .normal: return 0.3
        case .fast: return 0.15
        case .disabled: return 0.0
        }
    }
}

struct FirewallRule: Codable, Equatable {
    let id: String
    var name: String
    var enabled: Bool
    var action: FirewallAction
    var direction: FirewallDirection
    var protocol: FirewallProtocol
    var sourceIP: String?
    var sourcePort: String?
    var destinationIP: String?
    var destinationPort: String?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        enabled: Bool = true,
        action: FirewallAction,
        direction: FirewallDirection,
        protocol: FirewallProtocol,
        sourceIP: String? = nil,
        sourcePort: String? = nil,
        destinationIP: String? = nil,
        destinationPort: String? = nil
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.action = action
        self.direction = direction
        self.protocol = protocol
        self.sourceIP = sourceIP
        self.sourcePort = sourcePort
        self.destinationIP = destinationIP
        self.destinationPort = destinationPort
    }
}

enum FirewallAction: String, CaseIterable, Codable {
    case allow = "allow"
    case deny = "deny"
    case log = "log"
    
    var displayName: String {
        switch self {
        case .allow: return "允许"
        case .deny: return "拒绝"
        case .log: return "记录"
        }
    }
}

enum FirewallDirection: String, CaseIterable, Codable {
    case inbound = "inbound"
    case outbound = "outbound"
    case both = "both"
    
    var displayName: String {
        switch self {
        case .inbound: return "入站"
        case .outbound: return "出站"
        case .both: return "双向"
        }
    }
}

enum FirewallProtocol: String, CaseIterable, Codable {
    case tcp = "tcp"
    case udp = "udp"
    case icmp = "icmp"
    case any = "any"
    
    var displayName: String {
        switch self {
        case .tcp: return "TCP"
        case .udp: return "UDP"
        case .icmp: return "ICMP"
        case .any: return "任意"
        }
    }
}

// MARK: - 配置错误
enum ConfigError: LocalizedError {
    case invalidValue(String)
    case invalidConfiguration(String)
    case conflictingSettings(String)
    case missingRequiredField(String)
    case unsupportedVersion(String)
    case corruptedData(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidValue(let message):
            return "无效的配置值: \(message)"
        case .invalidConfiguration(let message):
            return "无效的配置: \(message)"
        case .conflictingSettings(let message):
            return "配置冲突: \(message)"
        case .missingRequiredField(let message):
            return "缺少必需字段: \(message)"
        case .unsupportedVersion(let message):
            return "不支持的版本: \(message)"
        case .corruptedData(let message):
            return "数据损坏: \(message)"
        }
    }
}
```

### 2. 配置管理器实现

```swift
// MARK: - 配置管理器协议
protocol ConfigManagerProtocol {
    func loadConfig() async throws -> AppConfig
    func saveConfig(_ config: AppConfig) async throws
    func resetConfig(category: ConfigCategory?) async throws
    func exportConfig(to url: URL) async throws
    func importConfig(from url: URL) async throws -> AppConfig
    func validateConfig(_ config: AppConfig) async throws
    func getConfigHistory() async -> [ConfigSnapshot]
    func restoreConfig(from snapshot: ConfigSnapshot) async throws
}

// MARK: - 配置管理器实现
class ConfigManager: ConfigManagerProtocol, ObservableObject {
    private let logger = Logger(subsystem: "V2rayU", category: "ConfigManager")
    private let storage: ConfigStorage
    private let validator: ConfigValidator
    private let migrator: ConfigMigrator
    private let watcher: ConfigWatcher
    
    @Published var currentConfig = AppConfig()
    @Published var hasUnsavedChanges = false
    @Published var isLoading = false
    
    private let configQueue = DispatchQueue(label: "config.manager.queue", qos: .userInitiated)
    private var configHistory: [ConfigSnapshot] = []
    private let maxHistoryCount = 50
    
    init() {
        self.storage = ConfigStorage()
        self.validator = ConfigValidator()
        self.migrator = ConfigMigrator()
        self.watcher = ConfigWatcher()
        
        setupConfigWatcher()
    }
    
    // MARK: - 公共方法
    
    /// 加载配置
    func loadConfig() async throws -> AppConfig {
        await MainActor.run {
            isLoading = true
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            var config = try await storage.loadConfig()
            
            // 配置迁移
            config = try await migrator.migrateIfNeeded(config)
            
            // 配置验证
            try await validateConfig(config)
            
            await MainActor.run {
                currentConfig = config
                hasUnsavedChanges = false
            }
            
            logger.info("配置加载成功")
            return config
        } catch {
            logger.error("配置加载失败: \(error)")
            
            // 加载默认配置
            let defaultConfig = AppConfig()
            await MainActor.run {
                currentConfig = defaultConfig
                hasUnsavedChanges = false
            }
            
            throw error
        }
    }
    
    /// 保存配置
    func saveConfig(_ config: AppConfig) async throws {
        // 验证配置
        try await validateConfig(config)
        
        // 创建快照
        let snapshot = ConfigSnapshot(
            config: currentConfig,
            timestamp: Date(),
            description: "自动保存"
        )
        
        // 保存到历史记录
        await addToHistory(snapshot)
        
        // 保存配置
        try await storage.saveConfig(config)
        
        await MainActor.run {
            currentConfig = config
            hasUnsavedChanges = false
        }
        
        // 发送配置变更通知
        NotificationCenter.default.post(
            name: .configDidChange,
            object: config
        )
        
        logger.info("配置保存成功")
    }
    
    /// 重置配置
    func resetConfig(category: ConfigCategory? = nil) async throws {
        var newConfig = currentConfig
        newConfig.reset(category: category)
        
        try await saveConfig(newConfig)
        
        logger.info("配置重置完成: \(category?.displayName ?? "全部")")
    }
    
    /// 导出配置
    func exportConfig(to url: URL) async throws {
        let exporter = ConfigExporter()
        try await exporter.export(config: currentConfig, to: url)
        
        logger.info("配置导出成功: \(url.path)")
    }
    
    /// 导入配置
    func importConfig(from url: URL) async throws -> AppConfig {
        let importer = ConfigImporter()
        let config = try await importer.import(from: url)
        
        // 验证导入的配置
        try await validateConfig(config)
        
        logger.info("配置导入成功: \(url.path)")
        return config
    }
    
    /// 验证配置
    func validateConfig(_ config: AppConfig) async throws {
        try await validator.validate(config)
    }
    
    /// 获取配置历史
    func getConfigHistory() async -> [ConfigSnapshot] {
        return await withCheckedContinuation { continuation in
            configQueue.async {
                continuation.resume(returning: self.configHistory)
            }
        }
    }
    
    /// 恢复配置
    func restoreConfig(from snapshot: ConfigSnapshot) async throws {
        try await saveConfig(snapshot.config)
        
        logger.info("配置恢复成功: \(snapshot.description)")
    }
    
    /// 更新配置
    func updateConfig<T>(_ keyPath: WritableKeyPath<AppConfig, T>, value: T) {
        config[keyPath: keyPath] = value
        checkForChanges()
    }
    
    /// 搜索配置项
    func searchConfigs() -> [ConfigItem] {
        guard !searchText.isEmpty else {
            return getAllConfigItems()
        }
        
        return getAllConfigItems().filter { item in
            item.name.localizedCaseInsensitiveContains(searchText) ||
            item.description.localizedCaseInsensitiveContains(searchText) ||
            item.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // MARK: - 私有方法
    
    private func setupConfigObserver() {
        // 监听配置变更
        $config
            .dropFirst()
            .sink { [weak self] _ in
                self?.checkForChanges()
            }
            .store(in: &cancellables)
    }
    
    private func checkForChanges() {
        hasUnsavedChanges = config != originalConfig
    }
    
    private func loadConfigHistory() async {
        let history = await configManager.getConfigHistory()
        
        await MainActor.run {
            self.configHistory = history
        }
    }
    
    private func getAllConfigItems() -> [ConfigItem] {
        var items: [ConfigItem] = []
        
        // 通用配置项
        items.append(contentsOf: getGeneralConfigItems())
        
        // 代理配置项
        items.append(contentsOf: getProxyConfigItems())
        
        // 网络配置项
        items.append(contentsOf: getNetworkConfigItems())
        
        // 安全配置项
        items.append(contentsOf: getSecurityConfigItems())
        
        // 界面配置项
        items.append(contentsOf: getUIConfigItems())
        
        // 高级配置项
        items.append(contentsOf: getAdvancedConfigItems())
        
        return items
    }
    
    private func getGeneralConfigItems() -> [ConfigItem] {
        return [
            ConfigItem(
                id: "launch_at_startup",
                name: "开机启动",
                description: "系统启动时自动启动应用",
                category: .general,
                keywords: ["启动", "开机", "自动"]
            ),
            ConfigItem(
                id: "start_minimized",
                name: "启动时最小化",
                description: "应用启动时最小化到系统托盘",
                category: .general,
                keywords: ["最小化", "托盘", "隐藏"]
            ),
            ConfigItem(
                id: "language",
                name: "语言",
                description: "应用界面显示语言",
                category: .general,
                keywords: ["语言", "界面", "本地化"]
            ),
            ConfigItem(
                id: "theme",
                name: "主题",
                description: "应用外观主题",
                category: .general,
                keywords: ["主题", "外观", "深色", "浅色"]
            )
        ]
    }
    
    private func getProxyConfigItems() -> [ConfigItem] {
        return [
            ConfigItem(
                id: "default_proxy",
                name: "默认代理",
                description: "系统启动时使用的默认代理服务器",
                category: .proxy,
                keywords: ["默认", "代理", "服务器"]
            ),
            ConfigItem(
                id: "auto_switch",
                name: "自动切换",
                description: "根据网络状况自动切换代理服务器",
                category: .proxy,
                keywords: ["自动", "切换", "智能"]
            ),
            ConfigItem(
                id: "load_balancing",
                name: "负载均衡",
                description: "在多个代理服务器之间分配流量",
                category: .proxy,
                keywords: ["负载", "均衡", "分配"]
            )
        ]
    }
    
    private func getNetworkConfigItems() -> [ConfigItem] {
        return [
            ConfigItem(
                id: "dns_servers",
                name: "DNS服务器",
                description: "用于域名解析的DNS服务器列表",
                category: .network,
                keywords: ["DNS", "域名", "解析"]
            ),
            ConfigItem(
                id: "connection_timeout",
                name: "连接超时",
                description: "建立连接的最大等待时间",
                category: .network,
                keywords: ["连接", "超时", "等待"]
            )
        ]
    }
    
    private func getSecurityConfigItems() -> [ConfigItem] {
        return [
            ConfigItem(
                id: "tls_verification",
                name: "TLS验证",
                description: "启用TLS证书验证",
                category: .security,
                keywords: ["TLS", "证书", "验证", "安全"]
            ),
            ConfigItem(
                id: "certificate_pinning",
                name: "证书固定",
                description: "固定特定的TLS证书",
                category: .security,
                keywords: ["证书", "固定", "安全"]
            )
        ]
    }
    
    private func getUIConfigItems() -> [ConfigItem] {
        return [
            ConfigItem(
                id: "font_size",
                name: "字体大小",
                description: "界面文字的显示大小",
                category: .ui,
                keywords: ["字体", "大小", "文字"]
            ),
            ConfigItem(
                id: "animations",
                name: "动画效果",
                description: "界面动画和过渡效果",
                category: .ui,
                keywords: ["动画", "效果", "过渡"]
            )
        ]
    }
    
    private func getAdvancedConfigItems() -> [ConfigItem] {
        return [
            ConfigItem(
                id: "debug_mode",
                name: "调试模式",
                description: "启用详细的调试信息输出",
                category: .advanced,
                keywords: ["调试", "日志", "开发"]
            ),
            ConfigItem(
                id: "api_server",
                name: "API服务器",
                description: "启用内置的API服务器",
                category: .advanced,
                keywords: ["API", "服务器", "接口"]
            )
        ]
    }
}

// MARK: - 配置项模型
struct ConfigItem: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let category: ConfigCategory
    let keywords: [String]
    
    init(
        id: String,
        name: String,
        description: String,
        category: ConfigCategory,
        keywords: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.keywords = keywords
    }
}
```

## 🎨 界面设计

### 1. 设置主界面

```swift
// MARK: - 设置主视图
struct SettingsView: View {
    @StateObject private var handler = SettingsHandler(
        configManager: AppContainer.shared.configManager
    )
    
    var body: some View {
        NavigationSplitView {
            // 侧边栏 - 配置分类
            SettingsSidebarView(
                selectedCategory: $handler.selectedCategory,
                searchText: $handler.searchText
            )
        } detail: {
            // 详情页 - 配置内容
            SettingsDetailView(
                category: handler.selectedCategory,
                config: $handler.config,
                searchText: handler.searchText
            )
        }
        .navigationTitle("设置")
        .toolbar {
            SettingsToolbarView(handler: handler)
        }
        .sheet(isPresented: $handler.showingImportSheet) {
            ConfigImportView(handler: handler)
        }
        .sheet(isPresented: $handler.showingExportSheet) {
            ConfigExportView(handler: handler)
        }
        .alert("重置配置", isPresented: $handler.showingResetAlert) {
            ResetConfigAlert(handler: handler)
        }
        .task {
            await handler.loadConfig()
        }
        .onChange(of: handler.hasUnsavedChanges) { hasChanges in
            if hasChanges {
                // 显示未保存提示
            }
        }
    }
}

// MARK: - 设置侧边栏
struct SettingsSidebarView: View {
    @Binding var selectedCategory: ConfigCategory
    @Binding var searchText: String
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            SearchBar(text: $searchText)
                .padding()
            
            // 分类列表
            List(ConfigCategory.allCases, id: \.self, selection: $selectedCategory) { category in
                CategoryRowView(category: category)
            }
            .listStyle(.sidebar)
        }
        .navigationTitle("配置")
    }
}

// MARK: - 分类行视图
struct CategoryRowView: View {
    let category: ConfigCategory
    
    var body: some View {
        Label {
            Text(category.displayName)
                .font(.system(size: 14, weight: .medium))
        } icon: {
            Image(systemName: category.icon)
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 设置详情视图
struct SettingsDetailView: View {
    let category: ConfigCategory
    @Binding var config: AppConfig
    let searchText: String
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                switch category {
                case .general:
                    GeneralSettingsView(config: $config.general)
                case .proxy:
                    ProxySettingsView(config: $config.proxy)
                case .network:
                    NetworkSettingsView(config: $config.network)
                case .security:
                    SecuritySettingsView(config: $config.security)
                case .ui:
                    UISettingsView(config: $config.ui)
                case .advanced:
                    AdvancedSettingsView(config: $config.advanced)
                }
            }
            .padding()
        }
        .navigationTitle(category.displayName)
    }
}

// MARK: - 通用设置视图
struct GeneralSettingsView: View {
    @Binding var config: GeneralConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection("启动选项") {
                SettingsToggle(
                    "开机启动",
                    description: "系统启动时自动启动应用",
                    isOn: $config.launchAtStartup
                )
                
                SettingsToggle(
                    "启动时最小化",
                    description: "应用启动时最小化到系统托盘",
                    isOn: $config.startMinimized
                )
            }
            
            SettingsSection("显示选项") {
                SettingsToggle(
                    "显示在Dock中",
                    description: "在Dock中显示应用图标",
                    isOn: $config.showInDock
                )
                
                SettingsToggle(
                    "显示在菜单栏",
                    description: "在菜单栏中显示状态图标",
                    isOn: $config.showInMenuBar
                )
            }
            
            SettingsSection("界面设置") {
                SettingsPicker(
                    "语言",
                    description: "应用界面显示语言",
                    selection: $config.language,
                    options: AppLanguage.allCases
                ) { language in
                    Text(language.displayName)
                }
                
                SettingsPicker(
                    "主题",
                    description: "应用外观主题",
                    selection: $config.theme,
                    options: AppTheme.allCases
                ) { theme in
                    Text(theme.displayName)
                }
            }
            
            SettingsSection("通知设置") {
                SettingsToggle(
                    "启用通知",
                    description: "显示系统通知",
                    isOn: $config.enableNotifications
                )
                
                SettingsToggle(
                    "通知声音",
                    description: "播放通知声音",
                    isOn: $config.notificationSound
                )
                .disabled(!config.enableNotifications)
            }
            
            SettingsSection("更新设置") {
                SettingsToggle(
                    "自动检查更新",
                    description: "定期检查应用更新",
                    isOn: $config.checkUpdatesAutomatically
                )
                
                SettingsPicker(
                    "更新通道",
                    description: "选择更新版本类型",
                    selection: $config.updateChannel,
                    options: UpdateChannel.allCases
                ) { channel in
                    Text(channel.displayName)
                }
                .disabled(!config.checkUpdatesAutomatically)
            }
        }
    }
}
```

### 2. 配置组件库

```swift
// MARK: - 设置区块
struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                content
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

// MARK: - 设置开关
struct SettingsToggle: View {
    let title: String
    let description: String?
    @Binding var isOn: Bool
    
    init(
        _ title: String,
        description: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.description = description
        self._isOn = isOn
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 设置选择器
struct SettingsPicker<T: Hashable, Content: View>: View {
    let title: String
    let description: String?
    @Binding var selection: T
    let options: [T]
    let content: (T) -> Content
    
    init(
        _ title: String,
        description: String? = nil,
        selection: Binding<T>,
        options: [T],
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.title = title
        self.description = description
        self._selection = selection
        self.options = options
        self.content = content
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    content(option)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 120)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 设置文本字段
struct SettingsTextField: View {
    let title: String
    let description: String?
    let placeholder: String
    @Binding var text: String
    
    init(
        _ title: String,
        description: String? = nil,
        placeholder: String = "",
        text: Binding<String>
    ) {
        self.title = title
        self.description = description
        self.placeholder = placeholder
        self._text = text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 设置数字字段
struct SettingsNumberField<T: Numeric & LosslessStringConvertible>: View {
    let title: String
    let description: String?
    let placeholder: String
    @Binding var value: T
    let range: ClosedRange<T>?
    let formatter: NumberFormatter
    
    init(
        _ title: String,
        description: String? = nil,
        placeholder: String = "",
        value: Binding<T>,
        range: ClosedRange<T>? = nil,
        formatter: NumberFormatter = NumberFormatter()
    ) {
        self.title = title
        self.description = description
        self.placeholder = placeholder
        self._value = value
        self.range = range
        self.formatter = formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            TextField(placeholder, value: $value, formatter: formatter)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 设置滑块
struct SettingsSlider<T: BinaryFloatingPoint>: View where T.Stride: BinaryFloatingPoint {
    let title: String
    let description: String?
    @Binding var value: T
    let range: ClosedRange<T>
    let step: T.Stride?
    
    init(
        _ title: String,
        description: String? = nil,
        value: Binding<T>,
        in range: ClosedRange<T>,
        step: T.Stride? = nil
    ) {
        self.title = title
        self.description = description
        self._value = value
        self.range = range
        self.step = step
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                    
                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(value, specifier: "%.1f")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 40)
            }
            
            if let step = step {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }
        }
        .padding(.vertical, 4)
    }
}
```

## 🔧 使用示例

### 1. 基本配置管理

```swift
// 创建配置管理器
let configManager = ConfigManager()

// 加载配置
let config = try await configManager.loadConfig()

// 修改配置
var newConfig = config
newConfig.general.launchAtStartup = true
newConfig.proxy.enableAutoSwitch = true

// 保存配置
try await configManager.saveConfig(newConfig)

// 重置配置
try await configManager.resetConfig(category: .general)
```

### 2. 配置导入导出

```swift
// 导出配置
let exportURL = URL(fileURLWithPath: "/path/to/config.json")
try await configManager.exportConfig(to: exportURL)

// 导入配置
let importURL = URL(fileURLWithPath: "/path/to/imported-config.json")
let importedConfig = try await configManager.importConfig(from: importURL)

// 应用导入的配置
try await configManager.saveConfig(importedConfig)
```

### 3. 配置验证

```swift
// 验证配置
do {
    try await configManager.validateConfig(config)
    print("配置验证通过")
} catch let error as ConfigError {
    print("配置验证失败: \(error.localizedDescription)")
}
```

### 4. 配置历史管理

```swift
// 获取配置历史
let history = await configManager.getConfigHistory()

// 恢复到历史配置
if let snapshot = history.first {
    try await configManager.restoreConfig(from: snapshot)
}
```

## 📚 最佳实践

### 1. 配置设计原则
- **分类清晰**: 按功能模块组织配置项
- **默认合理**: 提供合理的默认值
- **验证严格**: 对配置值进行严格验证
- **向后兼容**: 保持配置格式的向后兼容性

### 2. 性能优化
- **延迟加载**: 按需加载配置模块
- **增量保存**: 只保存变更的配置项
- **缓存机制**: 缓存常用配置值
- **异步处理**: 使用异步操作避免阻塞UI

### 3. 用户体验
- **实时预览**: 配置变更实时生效
- **搜索功能**: 提供配置项搜索
- **帮助提示**: 为配置项提供详细说明
- **导入导出**: 支持配置的备份和迁移

### 4. 错误处理
- **优雅降级**: 配置错误时使用默认值
- **错误提示**: 提供清晰的错误信息
- **自动修复**: 尝试自动修复损坏的配置
- **备份恢复**: 提供配置备份和恢复机制

## 🚀 扩展功能

### 1. 配置同步
- 支持多设备配置同步
- 云端配置备份
- 配置版本控制
- 冲突解决机制

### 2. 高级配置
- 配置模板系统
- 条件配置规则
- 配置继承机制
- 动态配置更新

### 3. 监控和分析
- 配置使用统计
- 性能影响分析
- 配置优化建议
- 异常配置检测

设置配置功能是V2rayU的核心管理模块，通过完善的配置体系和友好的用户界面，为用户提供了强大而灵活的应用定制能力。(_ updater: @escaping (inout AppConfig) -> Void) async throws {
        var newConfig = currentConfig
        updater(&newConfig)
        
        try await saveConfig(newConfig)
    }
    
    /// 应用配置变更
    func applyConfigChanges() async {
        // 应用通用配置
        await applyGeneralConfig()
        
        // 应用代理配置
        await applyProxyConfig()
        
        // 应用网络配置
        await applyNetworkConfig()
        
        // 应用安全配置
        await applySecurityConfig()
        
        // 应用界面配置
        await applyUIConfig()
        
        // 应用高级配置
        await applyAdvancedConfig()
        
        logger.info("配置变更应用完成")
    }
    
    // MARK: - 私有方法
    
    private func setupConfigWatcher() {
        watcher.onConfigChange = { [weak self] in
            Task {
                await self?.handleExternalConfigChange()
            }
        }
        
        watcher.startWatching()
    }
    
    private func handleExternalConfigChange() async {
        do {
            let config = try await loadConfig()
            logger.info("检测到外部配置变更，已重新加载")
        } catch {
            logger.error("处理外部配置变更失败: \(error)")
        }
    }
    
    private func addToHistory(_ snapshot: ConfigSnapshot) async {
        await withCheckedContinuation { continuation in
            configQueue.async {
                self.configHistory.insert(snapshot, at: 0)
                
                // 限制历史记录数量
                if self.configHistory.count > self.maxHistoryCount {
                    self.configHistory.removeLast()
                }
                
                continuation.resume()
            }
        }
    }
    
    private func applyGeneralConfig() async {
        let config = currentConfig.general
        
        // 应用启动设置
        if config.launchAtStartup {
            // 设置开机启动
        }
        
        // 应用语言设置
        // 应用主题设置
        // 应用通知设置
    }
    
    private func applyProxyConfig() async {
        let config = currentConfig.proxy
        
        // 应用默认代理
        // 应用自动切换
        // 应用负载均衡
        // 应用故障转移
    }
    
    private func applyNetworkConfig() async {
        let config = currentConfig.network
        
        // 应用DNS设置
        // 应用超时设置
        // 应用连接限制
    }
    
    private func applySecurityConfig() async {
        let config = currentConfig.security
        
        // 应用TLS设置
        // 应用证书验证
        // 应用防火墙规则
    }
    
    private func applyUIConfig() async {
        let config = currentConfig.ui
        
        // 应用主题
        // 应用字体
        // 应用动画
    }
    
    private func applyAdvancedConfig() async {
        let config = currentConfig.advanced
        
        // 应用调试设置
        // 应用日志设置
        // 应用性能设置
    }
}

// MARK: - 配置快照
struct ConfigSnapshot: Codable, Identifiable {
    let id: String
    let config: AppConfig
    let timestamp: Date
    let description: String
    
    init(
        id: String = UUID().uuidString,
        config: AppConfig,
        timestamp: Date,
        description: String
    ) {
        self.id = id
        self.config = config
        self.timestamp = timestamp
        self.description = description
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - 配置存储
class ConfigStorage {
    private let logger = Logger(subsystem: "V2rayU", category: "ConfigStorage")
    private let configURL: URL
    private let backupURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("V2rayU")
        
        self.configURL = appDir.appendingPathComponent("config.json")
        self.backupURL = appDir.appendingPathComponent("config.backup.json")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
    }
    
    func loadConfig() async throws -> AppConfig {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            // 返回默认配置
            return AppConfig()
        }
        
        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            logger.error("加载配置失败: \(error)")
            
            // 尝试加载备份
            if FileManager.default.fileExists(atPath: backupURL.path) {
                logger.info("尝试加载备份配置")
                let data = try Data(contentsOf: backupURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                return try decoder.decode(AppConfig.self, from: data)
            }
            
            throw error
        }
    }
    
    func saveConfig(_ config: AppConfig) async throws {
        // 创建备份
        if FileManager.default.fileExists(atPath: configURL.path) {
            try? FileManager.default.copyItem(at: configURL, to: backupURL)
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
        
        logger.info("配置保存成功")
    }
}

// MARK: - 配置验证器
class ConfigValidator {
    private let logger = Logger(subsystem: "V2rayU", category: "ConfigValidator")
    
    func validate(_ config: AppConfig) async throws {
        // 验证配置版本
        try validateVersion(config.version)
        
        // 验证各个配置模块
        try config.validate()
        
        // 验证配置完整性
        try validateIntegrity(config)
        
        logger.info("配置验证通过")
    }
    
    private func validateVersion(_ version: String) throws {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        // 简单的版本兼容性检查
        let configVersionComponents = version.split(separator: ".").compactMap { Int($0) }
        let currentVersionComponents = currentVersion.split(separator: ".").compactMap { Int($0) }
        
        if configVersionComponents.isEmpty || currentVersionComponents.isEmpty {
            throw ConfigError.unsupportedVersion("无效的版本格式")
        }
        
        // 检查主版本号兼容性
        if configVersionComponents[0] > currentVersionComponents[0] {
            throw ConfigError.unsupportedVersion("配置版本过新: \(version)")
        }
    }
    
    private func validateIntegrity(_ config: AppConfig) throws {
        // 检查必需字段
        if config.configId.isEmpty {
            throw ConfigError.missingRequiredField("configId")
        }
        
        // 检查数据一致性
        if config.createdAt > config.updatedAt {
            throw ConfigError.invalidConfiguration("创建时间不能晚于更新时间")
        }
    }
}

// MARK: - 配置迁移器
class ConfigMigrator {
    private let logger = Logger(subsystem: "V2rayU", category: "ConfigMigrator")
    
    func migrateIfNeeded(_ config: AppConfig) async throws -> AppConfig {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        if config.version == currentVersion {
            return config
        }
        
        logger.info("开始配置迁移: \(config.version) -> \(currentVersion)")
        
        var migratedConfig = config
        
        // 执行版本迁移
        migratedConfig = try await migrateToCurrentVersion(migratedConfig)
        
        // 更新版本信息
        migratedConfig.updatedAt = Date()
        
        logger.info("配置迁移完成")
        return migratedConfig
    }
    
    private func migrateToCurrentVersion(_ config: AppConfig) async throws -> AppConfig {
        var migratedConfig = config
        
        // 根据版本执行相应的迁移逻辑
        // 这里可以添加具体的迁移规则
        
        return migratedConfig
    }
}

// MARK: - 配置监视器
class ConfigWatcher {
    private let logger = Logger(subsystem: "V2rayU", category: "ConfigWatcher")
    private var fileSystemWatcher: DispatchSourceFileSystemObject?
    
    var onConfigChange: (() -> Void)?
    
    func startWatching() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configURL = appSupport.appendingPathComponent("V2rayU/config.json")
        
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return
        }
        
        let fileDescriptor = open(configURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            logger.error("无法打开配置文件进行监视")
            return
        }
        
        fileSystemWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .background)
        )
        
        fileSystemWatcher?.setEventHandler { [weak self] in
            self?.onConfigChange?()
        }
        
        fileSystemWatcher?.setCancelHandler {
            close(fileDescriptor)
        }
        
        fileSystemWatcher?.resume()
        
        logger.info("配置文件监视已启动")
    }
    
    func stopWatching() {
        fileSystemWatcher?.cancel()
        fileSystemWatcher = nil
        
        logger.info("配置文件监视已停止")
    }
    
    deinit {
        stopWatching()
    }
}

// MARK: - 配置导出器
class ConfigExporter {
    private let logger = Logger(subsystem: "V2rayU", category: "ConfigExporter")
    
    func export(config: AppConfig, to url: URL) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)
        
        logger.info("配置导出成功: \(url.path)")
    }
}

// MARK: - 配置导入器
class ConfigImporter {
    private let logger = Logger(subsystem: "V2rayU", category: "ConfigImporter")
    
    func import(from url: URL) async throws -> AppConfig {
        let data = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let config = try decoder.decode(AppConfig.self, from: data)
        
        logger.info("配置导入成功: \(url.path)")
        return config
    }
}

// MARK: - 通知名称
extension Notification.Name {
    static let configDidChange = Notification.Name("configDidChange")
    static let configDidReset = Notification.Name("configDidReset")
    static let configDidImport = Notification.Name("configDidImport")
    static let configDidExport = Notification.Name("configDidExport")
}
```

### 3. 设置处理器实现

```swift
// MARK: - 设置处理器
@MainActor
class SettingsHandler: AsyncHandler {
    private let configManager: ConfigManagerProtocol
    
    @Published var config = AppConfig()
    @Published var selectedCategory: ConfigCategory = .general
    @Published var searchText = ""
    @Published var hasUnsavedChanges = false
    @Published var configHistory: [ConfigSnapshot] = []
    @Published var showingImportSheet = false
    @Published var showingExportSheet = false
    @Published var showingResetAlert = false
    
    private var originalConfig = AppConfig()
    
    init(configManager: ConfigManagerProtocol) {
        self.configManager = configManager
        super.init()
        
        setupConfigObserver()
    }
    
    // MARK: - 公共方法
    
    /// 加载配置
    func loadConfig() async {
        await performAsyncOperation {
            let loadedConfig = try await self.configManager.loadConfig()
            
            await MainActor.run {
                self.config = loadedConfig
                self.originalConfig = loadedConfig
                self.hasUnsavedChanges = false
            }
            
            await self.loadConfigHistory()
            self.logger.info("配置加载完成")
        }
    }
    
    /// 保存配置
    func saveConfig() async {
        await performAsyncOperation {
            try await self.configManager.saveConfig(self.config)
            
            await MainActor.run {
                self.originalConfig = self.config
                self.hasUnsavedChanges = false
            }
            
            await self.loadConfigHistory()
            self.logger.info("配置保存完成")
        }
    }
    
    /// 重置配置
    func resetConfig(category: ConfigCategory? = nil) async {
        await performAsyncOperation {
            try await self.configManager.resetConfig(category: category)
            
            let loadedConfig = try await self.configManager.loadConfig()
            
            await MainActor.run {
                self.config = loadedConfig
                self.originalConfig = loadedConfig
                self.hasUnsavedChanges = false
            }
            
            self.logger.info("配置重置完成: \(category?.displayName ?? "全部")")
        }
    }
    
    /// 导出配置
    func exportConfig(to url: URL) async {
        await performAsyncOperation {
            try await self.configManager.exportConfig(to: url)
            self.logger.info("配置导出成功")
        }
    }
    
    /// 导入配置
    func importConfig(from url: URL) async {
        await performAsyncOperation {
            let importedConfig = try await self.configManager.importConfig(from: url)
            
            await MainActor.run {
                self.config = importedConfig
                self.hasUnsavedChanges = true
            }
            
            self.logger.info("配置导入成功")
        }
    }
    
    /// 恢复配置
    func restoreConfig(from snapshot: ConfigSnapshot) async {
        await performAsyncOperation {
            try await self.configManager.restoreConfig(from: snapshot)
            
            let loadedConfig = try await self.configManager.loadConfig()
            
            await MainActor.run {
                self.config = loadedConfig
                self.originalConfig = loadedConfig
                self.hasUnsavedChanges = false
            }
            
            self.logger.info("配置恢复完成")
        }
    }
    
    /// 验证配置
    func validateConfig() async -> Bool {
        do {
            try await configManager.validateConfig(config)
            return true
        } catch {
            await MainActor.run {
                self.error = error
            }
            logger.error("配置验证失败: \(error)")
            return false
        }
    }
    
    /// 应用配置变更
    func applyChanges() async {
        guard hasUnsavedChanges else { return }
        
        await saveConfig()
        
        // 应用配置到系统
        if let configManager = configManager as? ConfigManager {
            await configManager.applyConfigChanges()
        }
    }
    
    /// 取消变更
    func cancelChanges() {
        config = originalConfig
        hasUnsavedChanges = false
    }
    
    /// 更新配置
    func updateConfig
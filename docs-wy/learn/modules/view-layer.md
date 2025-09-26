# 视图层模块详解

## 📋 概述

V2rayU的视图层采用SwiftUI框架构建，遵循MVVM架构模式。本模块负责用户界面的展示和交互，包括主界面、代理列表、设置页面、状态栏菜单等核心UI组件。

## 🏗️ 架构设计

### 1. MVVM架构模式

```swift
// MARK: - 视图模型基类
protocol ViewModelProtocol: ObservableObject {
    associatedtype State
    associatedtype Action
    
    var state: State { get }
    func send(_ action: Action)
}

// MARK: - 基础视图模型
class BaseViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showError = false
    
    // MARK: - 错误处理
    func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.error = error
            self.showError = true
            self.isLoading = false
        }
    }
    
    // MARK: - 加载状态管理
    func setLoading(_ loading: Bool) {
        DispatchQueue.main.async {
            self.isLoading = loading
        }
    }
    
    // MARK: - 清除错误
    func clearError() {
        DispatchQueue.main.async {
            self.error = nil
            self.showError = false
        }
    }
}

// MARK: - 视图状态枚举
enum ViewState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var data: T? {
        if case .loaded(let data) = self {
            return data
        }
        return nil
    }
    
    var error: Error? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
}
```

### 2. 主应用入口

```swift
// MARK: - 应用入口
@main
struct V2rayUApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var menuBarManager = MenuBarManager.shared
    
    var body: some Scene {
        // 主窗口（隐藏）
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        // 设置窗口
        WindowGroup("settings") {
            SettingsView()
                .environmentObject(appState)
                .frame(minWidth: 600, minHeight: 500)
        }
        .windowResizability(.contentMinSize)
        .defaultPosition(.center)
        
        // 菜单栏
        MenuBarExtra("V2rayU", systemImage: menuBarManager.statusIcon) {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(menuBarManager)
        }
        .menuBarExtraStyle(.menu)
    }
}

// MARK: - 应用状态管理
class AppState: ObservableObject {
    static let shared = AppState()
    
    // MARK: - 主题设置
    @Published var currentTheme: AppTheme = .system {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
            applyTheme()
        }
    }
    
    // MARK: - 语言设置
    @Published var currentLanguage: AppLanguage = .system {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            applyLanguage()
        }
    }
    
    // MARK: - 代理状态
    @Published var isProxyEnabled = false
    @Published var currentProxy: ProxyConfig?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    // MARK: - 流量统计
    @Published var uploadSpeed: String = "0 B/s"
    @Published var downloadSpeed: String = "0 B/s"
    @Published var totalUpload: String = "0 B"
    @Published var totalDownload: String = "0 B"
    
    private init() {
        loadSettings()
        setupNotifications()
    }
    
    // MARK: - 加载设置
    private func loadSettings() {
        if let themeRaw = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = AppTheme(rawValue: themeRaw) {
            currentTheme = theme
        }
        
        if let languageRaw = UserDefaults.standard.string(forKey: "app_language"),
           let language = AppLanguage(rawValue: languageRaw) {
            currentLanguage = language
        }
    }
    
    // MARK: - 设置通知监听
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .proxyStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let isEnabled = notification.userInfo?["isEnabled"] as? Bool {
                self?.isProxyEnabled = isEnabled
            }
            if let proxy = notification.userInfo?["proxy"] as? ProxyConfig {
                self?.currentProxy = proxy
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .trafficStatsUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let stats = notification.userInfo?["stats"] as? TrafficStats {
                self?.updateTrafficStats(stats)
            }
        }
    }
    
    // MARK: - 更新流量统计
    private func updateTrafficStats(_ stats: TrafficStats) {
        uploadSpeed = ByteCountFormatter.string(fromByteCount: stats.uploadSpeed, countStyle: .binary) + "/s"
        downloadSpeed = ByteCountFormatter.string(fromByteCount: stats.downloadSpeed, countStyle: .binary) + "/s"
        totalUpload = ByteCountFormatter.string(fromByteCount: stats.totalUpload, countStyle: .binary)
        totalDownload = ByteCountFormatter.string(fromByteCount: stats.totalDownload, countStyle: .binary)
    }
    
    // MARK: - 应用主题
    private func applyTheme() {
        // 主题应用逻辑
    }
    
    // MARK: - 应用语言
    private func applyLanguage() {
        // 语言应用逻辑
    }
}

// MARK: - 主题枚举
enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return NSLocalizedString("Light", comment: "")
        case .dark: return NSLocalizedString("Dark", comment: "")
        case .system: return NSLocalizedString("System", comment: "")
        }
    }
}

// MARK: - 语言枚举
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case chinese = "zh-Hans"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "简体中文"
        case .system: return NSLocalizedString("System", comment: "")
        }
    }
}

// MARK: - 连接状态
enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    var displayText: String {
        switch self {
        case .disconnected:
            return NSLocalizedString("Disconnected", comment: "")
        case .connecting:
            return NSLocalizedString("Connecting", comment: "")
        case .connected:
            return NSLocalizedString("Connected", comment: "")
        case .error(let message):
            return NSLocalizedString("Error: ", comment: "") + message
        }
    }
    
    var color: Color {
        switch self {
        case .disconnected:
            return .secondary
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
}
```

## 🎯 核心视图组件

### 1. 菜单栏视图

```swift
// MARK: - 菜单栏视图
struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var menuBarManager: MenuBarManager
    @StateObject private var proxyHandler = ProxyHandler()
    @StateObject private var systemProxyHandler = SystemProxyHandler()
    
    var body: some View {
        VStack(spacing: 0) {
            // 状态区域
            statusSection
            
            Divider()
            
            // 代理列表
            proxyListSection
            
            Divider()
            
            // 控制按钮
            controlSection
        }
        .frame(width: 280)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - 状态区域
    private var statusSection: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(appState.connectionStatus.color)
                    .frame(width: 8, height: 8)
                
                Text(appState.connectionStatus.displayText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: toggleProxy) {
                    Image(systemName: appState.isProxyEnabled ? "stop.circle.fill" : "play.circle.fill")
                        .foregroundColor(appState.isProxyEnabled ? .red : .green)
                }
                .buttonStyle(.plain)
                .help(appState.isProxyEnabled ? "停止代理" : "启动代理")
            }
            
            if appState.isProxyEnabled {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("↑ \(appState.uploadSpeed)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("↓ \(appState.downloadSpeed)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("总上传: \(appState.totalUpload)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("总下载: \(appState.totalDownload)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - 代理列表区域
    private var proxyListSection: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(proxyHandler.proxies) { proxy in
                    ProxyRowView(
                        proxy: proxy,
                        isSelected: proxy.id == appState.currentProxy?.id,
                        onSelect: { selectProxy(proxy) },
                        onTest: { testProxy(proxy) }
                    )
                }
            }
        }
        .frame(maxHeight: 200)
    }
    
    // MARK: - 控制区域
    private var controlSection: some View {
        VStack(spacing: 4) {
            HStack {
                Button("设置") {
                    openSettings()
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button("测速") {
                    testAllProxies()
                }
                .buttonStyle(.borderless)
                .disabled(proxyHandler.isLoading)
                
                Button("刷新") {
                    refreshProxies()
                }
                .buttonStyle(.borderless)
                .disabled(proxyHandler.isLoading)
            }
            
            HStack {
                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                
                Spacer()
                
                if proxyHandler.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - 操作方法
    private func toggleProxy() {
        Task {
            do {
                if appState.isProxyEnabled {
                    try await systemProxyHandler.disableSystemProxy()
                } else {
                    if let proxy = appState.currentProxy {
                        try await systemProxyHandler.enableSystemProxy(with: proxy)
                    }
                }
            } catch {
                print("切换代理失败: \(error)")
            }
        }
    }
    
    private func selectProxy(_ proxy: ProxyConfig) {
        Task {
            do {
                try await proxyHandler.activateProxy(proxy)
            } catch {
                print("选择代理失败: \(error)")
            }
        }
    }
    
    private func testProxy(_ proxy: ProxyConfig) {
        Task {
            do {
                try await proxyHandler.testProxy(proxy)
            } catch {
                print("测试代理失败: \(error)")
            }
        }
    }
    
    private func testAllProxies() {
        Task {
            do {
                try await proxyHandler.batchTestProxies(proxyHandler.proxies)
            } catch {
                print("批量测试失败: \(error)")
            }
        }
    }
    
    private func refreshProxies() {
        Task {
            await proxyHandler.loadProxies()
        }
    }
    
    private func openSettings() {
        if let url = URL(string: "v2rayu://settings") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - 菜单栏管理器
class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()
    
    @Published var statusIcon: String = "network"
    @Published var isMenuOpen = false
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .proxyStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let isEnabled = notification.userInfo?["isEnabled"] as? Bool {
                self?.statusIcon = isEnabled ? "network.badge.shield.half.filled" : "network"
            }
        }
    }
}
```

### 2. 代理行视图

```swift
// MARK: - 代理行视图
struct ProxyRowView: View {
    let proxy: ProxyConfig
    let isSelected: Bool
    let onSelect: () -> Void
    let onTest: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // 选择指示器
            Circle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .stroke(Color.secondary, lineWidth: 1)
                        .opacity(isSelected ? 0 : 1)
                )
            
            // 代理信息
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(proxy.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 协议类型标签
                    Text(proxy.protocolType.displayName)
                        .font(.system(size: 10))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(3)
                }
                
                HStack {
                    Text("\(proxy.serverAddress):\(proxy.serverPort)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 延迟显示
                    if let latency = proxy.latency {
                        Text("\(latency)ms")
                            .font(.system(size: 10))
                            .foregroundColor(latencyColor(latency))
                    } else {
                        Text("未测试")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 操作按钮
            if isHovered {
                Button(action: onTest) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("测试延迟")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onSelect()
        }
    }
    
    // MARK: - 延迟颜色
    private func latencyColor(_ latency: Int) -> Color {
        switch latency {
        case 0..<100:
            return .green
        case 100..<300:
            return .orange
        default:
            return .red
        }
    }
}
```

### 3. 设置视图

```swift
// MARK: - 设置视图
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationSplitView {
            // 侧边栏
            settingsSidebar
        } detail: {
            // 详情页面
            settingsDetail
        }
        .navigationTitle("设置")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("完成") {
                    NSApplication.shared.keyWindow?.close()
                }
            }
        }
    }
    
    // MARK: - 设置侧边栏
    private var settingsSidebar: some View {
        List(SettingsSection.allCases, id: \.self, selection: $viewModel.selectedSection) { section in
            Label(section.title, systemImage: section.icon)
                .tag(section)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
    
    // MARK: - 设置详情
    private var settingsDetail: some View {
        Group {
            switch viewModel.selectedSection {
            case .general:
                GeneralSettingsView()
            case .proxy:
                ProxySettingsView()
            case .subscription:
                SubscriptionSettingsView()
            case .advanced:
                AdvancedSettingsView()
            case .about:
                AboutView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - 设置视图模型
class SettingsViewModel: ObservableObject {
    @Published var selectedSection: SettingsSection = .general
}

// MARK: - 设置分类
enum SettingsSection: CaseIterable {
    case general
    case proxy
    case subscription
    case advanced
    case about
    
    var title: String {
        switch self {
        case .general:
            return NSLocalizedString("General", comment: "")
        case .proxy:
            return NSLocalizedString("Proxy", comment: "")
        case .subscription:
            return NSLocalizedString("Subscription", comment: "")
        case .advanced:
            return NSLocalizedString("Advanced", comment: "")
        case .about:
            return NSLocalizedString("About", comment: "")
        }
    }
    
    var icon: String {
        switch self {
        case .general:
            return "gearshape"
        case .proxy:
            return "network"
        case .subscription:
            return "arrow.triangle.2.circlepath"
        case .advanced:
            return "slider.horizontal.3"
        case .about:
            return "info.circle"
        }
    }
}
```

### 4. 通用设置视图

```swift
// MARK: - 通用设置视图
struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("launch_at_login") private var launchAtLogin = false
    @AppStorage("auto_check_update") private var autoCheckUpdate = true
    @AppStorage("show_dock_icon") private var showDockIcon = false
    
    var body: some View {
        Form {
            Section("外观") {
                HStack {
                    Text("主题")
                    Spacer()
                    Picker("主题", selection: $appState.currentTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                
                HStack {
                    Text("语言")
                    Spacer()
                    Picker("语言", selection: $appState.currentLanguage) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            }
            
            Section("启动") {
                Toggle("开机自启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
                
                Toggle("显示Dock图标", isOn: $showDockIcon)
                    .onChange(of: showDockIcon) { newValue in
                        setDockIconVisibility(newValue)
                    }
            }
            
            Section("更新") {
                Toggle("自动检查更新", isOn: $autoCheckUpdate)
                
                HStack {
                    Button("检查更新") {
                        checkForUpdates()
                    }
                    
                    Spacer()
                    
                    Text("当前版本: \(Bundle.main.appVersion)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 500)
    }
    
    // MARK: - 设置开机自启动
    private func setLaunchAtLogin(_ enabled: Bool) {
        let identifier = "com.v2rayu.launcher"
        
        if enabled {
            // 添加到登录项
            if let bundleURL = Bundle.main.bundleURL {
                LSSharedFileListInsertItemURL(
                    LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems, nil)?.takeRetainedValue(),
                    kLSSharedFileListItemLast,
                    nil,
                    nil,
                    bundleURL as CFURL,
                    nil,
                    nil
                )
            }
        } else {
            // 从登录项移除
            // 实现移除逻辑
        }
    }
    
    // MARK: - 设置Dock图标可见性
    private func setDockIconVisibility(_ visible: Bool) {
        if visible {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    // MARK: - 检查更新
    private func checkForUpdates() {
        // 实现更新检查逻辑
    }
}

// MARK: - Bundle扩展
extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}
```

### 5. 代理设置视图

```swift
// MARK: - 代理设置视图
struct ProxySettingsView: View {
    @StateObject private var viewModel = ProxySettingsViewModel()
    @State private var showingAddProxy = false
    @State private var selectedProxy: ProxyConfig?
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbar
            
            Divider()
            
            // 代理列表
            proxyList
        }
        .sheet(isPresented: $showingAddProxy) {
            ProxyEditView(proxy: nil) { proxy in
                viewModel.addProxy(proxy)
            }
        }
        .sheet(item: $selectedProxy) { proxy in
            ProxyEditView(proxy: proxy) { updatedProxy in
                viewModel.updateProxy(updatedProxy)
            }
        }
        .onAppear {
            viewModel.loadProxies()
        }
    }
    
    // MARK: - 工具栏
    private var toolbar: some View {
        HStack {
            Button(action: { showingAddProxy = true }) {
                Label("添加代理", systemImage: "plus")
            }
            
            Button(action: viewModel.importFromClipboard) {
                Label("从剪贴板导入", systemImage: "doc.on.clipboard")
            }
            .disabled(viewModel.isLoading)
            
            Button(action: viewModel.exportToClipboard) {
                Label("导出到剪贴板", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.proxies.isEmpty)
            
            Spacer()
            
            Button(action: viewModel.testAllProxies) {
                Label("测试全部", systemImage: "speedometer")
            }
            .disabled(viewModel.isLoading || viewModel.proxies.isEmpty)
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
    }
    
    // MARK: - 代理列表
    private var proxyList: some View {
        Table(viewModel.proxies) {
            TableColumn("名称") { proxy in
                Text(proxy.name)
            }
            .width(min: 100, ideal: 150)
            
            TableColumn("类型") { proxy in
                Text(proxy.protocolType.displayName)
            }
            .width(80)
            
            TableColumn("服务器") { proxy in
                Text("\(proxy.serverAddress):\(proxy.serverPort)")
            }
            .width(min: 120, ideal: 200)
            
            TableColumn("延迟") { proxy in
                if let latency = proxy.latency {
                    Text("\(latency)ms")
                        .foregroundColor(latencyColor(latency))
                } else {
                    Text("未测试")
                        .foregroundColor(.secondary)
                }
            }
            .width(80)
            
            TableColumn("操作") { proxy in
                HStack {
                    Button("编辑") {
                        selectedProxy = proxy
                    }
                    .buttonStyle(.borderless)
                    
                    Button("删除") {
                        viewModel.deleteProxy(proxy)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
            }
            .width(100)
        }
        .contextMenu(forSelectionType: ProxyConfig.ID.self) { selection in
            if selection.count == 1, let proxyId = selection.first,
               let proxy = viewModel.proxies.first(where: { $0.id == proxyId }) {
                Button("编辑") {
                    selectedProxy = proxy
                }
                
                Button("复制分享链接") {
                    viewModel.copyShareURL(proxy)
                }
                
                Divider()
                
                Button("删除") {
                    viewModel.deleteProxy(proxy)
                }
            }
        }
    }
    
    // MARK: - 延迟颜色
    private func latencyColor(_ latency: Int) -> Color {
        switch latency {
        case 0..<100:
            return .green
        case 100..<300:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - 代理设置视图模型
class ProxySettingsViewModel: BaseViewModel {
    @Published var proxies: [ProxyConfig] = []
    
    @Inject private var proxyHandler: ProxyHandler
    @Inject private var configParser: ConfigParser
    
    // MARK: - 加载代理
    func loadProxies() {
        Task {
            setLoading(true)
            do {
                let loadedProxies = try await proxyHandler.getAllProxies()
                DispatchQueue.main.async {
                    self.proxies = loadedProxies
                    self.setLoading(false)
                }
            } catch {
                handleError(error)
            }
        }
    }
    
    // MARK: - 添加代理
    func addProxy(_ proxy: ProxyConfig) {
        Task {
            do {
                try await proxyHandler.addProxy(proxy)
                await loadProxies()
            } catch {
                handleError(error)
            }
        }
    }
    
    // MARK: - 更新代理
    func updateProxy(_ proxy: ProxyConfig) {
        Task {
            do {
                try await proxyHandler.updateProxy(proxy)
                await loadProxies()
            } catch {
                handleError(error)
            }
        }
    }
    
    // MARK: - 删除代理
    func deleteProxy(_ proxy: ProxyConfig) {
        Task {
            do {
                try await proxyHandler.deleteProxy(proxy.id)
                await loadProxies()
            } catch {
                handleError(error)
            }
        }
    }
    
    // MARK: - 从剪贴板导入
    func importFromClipboard() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
            return
        }
        
        Task {
            setLoading(true)
            do {
                let importedProxies = try configParser.parseSubscriptionContent(clipboardString)
                for proxy in importedProxies {
                    try await proxyHandler.addProxy(proxy)
                }
                await loadProxies()
            } catch {
                handleError(error)
            }
        }
    }
    
    // MARK: - 导出到剪贴板
    func exportToClipboard() {
        Task {
            do {
                let exportString = try configParser.exportProxies(proxies)
                DispatchQueue.main.async {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(exportString, forType: .string)
                }
            } catch {
                handleError(error)
            }
        }
    }
    
    // MARK: - 测试所有代理
    func testAllProxies() {
        Task {
            setLoading(true)
            do {
                try await proxyHandler.batchTestProxies(proxies)
                await loadProxies()
            } catch {
                handleError(error)
            }
        }
    }
    
    // MARK: - 复制分享链接
    func copyShareURL(_ proxy: ProxyConfig) {
        Task {
            do {
                let shareURL = try ProtocolManager.shared.generateShareURL(proxy)
                DispatchQueue.main.async {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(shareURL, forType: .string)
                }
            } catch {
                handleError(error)
            }
        }
    }
}
```

## 🎨 UI组件库

### 1. 自定义组件

```swift
// MARK: - 状态指示器
struct StatusIndicator: View {
    let status: ConnectionStatus
    let size: CGFloat
    
    init(_ status: ConnectionStatus, size: CGFloat = 8) {
        self.status = status
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(status.color.opacity(0.3), lineWidth: size * 0.2)
                    .scaleEffect(1.5)
                    .opacity(status == .connecting ? 1 : 0)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: status == .connecting
                    )
            )
    }
}

// MARK: - 协议标签
struct ProtocolBadge: View {
    let protocolType: ProxyType
    let size: BadgeSize
    
    enum BadgeSize {
        case small, medium, large
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 10
            case .large: return 12
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 1, leading: 3, bottom: 1, trailing: 3)
            case .medium: return EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
            case .large: return EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6)
            }
        }
    }
    
    var body: some View {
        Text(protocolType.displayName)
            .font(.system(size: size.fontSize, weight: .medium))
            .padding(size.padding)
            .background(protocolColor.opacity(0.2))
            .foregroundColor(protocolColor)
            .cornerRadius(4)
    }
    
    private var protocolColor: Color {
        switch protocolType {
        case .vmess: return .blue
        case .vless: return .purple
        case .shadowsocks: return .green
        case .trojan: return .red
        case .http: return .orange
        case .socks5: return .gray
        }
    }
}

// MARK: - 延迟指示器
struct LatencyIndicator: View {
    let latency: Int?
    let showText: Bool
    
    init(_ latency: Int?, showText: Bool = true) {
        self.latency = latency
        self.showText = showText
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // 信号强度图标
            signalBars
            
            if showText {
                if let latency = latency {
                    Text("\(latency)ms")
                        .font(.caption2)
                        .foregroundColor(latencyColor)
                } else {
                    Text("--")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var signalBars: some View {
        HStack(spacing: 1) {
            ForEach(0..<4) { index in
                Rectangle()
                    .fill(barColor(for: index))
                    .frame(width: 2, height: CGFloat(2 + index * 2))
            }
        }
    }
    
    private func barColor(for index: Int) -> Color {
        guard let latency = latency else {
            return .secondary.opacity(0.3)
        }
        
        let strength = latencyStrength(latency)
        return index < strength ? latencyColor : .secondary.opacity(0.3)
    }
    
    private func latencyStrength(_ latency: Int) -> Int {
        switch latency {
        case 0..<50: return 4
        case 50..<100: return 3
        case 100..<200: return 2
        case 200..<500: return 1
        default: return 0
        }
    }
    
    private var latencyColor: Color {
        guard let latency = latency else {
            return .secondary
        }
        
        switch latency {
        case 0..<100: return .green
        case 100..<300: return .orange
        default: return .red
        }
    }
}

// MARK: - 流量显示器
struct TrafficDisplay: View {
    let upload: String
    let download: String
    let style: DisplayStyle
    
    enum DisplayStyle {
        case horizontal, vertical
    }
    
    var body: some View {
        Group {
            if style == .horizontal {
                HStack(spacing: 8) {
                    trafficItem("↑", upload, .green)
                    trafficItem("↓", download, .blue)
                }
            } else {
                VStack(spacing: 2) {
                    trafficItem("↑", upload, .green)
                    trafficItem("↓", download, .blue)
                }
            }
        }
    }
    
    private func trafficItem(_ icon: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 2) {
            Text(icon)
                .foregroundColor(color)
                .font(.caption2)
            Text(value)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
```

## 📚 相关文档

- [应用架构模块](app-architecture.md)
- [数据库层模块](database-layer.md)
- [处理器层模块](handler-layer.md)
- [协议层模块](protocol-layer.md)
- [基础工具模块](base-utilities.md)

---

*本文档详细介绍了V2rayU视图层的设计与实现，为开发者提供了完整的SwiftUI界面开发解决方案。*
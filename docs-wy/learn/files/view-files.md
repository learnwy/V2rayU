# 视图文件详解

## 📋 概述

本文档详细解析V2rayU项目中的视图文件，包括SwiftUI界面组件、自定义控件、布局管理和用户交互的实现细节。

## 🏗️ 视图分类

### 1. 主界面视图
- `ContentView.swift` - 主界面容器
- `MainView.swift` - 主要内容视图
- `SidebarView.swift` - 侧边栏视图
- `DetailView.swift` - 详情视图

### 2. 服务器管理视图
- `ServerListView.swift` - 服务器列表
- `ServerRowView.swift` - 服务器行视图
- `ServerDetailView.swift` - 服务器详情
- `AddServerView.swift` - 添加服务器

### 3. 订阅管理视图
- `SubscriptionListView.swift` - 订阅列表
- `SubscriptionDetailView.swift` - 订阅详情
- `AddSubscriptionView.swift` - 添加订阅

### 4. 设置界面视图
- `SettingsView.swift` - 设置主界面
- `GeneralSettingsView.swift` - 通用设置
- `ProxySettingsView.swift` - 代理设置
- `AdvancedSettingsView.swift` - 高级设置

### 5. 工具视图
- `PingTestView.swift` - 延迟测试
- `TrafficStatsView.swift` - 流量统计
- `LogView.swift` - 日志查看
- `AboutView.swift` - 关于界面

### 6. 通用组件
- `CustomButton.swift` - 自定义按钮
- `StatusIndicator.swift` - 状态指示器
- `ProgressView.swift` - 进度视图
- `AlertView.swift` - 警告视图

## 📁 详细视图解析

### 1. ContentView.swift

**文件路径**: `V2rayU/Views/ContentView.swift`

**功能描述**: 应用的根视图，管理整体布局和导航结构。

```swift
import SwiftUI

/// 应用主视图
struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var serverManager = ServerManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var proxyManager = ProxyManager.shared
    
    @State private var selectedSidebarItem: SidebarItem? = .servers
    @State private var selectedServerID: UUID?
    @State private var showingSettings = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationSplitView {
            // 侧边栏
            SidebarView(
                selectedItem: $selectedSidebarItem,
                selectedServerID: $selectedServerID
            )
            .navigationSplitViewColumnWidth(
                min: 200,
                ideal: 250,
                max: 300
            )
        } content: {
            // 主内容区域
            MainContentView(
                selectedItem: selectedSidebarItem,
                selectedServerID: $selectedServerID
            )
            .navigationSplitViewColumnWidth(
                min: 300,
                ideal: 400,
                max: 500
            )
        } detail: {
            // 详情区域
            DetailView(
                selectedItem: selectedSidebarItem,
                selectedServerID: selectedServerID
            )
            .navigationSplitViewColumnWidth(min: 400)
        }
        .navigationTitle("V2rayU")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // 连接状态
                ConnectionStatusView()
                
                Divider()
                
                // 快速操作按钮
                QuickActionButtons(
                    showingSettings: $showingSettings,
                    showingAbout: $showingAbout
                )
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .environmentObject(appState)
        .environmentObject(serverManager)
        .environmentObject(subscriptionManager)
        .environmentObject(proxyManager)
        .onAppear {
            setupInitialState()
        }
        .onChange(of: appState.isConnected) { isConnected in
            updateConnectionState(isConnected)
        }
    }
    
    // MARK: - 私有方法
    
    private func setupInitialState() {
        // 加载保存的选择状态
        if let savedSelection = UserDefaults.standard.string(forKey: "selectedSidebarItem"),
           let sidebarItem = SidebarItem(rawValue: savedSelection) {
            selectedSidebarItem = sidebarItem
        }
        
        // 加载服务器数据
        Task {
            await serverManager.loadServers()
            await subscriptionManager.loadSubscriptions()
        }
    }
    
    private func updateConnectionState(_ isConnected: Bool) {
        // 更新菜单栏状态
        NotificationCenter.default.post(
            name: .connectionStateChanged,
            object: isConnected
        )
    }
}

// MARK: - 侧边栏项目
enum SidebarItem: String, CaseIterable, Identifiable {
    case servers = "servers"
    case subscriptions = "subscriptions"
    case routing = "routing"
    case logs = "logs"
    case statistics = "statistics"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .servers: return "服务器"
        case .subscriptions: return "订阅"
        case .routing: return "路由"
        case .logs: return "日志"
        case .statistics: return "统计"
        }
    }
    
    var icon: String {
        switch self {
        case .servers: return "server.rack"
        case .subscriptions: return "arrow.clockwise.circle"
        case .routing: return "point.topleft.down.curvedto.point.bottomright.up"
        case .logs: return "doc.text"
        case .statistics: return "chart.bar"
        }
    }
}

// MARK: - 连接状态视图
struct ConnectionStatusView: View {
    @EnvironmentObject private var proxyManager: ProxyManager
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
        )
    }
    
    private var statusColor: Color {
        switch proxyManager.connectionStatus {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .red
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch proxyManager.connectionStatus {
        case .connected: return "已连接"
        case .connecting: return "连接中"
        case .disconnected: return "未连接"
        case .error: return "错误"
        }
    }
}

// MARK: - 快速操作按钮
struct QuickActionButtons: View {
    @Binding var showingSettings: Bool
    @Binding var showingAbout: Bool
    
    @EnvironmentObject private var proxyManager: ProxyManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    var body: some View {
        HStack(spacing: 8) {
            // 连接/断开按钮
            Button(action: toggleConnection) {
                Image(systemName: proxyManager.isConnected ? "stop.circle.fill" : "play.circle.fill")
                    .foregroundColor(proxyManager.isConnected ? .red : .green)
            }
            .help(proxyManager.isConnected ? "断开连接" : "连接")
            
            // 更新订阅按钮
            Button(action: updateSubscriptions) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
            }
            .help("更新所有订阅")
            .disabled(subscriptionManager.isUpdating)
            
            // 设置按钮
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                    .foregroundColor(.secondary)
            }
            .help("设置")
            
            // 关于按钮
            Button(action: { showingAbout = true }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
            }
            .help("关于")
        }
    }
    
    private func toggleConnection() {
        Task {
            if proxyManager.isConnected {
                await proxyManager.disconnect()
            } else {
                await proxyManager.connect()
            }
        }
    }
    
    private func updateSubscriptions() {
        Task {
            await subscriptionManager.updateAllSubscriptions()
        }
    }
}

// MARK: - 主内容视图
struct MainContentView: View {
    let selectedItem: SidebarItem?
    @Binding var selectedServerID: UUID?
    
    var body: some View {
        Group {
            switch selectedItem {
            case .servers:
                ServerListView(selectedServerID: $selectedServerID)
            case .subscriptions:
                SubscriptionListView()
            case .routing:
                RoutingView()
            case .logs:
                LogView()
            case .statistics:
                StatisticsView()
            case .none:
                WelcomeView()
            }
        }
        .navigationTitle(selectedItem?.displayName ?? "V2rayU")
    }
}

// MARK: - 详情视图
struct DetailView: View {
    let selectedItem: SidebarItem?
    let selectedServerID: UUID?
    
    var body: some View {
        Group {
            switch selectedItem {
            case .servers:
                if let serverID = selectedServerID {
                    ServerDetailView(serverID: serverID)
                } else {
                    EmptyDetailView(message: "选择一个服务器查看详情")
                }
            case .subscriptions:
                SubscriptionDetailView()
            case .routing:
                RoutingDetailView()
            case .logs:
                LogDetailView()
            case .statistics:
                StatisticsDetailView()
            case .none:
                EmptyDetailView(message: "选择一个项目查看详情")
            }
        }
    }
}

// MARK: - 空详情视图
struct EmptyDetailView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.title2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

// MARK: - 欢迎视图
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image("AppIcon")
                .resizable()
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(spacing: 8) {
                Text("欢迎使用 V2rayU")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("一个简洁易用的 V2Ray 客户端")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                QuickStartButton(
                    title: "添加服务器",
                    icon: "plus.circle.fill",
                    color: .blue
                ) {
                    // 添加服务器逻辑
                }
                
                QuickStartButton(
                    title: "添加订阅",
                    icon: "link.circle.fill",
                    color: .green
                ) {
                    // 添加订阅逻辑
                }
                
                QuickStartButton(
                    title: "导入配置",
                    icon: "square.and.arrow.down.fill",
                    color: .orange
                ) {
                    // 导入配置逻辑
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

// MARK: - 快速开始按钮
struct QuickStartButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 280)
    }
}

#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
}
```

### 2. ServerListView.swift

**文件路径**: `V2rayU/Views/Servers/ServerListView.swift`

**功能描述**: 服务器列表视图，显示所有服务器并支持管理操作。

```swift
import SwiftUI

/// 服务器列表视图
struct ServerListView: View {
    @Binding var selectedServerID: UUID?
    
    @EnvironmentObject private var serverManager: ServerManager
    @EnvironmentObject private var proxyManager: ProxyManager
    
    @State private var searchText = ""
    @State private var sortOrder = ServerSortOrder.name
    @State private var showingAddServer = false
    @State private var showingImportSheet = false
    @State private var selectedServers = Set<UUID>()
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索和工具栏
            ServerListToolbar(
                searchText: $searchText,
                sortOrder: $sortOrder,
                showingAddServer: $showingAddServer,
                showingImportSheet: $showingImportSheet,
                selectedCount: selectedServers.count,
                onDeleteSelected: deleteSelectedServers,
                onTestSelected: testSelectedServers
            )
            
            Divider()
            
            // 服务器列表
            if filteredServers.isEmpty {
                EmptyServerListView(
                    hasServers: !serverManager.servers.isEmpty,
                    searchText: searchText
                )
            } else {
                ServerList(
                    servers: filteredServers,
                    selectedServerID: $selectedServerID,
                    selectedServers: $selectedServers,
                    sortOrder: sortOrder
                )
            }
        }
        .sheet(isPresented: $showingAddServer) {
            AddServerView()
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportConfigView()
        }
        .alert("删除服务器", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                performDeleteSelectedServers()
            }
        } message: {
            Text("确定要删除选中的 \(selectedServers.count) 个服务器吗？此操作无法撤销。")
        }
        .onAppear {
            loadServers()
        }
    }
    
    // MARK: - 计算属性
    
    private var filteredServers: [ServerConfig] {
        let filtered = serverManager.servers.filter { server in
            if searchText.isEmpty {
                return true
            }
            return server.name.localizedCaseInsensitiveContains(searchText) ||
                   server.address.localizedCaseInsensitiveContains(searchText) ||
                   server.group?.localizedCaseInsensitiveContains(searchText) == true
        }
        
        return filtered.sorted { lhs, rhs in
            switch sortOrder {
            case .name:
                return lhs.name < rhs.name
            case .address:
                return lhs.address < rhs.address
            case .protocol:
                return lhs.protocol.rawValue < rhs.protocol.rawValue
            case .ping:
                let lhsPing = lhs.lastPingTime ?? Double.infinity
                let rhsPing = rhs.lastPingTime ?? Double.infinity
                return lhsPing < rhsPing
            case .group:
                let lhsGroup = lhs.group ?? ""
                let rhsGroup = rhs.group ?? ""
                return lhsGroup < rhsGroup
            case .lastUsed:
                let lhsUsed = lhs.lastUsed ?? Date.distantPast
                let rhsUsed = rhs.lastUsed ?? Date.distantPast
                return lhsUsed > rhsUsed
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func loadServers() {
        Task {
            await serverManager.loadServers()
        }
    }
    
    private func deleteSelectedServers() {
        if !selectedServers.isEmpty {
            showingDeleteAlert = true
        }
    }
    
    private func performDeleteSelectedServers() {
        Task {
            await serverManager.deleteServers(selectedServers)
            selectedServers.removeAll()
        }
    }
    
    private func testSelectedServers() {
        Task {
            await serverManager.testServers(selectedServers)
        }
    }
}

// MARK: - 服务器排序
enum ServerSortOrder: String, CaseIterable {
    case name = "name"
    case address = "address"
    case `protocol` = "protocol"
    case ping = "ping"
    case group = "group"
    case lastUsed = "lastUsed"
    
    var displayName: String {
        switch self {
        case .name: return "名称"
        case .address: return "地址"
        case .protocol: return "协议"
        case .ping: return "延迟"
        case .group: return "分组"
        case .lastUsed: return "最近使用"
        }
    }
    
    var icon: String {
        switch self {
        case .name: return "textformat"
        case .address: return "globe"
        case .protocol: return "network"
        case .ping: return "speedometer"
        case .group: return "folder"
        case .lastUsed: return "clock"
        }
    }
}

// MARK: - 服务器列表工具栏
struct ServerListToolbar: View {
    @Binding var searchText: String
    @Binding var sortOrder: ServerSortOrder
    @Binding var showingAddServer: Bool
    @Binding var showingImportSheet: Bool
    
    let selectedCount: Int
    let onDeleteSelected: () -> Void
    let onTestSelected: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索服务器...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.1))
            )
            
            // 工具栏
            HStack {
                // 排序选择器
                Menu {
                    ForEach(ServerSortOrder.allCases, id: \.self) { order in
                        Button(action: { sortOrder = order }) {
                            HStack {
                                Image(systemName: order.icon)
                                Text(order.displayName)
                                if sortOrder == order {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortOrder.displayName)
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                
                Spacer()
                
                // 批量操作按钮
                if selectedCount > 0 {
                    HStack(spacing: 8) {
                        Text("\(selectedCount) 个已选中")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("测试", action: onTestSelected)
                            .font(.caption)
                        
                        Button("删除", action: onDeleteSelected)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } else {
                    // 添加按钮
                    HStack(spacing: 8) {
                        Button(action: { showingAddServer = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("添加")
                            }
                            .font(.caption)
                        }
                        
                        Button(action: { showingImportSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down")
                                Text("导入")
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - 服务器列表
struct ServerList: View {
    let servers: [ServerConfig]
    @Binding var selectedServerID: UUID?
    @Binding var selectedServers: Set<UUID>
    let sortOrder: ServerSortOrder
    
    @EnvironmentObject private var proxyManager: ProxyManager
    
    var body: some View {
        List(servers, id: \.id, selection: $selectedServerID) { server in
            ServerRowView(
                server: server,
                isSelected: selectedServers.contains(server.id),
                isActive: proxyManager.activeServerID == server.id,
                onToggleSelection: {
                    toggleSelection(for: server.id)
                },
                onConnect: {
                    connectToServer(server)
                }
            )
            .tag(server.id)
        }
        .listStyle(PlainListStyle())
        .contextMenu(forSelectionType: UUID.self) { selection in
            if selection.count == 1, let serverID = selection.first {
                ServerContextMenu(serverID: serverID)
            } else if selection.count > 1 {
                MultiServerContextMenu(serverIDs: selection)
            }
        }
    }
    
    private func toggleSelection(for serverID: UUID) {
        if selectedServers.contains(serverID) {
            selectedServers.remove(serverID)
        } else {
            selectedServers.insert(serverID)
        }
    }
    
    private func connectToServer(_ server: ServerConfig) {
        Task {
            await proxyManager.connect(to: server)
        }
    }
}

// MARK: - 空服务器列表视图
struct EmptyServerListView: View {
    let hasServers: Bool
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasServers ? "magnifyingglass" : "server.rack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(hasServers ? "未找到服务器" : "暂无服务器")
                    .font(.title2)
                    .fontWeight(.medium)
                
                if hasServers {
                    Text("尝试修改搜索条件")
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    Text("点击添加按钮开始添加服务器")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ServerListView(selectedServerID: .constant(nil))
        .environmentObject(ServerManager.shared)
        .environmentObject(ProxyManager.shared)
        .frame(width: 400, height: 600)
}
```

### 3. ServerRowView.swift

**文件路径**: `V2rayU/Views/Servers/ServerRowView.swift`

**功能描述**: 服务器行视图，显示单个服务器的信息和状态。

```swift
import SwiftUI

/// 服务器行视图
struct ServerRowView: View {
    let server: ServerConfig
    let isSelected: Bool
    let isActive: Bool
    let onToggleSelection: () -> Void
    let onConnect: () -> Void
    
    @State private var isHovered = false
    @State private var showingPingAnimation = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 选择框
            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 协议图标
            ProtocolIcon(protocol: server.protocol)
            
            // 服务器信息
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(server.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Text(server.formattedAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let group = server.group {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(group)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // 延迟信息
            PingIndicator(
                ping: server.lastPingTime,
                status: server.pingStatus,
                isAnimating: showingPingAnimation
            )
            
            // 连接按钮
            if isHovered || isActive {
                Button(action: onConnect) {
                    Image(systemName: isActive ? "stop.circle" : "play.circle")
                        .foregroundColor(isActive ? .red : .green)
                }
                .buttonStyle(PlainButtonStyle())
                .help(isActive ? "断开连接" : "连接到此服务器")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(rowBorderColor, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            ServerRowContextMenu(
                server: server,
                onConnect: onConnect,
                onStartPing: startPingTest
            )
        }
    }
    
    // MARK: - 计算属性
    
    private var rowBackgroundColor: Color {
        if isActive {
            return Color.green.opacity(0.1)
        } else if isSelected {
            return Color.blue.opacity(0.1)
        } else if isHovered {
            return Color.secondary.opacity(0.05)
        } else {
            return Color.clear
        }
    }
    
    private var rowBorderColor: Color {
        if isActive {
            return Color.green.opacity(0.3)
        } else if isSelected {
            return Color.blue.opacity(0.3)
        } else {
            return Color.clear
        }
    }
    
    // MARK: - 私有方法
    
    private func startPingTest() {
        withAnimation(.easeInOut(duration: 0.5).repeatCount(3)) {
            showingPingAnimation = true
        }
        
        Task {
            await ServerManager.shared.testServer(server.id)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showingPingAnimation = false
            }
        }
    }
}

// MARK: - 协议图标
struct ProtocolIcon: View {
    let `protocol`: ProxyProtocol
    
    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
            .font(.title3)
            .frame(width: 20, height: 20)
    }
    
    private var iconName: String {
        switch `protocol` {
        case .vmess: return "v.circle.fill"
        case .vless: return "v.circle"
        case .trojan: return "t.circle.fill"
        case .shadowsocks: return "s.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch `protocol` {
        case .vmess: return .blue
        case .vless: return .purple
        case .trojan: return .red
        case .shadowsocks: return .orange
        }
    }
}

// MARK: - 延迟指示器
struct PingIndicator: View {
    let ping: TimeInterval?
    let status: PingStatus
    let isAnimating: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.5 : 1.0)
                .opacity(isAnimating ? 0.5 : 1.0)
            
            Text(pingText)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(minWidth: 40, alignment: .trailing)
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .unknown: return .gray
        case .timeout: return .red
        case .excellent: return .green
        case .good: return .yellow
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    private var pingText: String {
        guard let ping = ping, ping >= 0 else {
            return status == .timeout ? "超时" : "--"
        }
        return "\(Int(ping))ms"
    }
}

// MARK: - 服务器行右键菜单
struct ServerRowContextMenu: View {
    let server: ServerConfig
    let onConnect: () -> Void
    let onStartPing: () -> Void
    
    @EnvironmentObject private var proxyManager: ProxyManager
    
    var body: some View {
        Group {
            Button(action: onConnect) {
                HStack {
                    Image(systemName: isActive ? "stop.circle" : "play.circle")
                    Text(isActive ? "断开连接" : "连接")
                }
            }
            
            Button(action: onStartPing) {
                HStack {
                    Image(systemName: "speedometer")
                    Text("测试延迟")
                }
            }
            
            Divider()
            
            Button(action: editServer) {
                HStack {
                    Image(systemName: "pencil")
                    Text("编辑")
                }
            }
            
            Button(action: duplicateServer) {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("复制")
                }
            }
            
            Button(action: shareServer) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("分享")
                }
            }
            
            Divider()
            
            Button(action: deleteServer) {
                HStack {
                    Image(systemName: "trash")
                    Text("删除")
                }
            }
            .foregroundColor(.red)
        }
    }
    
    private var isActive: Bool {
        proxyManager.activeServerID == server.id
    }
    
    private func editServer() {
        // 编辑服务器逻辑
        NotificationCenter.default.post(
            name: .editServer,
            object: server.id
        )
    }
    
    private func duplicateServer() {
        Task {
            await ServerManager.shared.duplicateServer(server.id)
        }
    }
    
    private func shareServer() {
        // 分享服务器逻辑
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(server.connectionURL, forType: .string)
    }
    
    private func deleteServer() {
        Task {
            await ServerManager.shared.deleteServer(server.id)
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        ServerRowView(
            server: ServerConfig(
                name: "测试服务器",
                address: "example.com",
                port: 443,
                protocol: .vmess,
                protocolSettings: .vmess(VMessConfig(
                    uuid: "12345678-1234-1234-1234-123456789abc",
                    alterId: 0,
                    security: "auto"
                ))
            ),
            isSelected: false,
            isActive: false,
            onToggleSelection: {},
            onConnect: {}
        )
        
        ServerRowView(
            server: ServerConfig(
                name: "活动服务器",
                address: "active.example.com",
                port: 443,
                protocol: .vless,
                protocolSettings: .vless(VLESSConfig(
                    uuid: "87654321-4321-4321-4321-cba987654321",
                    encryption: "none",
                    flow: nil
                ))
            ),
            isSelected: true,
            isActive: true,
            onToggleSelection: {},
            onConnect: {}
        )
    }
    .padding()
    .frame(width: 400)
}
```

## 🎨 视图设计原则

### 1. SwiftUI最佳实践
- **声明式UI**: 使用声明式语法描述界面
- **状态管理**: 合理使用@State、@Binding、@ObservedObject
- **组件化**: 将复杂视图拆分为小组件
- **性能优化**: 避免不必要的视图重绘

### 2. 用户体验设计
- **响应式布局**: 适配不同窗口尺寸
- **交互反馈**: 提供清晰的用户操作反馈
- **无障碍支持**: 支持VoiceOver和键盘导航
- **主题适配**: 支持浅色和深色主题

### 3. 视觉设计
- **一致性**: 保持视觉元素的一致性
- **层次结构**: 清晰的信息层次
- **色彩系统**: 合理的色彩搭配
- **图标使用**: 统一的图标风格

### 4. 代码组织
- **文件结构**: 按功能模块组织视图文件
- **命名规范**: 清晰的视图和属性命名
- **代码复用**: 提取公共视图组件
- **文档注释**: 为复杂视图添加注释

## 🔧 视图架构图

```
ContentView (根视图)
├── SidebarView (侧边栏)
│   ├── SidebarItemView
│   └── ServerGroupView
├── MainContentView (主内容)
│   ├── ServerListView
│   │   ├── ServerRowView
│   │   └── ServerListToolbar
│   ├── SubscriptionListView
│   └── SettingsView
└── DetailView (详情)
    ├── ServerDetailView
    ├── SubscriptionDetailView
    └── EmptyDetailView

通用组件 (Common Components)
├── CustomButton
├── StatusIndicator
├── ProgressView
├── AlertView
└── LoadingView
```

## 📚 扩展功能

### 1. 自定义修饰符
```swift
// 卡片样式修饰符
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .shadow(radius: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
```

### 2. 动画效果
```swift
// 连接状态动画
struct PulseAnimation: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .opacity(isAnimating ? 0.7 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}
```

### 3. 主题系统
```swift
// 主题管理
class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .system
    
    var primaryColor: Color {
        switch currentTheme {
        case .light: return .blue
        case .dark: return .cyan
        case .system: return .accentColor
        }
    }
}
```

SwiftUI视图系统为V2rayU提供了现代化、响应式的用户界面，通过合理的组件设计和状态管理，实现了流畅的用户体验。
# V2rayU 开发指南

本文档提供 V2rayU 项目的开发环境搭建、项目架构说明和开发流程指导。

## 开发环境要求

### 系统要求
- **macOS**: 12.0 或更高版本
- **Xcode**: 14.0 或更高版本
- **Swift**: 5.7 或更高版本

### 开发工具
- **Xcode**: 主要开发 IDE
- **Git**: 版本控制
- **Terminal**: 命令行工具

## 项目搭建

### 1. 克隆项目
```bash
git clone https://github.com/yanue/V2rayU.git
cd V2rayU
```

### 2. 打开项目
```bash
open V2rayU.xcodeproj
```

### 3. 配置开发环境

#### Swift Package Manager 依赖
项目使用 SPM 管理依赖，主要包括：
- **GRDB.swift**: SQLite 数据库 ORM
- **Sparkle**: 自动更新框架
- **其他系统框架**: SwiftUI, Combine, Network 等

#### 构建配置
- **Debug**: 开发调试配置
- **Release**: 发布配置
- **Target**: V2rayU (主应用) + V2rayUTool (系统工具)

### 4. 首次运行
1. 选择 V2rayU scheme
2. 按 `Cmd + R` 运行
3. 应用会提示安装系统组件，输入密码完成安装

## 项目架构

### 整体架构
```
V2rayU/
├── V2rayU/                 # 主应用代码
│   ├── App.swift          # 应用入口
│   ├── AppDelegate.swift  # 应用委托
│   ├── Database/          # 数据层
│   ├── Handler/           # 业务逻辑层
│   ├── Views/             # 视图层
│   └── Resources/         # 资源文件
├── V2rayUTool/            # 系统代理工具
├── Build/                 # 构建脚本
└── V2rayU.xcodeproj/      # Xcode 项目文件
```

### 架构模式

#### MVVM 架构
- **Model**: 数据模型 (`Database/Models/`)
- **ViewModel**: 视图模型 (`Database/ViewModels/`)
- **View**: SwiftUI 视图 (`Views/`)

#### 数据流
```
View ↔ ViewModel ↔ Model ↔ Database
     ↕
   Handler (业务逻辑)
```

### 核心模块

#### 1. 数据层 (Database)
```swift
// 主要文件
Database/
├── Database.swift         # 数据库管理
├── Migrate.swift         # 数据库迁移
├── Models/               # 数据模型
│   ├── ProfileModel.swift    # 服务器配置模型
│   ├── SubModel.swift        # 订阅模型
│   ├── RoutingModel.swift    # 路由规则模型
│   └── ProfileStatModel.swift # 统计数据模型
└── ViewModels/           # 视图模型
    ├── ProfileViewModel.swift
    ├── SubViewModel.swift
    └── RoutingViewModel.swift
```

#### 2. 业务逻辑层 (Handler)
```swift
Handler/
├── V2rayLaunch.swift         # V2ray 启动管理
├── V2rayConfigHandler.swift  # 配置文件生成
├── SubscriptionHandler.swift # 订阅管理
├── ImportHandler.swift       # 导入处理
├── ShareHandler.swift        # 分享功能
├── PacHandler.swift          # PAC 文件处理
├── RoutingHandler.swift      # 路由规则
├── HttpServer.swift          # HTTP 服务器
├── V2rayStats.swift          # 统计数据
├── V2rayOutboundHandler.swift # 出站配置
├── Tunnel.swift              # 隧道管理
└── Ping/                     # 延迟测试
    ├── Ping.swift
    ├── PingAll.swift
    └── PingRunning.swift
```

#### 3. 视图层 (Views)
```swift
Views/
├── AppMenu/              # 菜单相关视图
├── Base/                 # 基础组件
├── Log/                  # 日志视图
├── Overview/             # 概览页面
├── Profile/              # 服务器配置
├── Routing/              # 路由规则
├── Setting/              # 设置页面
└── Subscription/         # 订阅管理
```

## 开发流程

### 代码规范

#### Swift 编码规范
- 使用 4 空格缩进
- 类名使用 PascalCase
- 变量和函数使用 camelCase
- 常量使用 UPPER_SNAKE_CASE
- 遵循 Swift API Design Guidelines

#### SwiftUI 最佳实践
```swift
// 视图组件示例
struct ProfileListView: View {
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.profiles) { profile in
                ProfileRowView(profile: profile)
            }
            .navigationTitle("服务器列表")
        }
        .onAppear {
            viewModel.loadProfiles()
        }
    }
}
```

#### 数据模型设计
```swift
// 模型示例
struct ProfileModel: Codable, Identifiable {
    let id = UUID()
    var remark: String
    var address: String
    var port: Int
    var protocol: ProxyProtocol
    
    // 业务逻辑方法
    func generateConfig() -> [String: Any] {
        // 配置生成逻辑
    }
}
```

### 调试技巧

#### 1. 日志系统
```swift
// 使用统一的日志系统
NSLog("[V2rayU] 启动代理: \(profile.remark)")

// 查看日志文件
tail -f ~/.V2rayU/V2rayU.log
tail -f ~/.V2rayU/v2ray-core.log
```

#### 2. 断点调试
- 在 Xcode 中设置断点
- 使用 `po` 命令查看变量值
- 利用 View Hierarchy 调试 UI

#### 3. 网络调试
```bash
# 检查代理设置
networksetup -getwebproxy "Wi-Fi"
networksetup -getsecurewebproxy "Wi-Fi"

# 测试代理连接
curl -x http://127.0.0.1:1087 https://www.google.com
```

### 测试策略

#### 单元测试
```swift
// 测试示例
class ProfileModelTests: XCTestCase {
    func testProfileCreation() {
        let profile = ProfileModel(
            remark: "测试服务器",
            address: "example.com",
            port: 443,
            protocol: .vmess
        )
        
        XCTAssertEqual(profile.remark, "测试服务器")
        XCTAssertEqual(profile.port, 443)
    }
}
```

#### 集成测试
- 测试订阅更新流程
- 测试代理启动/停止
- 测试配置文件生成

### 构建和发布

#### Debug 构建
```bash
# 命令行构建
xcodebuild -project V2rayU.xcodeproj -scheme V2rayU -configuration Debug
```

#### Release 构建
```bash
# 发布构建
xcodebuild -project V2rayU.xcodeproj -scheme V2rayU -configuration Release
```

#### 代码签名
- 配置开发者证书
- 设置 Bundle Identifier
- 配置 Entitlements

## 常见开发问题

### 1. 权限问题
```swift
// 需要的权限
- com.apple.security.network.client
- com.apple.security.network.server
- com.apple.security.files.user-selected.read-write
```

### 2. 系统代理设置
```swift
// V2rayUTool 需要管理员权限
// 使用 AuthorizationExecuteWithPrivileges 执行
```

### 3. 数据库迁移
```swift
// 版本升级时的数据库迁移
func migrate() {
    // 检查数据库版本
    // 执行迁移脚本
    // 更新版本号
}
```

### 4. 内存管理
```swift
// 避免循环引用
class ViewModel: ObservableObject {
    weak var delegate: ViewModelDelegate?
    
    deinit {
        // 清理资源
    }
}
```

## 性能优化

### 1. SwiftUI 性能
- 使用 `@StateObject` 而非 `@ObservedObject`
- 避免在 `body` 中创建复杂对象
- 合理使用 `@State` 和 `@Binding`

### 2. 数据库优化
- 使用索引优化查询
- 批量操作减少 I/O
- 合理使用事务

### 3. 网络优化
- 使用连接池
- 实现请求缓存
- 异步处理网络请求

## 贡献指南

### 提交代码
1. Fork 项目
2. 创建功能分支
3. 提交代码
4. 创建 Pull Request

### 代码审查
- 确保代码符合规范
- 添加必要的测试
- 更新相关文档

### 问题报告
- 使用 Issue 模板
- 提供详细的重现步骤
- 附加相关日志信息

## 相关资源

- [Swift 官方文档](https://swift.org/documentation/)
- [SwiftUI 教程](https://developer.apple.com/tutorials/swiftui)
- [V2ray 官方文档](https://www.v2ray.com/)
- [GRDB 文档](https://github.com/groue/GRDB.swift)

## 联系方式

如有开发相关问题，可以通过以下方式联系：
- GitHub Issues
- 项目讨论区
- 开发者邮箱
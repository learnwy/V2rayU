# V2rayU 项目学习指南

本指南将帮助你系统性地学习和理解 V2rayU 项目，从基础概念到深入的代码分析。

## 学习路径规划

### 阶段一：基础理解 (1-2 天)

#### 1. 了解项目背景
- **V2ray 协议**: 了解 V2ray 的基本概念和工作原理
- **代理技术**: 理解 HTTP/SOCKS 代理、透明代理的区别
- **macOS 系统代理**: 学习 macOS 网络代理设置机制

#### 2. 熟悉技术栈
- **SwiftUI**: 现代化的 UI 框架
- **Combine**: 响应式编程框架
- **GRDB**: SQLite 数据库 ORM
- **Swift Package Manager**: 依赖管理

#### 3. 运行项目
- 按照 [DEVELOPMENT.md](./DEVELOPMENT.md) 搭建开发环境
- 成功运行项目并体验基本功能
- 观察应用的菜单栏交互和主要界面

### 阶段二：架构分析 (2-3 天)

#### 1. 项目结构概览
```
V2rayU/
├── App.swift              # 应用入口点
├── AppDelegate.swift      # 应用生命周期管理
├── Database/              # 数据层
├── Handler/               # 业务逻辑层
├── Views/                 # 用户界面层
└── Resources/             # 资源文件
```

#### 2. 架构模式理解
- **MVVM 模式**: Model-View-ViewModel 的实现
- **数据流向**: View → ViewModel → Handler → Model
- **状态管理**: 使用 `@StateObject`, `@ObservedObject`, `@Published`

### 阶段三：核心模块深入 (3-5 天)

#### 1. 应用启动流程

**关键文件**: `App.swift`, `AppDelegate.swift`

```swift
// 学习重点
1. SwiftUI App 生命周期
2. MenuBarExtra 的使用
3. 窗口管理机制
4. 应用初始化流程
```

**代码分析路径**:
1. `App.swift` → 应用入口和 UI 结构
2. `AppDelegate.swift` → 系统事件处理
3. `V2rayLaunch.swift` → 核心组件安装和启动

#### 2. 数据模型设计

**关键文件**: `Database/Models/`

```swift
// 核心模型
ProfileModel.swift     # 服务器配置模型
SubModel.swift         # 订阅模型  
RoutingModel.swift     # 路由规则模型
ProfileStatModel.swift # 统计数据模型
```

**学习重点**:
- 数据模型的设计原则
- Codable 协议的使用
- 数据库映射关系
- 模型间的关联关系

#### 3. 业务逻辑核心

**关键文件**: `Handler/`

##### V2ray 核心管理 (`V2rayLaunch.swift`)
```swift
// 学习重点
1. checkInstall()      # 检查和安装核心组件
2. ToggleRunning()     # 启动/停止代理
3. restartV2ray()      # 重启服务
4. SwitchProxyMode()   # 切换代理模式
```

##### 配置文件生成 (`V2rayConfigHandler.swift`)
```swift
// 学习重点
1. 配置文件结构理解
2. 不同协议的配置差异
3. 路由规则的应用
4. JSON 配置的动态生成
```

##### 订阅管理 (`SubscriptionHandler.swift`)
```swift
// 学习重点
1. sync()              # 订阅同步机制
2. dlFromUrl()         # 网络请求处理
3. handle()            # 数据解析和导入
4. 并发处理和错误处理
```

#### 4. 用户界面设计

**关键目录**: `Views/`

```swift
// UI 模块分析
AppMenu/        # 菜单栏相关视图
Profile/        # 服务器配置界面
Subscription/   # 订阅管理界面
Setting/        # 设置页面
Routing/        # 路由规则界面
```

**SwiftUI 学习重点**:
- 声明式 UI 设计
- 状态绑定和数据流
- 自定义组件封装
- 响应式布局

### 阶段四：高级特性 (2-3 天)

#### 1. 系统集成

**网络代理设置**:
```swift
// V2rayUTool 的作用
1. 系统代理配置
2. PAC 文件管理
3. 权限提升机制
```

**系统服务集成**:
```swift
// LaunchAgent 机制
1. 开机自启动
2. 后台服务管理
3. 进程间通信
```

#### 2. 网络功能

**延迟测试** (`Handler/Ping/`):
```swift
Ping.swift        # 单个服务器测试
PingAll.swift     # 批量测试
PingRunning.swift # 运行中测试
```

**流量统计** (`V2rayStats.swift`):
```swift
// 学习重点
1. V2ray API 调用
2. 实时数据获取
3. 统计数据存储
```

#### 3. 数据持久化

**数据库设计** (`Database/`):
```swift
Database.swift    # 数据库连接和管理
Migrate.swift     # 数据库版本迁移
```

**学习重点**:
- GRDB 的使用模式
- 数据库迁移策略
- 查询优化技巧

## 代码阅读顺序

### 第一轮：整体流程理解

1. **应用启动**
   ```
   App.swift → AppDelegate.swift → V2rayLaunch.checkInstall()
   ```

2. **数据模型**
   ```
   ProfileModel.swift → Database.swift → ProfileViewModel.swift
   ```

3. **核心功能**
   ```
   V2rayLaunch.swift → V2rayConfigHandler.swift → SubscriptionHandler.swift
   ```

### 第二轮：深入业务逻辑

1. **配置管理流程**
   ```
   ImportHandler.swift → ShareHandler.swift → V2rayOutboundHandler.swift
   ```

2. **网络功能**
   ```
   PacHandler.swift → HttpServer.swift → Tunnel.swift
   ```

3. **路由系统**
   ```
   RoutingHandler.swift → RoutingModel.swift → RoutingViewModel.swift
   ```

### 第三轮：UI 和交互

1. **主界面**
   ```
   Views/Overview/ → Views/Profile/ → Views/AppMenu/
   ```

2. **设置和配置**
   ```
   Views/Setting/ → Views/Subscription/ → Views/Routing/
   ```

## 关键概念理解

### 1. V2ray 配置结构

```json
{
  "inbounds": [    // 入站连接
    {
      "port": 1087,
      "protocol": "http"
    }
  ],
  "outbounds": [   // 出站连接
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [...]
      }
    }
  ],
  "routing": {     // 路由规则
    "rules": [...]
  }
}
```

### 2. 代理模式

- **PAC 模式**: 基于规则的智能分流
- **全局模式**: 所有流量通过代理
- **手动模式**: 仅设置代理端口，不修改系统设置

### 3. 协议支持

```swift
enum ProxyProtocol: String, CaseIterable {
    case vmess = "vmess"
    case vless = "vless"
    case trojan = "trojan"
    case shadowsocks = "shadowsocks"
    case socks = "socks"
    case http = "http"
}
```

## 实践练习

### 练习 1: 添加新的协议支持

**目标**: 为应用添加一个新的代理协议支持

**步骤**:
1. 在 `ProxyProtocol` 枚举中添加新协议
2. 修改 `ProfileModel` 支持新协议的配置
3. 更新 `V2rayConfigHandler` 生成对应配置
4. 在 UI 中添加新协议的配置界面

### 练习 2: 实现配置导出功能

**目标**: 添加将当前配置导出为文件的功能

**步骤**:
1. 在 `ShareHandler` 中添加导出方法
2. 实现配置序列化逻辑
3. 添加文件保存对话框
4. 在菜单中添加导出选项

### 练习 3: 优化订阅更新

**目标**: 改进订阅更新的用户体验

**步骤**:
1. 添加更新进度显示
2. 实现增量更新逻辑
3. 添加更新失败重试机制
4. 优化并发更新性能

## 调试技巧

### 1. 日志分析

```bash
# 实时查看应用日志
tail -f ~/.V2rayU/V2rayU.log

# 查看 V2ray 核心日志
tail -f ~/.V2rayU/v2ray-core.log

# 过滤特定类型的日志
grep "ERROR" ~/.V2rayU/V2rayU.log
```

### 2. 网络调试

```bash
# 检查代理设置
networksetup -getwebproxy "Wi-Fi"

# 测试代理连接
curl -x http://127.0.0.1:1087 https://httpbin.org/ip

# 查看网络连接
lsof -i :1087
```

### 3. 数据库调试

```bash
# 使用 sqlite3 查看数据库
sqlite3 ~/.V2rayU/.V2rayU.db

# 查看表结构
.schema profiles

# 查询数据
SELECT * FROM profiles LIMIT 5;
```

## 进阶学习资源

### 技术文档
- [V2ray 官方文档](https://www.v2ray.com/)
- [SwiftUI 官方教程](https://developer.apple.com/tutorials/swiftui)
- [Combine 框架指南](https://developer.apple.com/documentation/combine)
- [GRDB 使用指南](https://github.com/groue/GRDB.swift)

### 相关项目
- [V2rayX](https://github.com/Cenmrev/V2RayX) - 另一个 macOS V2ray 客户端
- [ClashX](https://github.com/yichengchen/clashX) - Clash 的 macOS 客户端
- [Qv2ray](https://github.com/Qv2ray/Qv2ray) - 跨平台 V2ray 客户端

### 学习社区
- GitHub Issues 和 Discussions
- V2ray 官方社区
- Swift 开发者社区

## 常见问题解答

### Q: 如何理解 SwiftUI 的数据绑定？

**A**: SwiftUI 使用 `@State`, `@Binding`, `@ObservedObject` 等属性包装器实现数据绑定。数据变化时会自动触发 UI 更新。

### Q: V2ray 配置文件是如何生成的？

**A**: 通过 `V2rayConfigHandler` 根据用户配置动态生成 JSON 格式的配置文件，包含入站、出站和路由规则。

### Q: 系统代理是如何设置的？

**A**: 通过 `V2rayUTool` 工具调用 macOS 的 `networksetup` 命令来修改系统网络设置。

### Q: 如何添加新的 UI 组件？

**A**: 在 `Views/` 目录下创建新的 SwiftUI 视图，遵循现有的命名和组织规范，使用 MVVM 模式连接数据。

## 总结

通过系统性地学习 V2rayU 项目，你将掌握：

1. **SwiftUI 应用开发**: 现代化的 macOS 应用开发技能
2. **网络编程**: 代理协议和网络配置的深入理解
3. **系统集成**: macOS 系统服务和权限管理
4. **数据库设计**: 移动应用的数据持久化方案
5. **架构设计**: MVVM 模式在实际项目中的应用

建议按照本指南的学习路径循序渐进，结合实际代码阅读和练习，逐步深入理解项目的各个方面。
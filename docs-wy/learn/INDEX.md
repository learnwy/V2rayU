# V2rayU 学习文档完整索引

本索引提供了 V2rayU 学习文档体系的完整导航，帮助您快速找到所需的学习资源。

## 📋 完整文档列表

### 🎯 学习路径 (Learning Paths)

```
learning-paths/
├── beginner-path.md          # 初学者学习路径
├── intermediate-path.md       # 中级开发者学习路径
├── advanced-path.md           # 高级开发者学习路径
└── architecture-deep-dive.md  # 架构深度解析
```

**适用人群**:
- `beginner-path.md`: Swift 新手、macOS 开发初学者
- `intermediate-path.md`: 有一定 Swift 经验的开发者
- `advanced-path.md`: 资深开发者、架构师、技术领导
- `architecture-deep-dive.md`: 所有希望深入理解架构的开发者

### 🏗️ 模块文档 (Modules)

```
modules/
├── app-architecture.md       # 应用架构模块 - MVVM + 分层架构
├── database-layer.md         # 数据库层模块 - GRDB + SQLite
├── handler-layer.md          # 处理器层模块 - 业务逻辑处理
├── protocol-layer.md         # 协议层模块 - 代理协议实现
├── view-layer.md             # 视图层模块 - SwiftUI 界面
└── base-utilities.md         # 基础工具模块 - 通用工具类
```

**核心概念**:
- **架构设计**: 分层架构、MVVM 模式、依赖注入
- **数据管理**: 数据库设计、迁移、查询优化
- **业务逻辑**: 服务管理、状态管理、事件处理
- **协议支持**: VMess、VLess、Trojan、Shadowsocks
- **用户界面**: SwiftUI、响应式设计、主题系统
- **基础设施**: 工具类、扩展方法、常量管理

### ⚡ 功能文档 (Features)

```
features/
├── proxy-management.md       # 代理管理 - 服务器配置和连接
├── subscription-sync.md      # 订阅同步 - 订阅源管理和更新
├── system-proxy.md           # 系统代理 - 系统级代理设置
├── traffic-stats.md          # 流量统计 - 网络流量监控
├── ping-testing.md           # 延迟测试 - 服务器延迟检测
├── routing-rules.md          # 路由规则 - 智能路由配置
├── log-management.md         # 日志管理 - 日志记录和分析
└── settings-config.md        # 设置配置 - 应用设置管理
```

**功能特性**:
- **连接管理**: 多服务器支持、自动切换、负载均衡
- **订阅服务**: 自动更新、批量导入、格式解析
- **系统集成**: PAC 配置、全局代理、规则代理
- **监控统计**: 实时流量、历史数据、性能分析
- **网络诊断**: 延迟测试、连通性检查、速度测试
- **智能路由**: 域名规则、IP 规则、GeoIP 支持
- **调试工具**: 结构化日志、错误追踪、性能监控
- **用户体验**: 个性化设置、主题切换、快捷操作

### 📁 文件详解 (Files)

```
files/
├── core-files.md             # 核心文件 - 应用入口和主要组件
├── model-files.md            # 模型文件 - 数据模型和实体
├── view-files.md             # 视图文件 - SwiftUI 视图组件
├── handler-files.md          # 处理器文件 - 业务逻辑处理器
├── protocol-files.md         # 协议文件 - 代理协议实现
└── utility-files.md          # 工具文件 - 辅助工具和扩展
```

**文件类型**:
- **核心文件**: `AppDelegate.swift`, `ContentView.swift`, `MainWindow.swift`
- **数据模型**: `ServerProfile.swift`, `Subscription.swift`, `TrafficStats.swift`
- **视图组件**: `ServerListView.swift`, `SettingsView.swift`, `StatusView.swift`
- **业务处理**: `V2rayHandler.swift`, `ProxyHandler.swift`, `ConfigHandler.swift`
- **协议实现**: `VMessProtocol.swift`, `TrojanProtocol.swift`, `ShadowsocksProtocol.swift`
- **工具扩展**: `String+Extensions.swift`, `Data+Extensions.swift`, `NetworkUtils.swift`

### 🔗 依赖分析 (Dependencies)

```
dependencies/
├── swift-packages.md         # Swift 包依赖 - SPM 包管理
├── third-party-libs.md       # 第三方库 - 外部库集成
└── system-frameworks.md      # 系统框架 - macOS 框架使用
```

**依赖类型**:
- **Swift 包**: GRDB.swift, Sparkle, SwiftyJSON
- **第三方库**: Alamofire, CryptoKit, Network.framework
- **系统框架**: SystemConfiguration, Security, ServiceManagement

## 🎯 学习路径推荐

### 按技能水平

#### 🌱 初学者 (0-1年经验)
```
1. beginner-path.md           # 基础学习路径
2. app-architecture.md        # 理解整体架构
3. view-layer.md              # 学习 SwiftUI 界面
4. core-files.md              # 分析核心文件
5. base-utilities.md          # 掌握基础工具
```

#### 🚀 中级开发者 (1-3年经验)
```
1. intermediate-path.md       # 中级学习路径
2. database-layer.md          # 深入数据库设计
3. handler-layer.md           # 理解业务逻辑
4. protocol-layer.md          # 学习协议实现
5. proxy-management.md        # 掌握核心功能
```

#### 🎖️ 高级开发者 (3+年经验)
```
1. advanced-path.md           # 高级学习路径
2. architecture-deep-dive.md  # 架构深度分析
3. system-proxy.md            # 系统集成技术
4. routing-rules.md           # 高级路由配置
5. swift-packages.md          # 依赖管理策略
```

### 按学习目标

#### 🏗️ 架构理解
```
1. architecture-deep-dive.md  # 架构深度解析
2. app-architecture.md        # 应用架构设计
3. database-layer.md          # 数据层架构
4. handler-layer.md           # 业务层架构
5. system-frameworks.md       # 系统集成架构
```

#### ⚡ 功能开发
```
1. proxy-management.md        # 代理管理功能
2. subscription-sync.md       # 订阅同步功能
3. traffic-stats.md           # 流量统计功能
4. ping-testing.md            # 延迟测试功能
5. settings-config.md         # 配置管理功能
```

#### 🔧 技术深入
```
1. protocol-layer.md          # 协议技术实现
2. system-proxy.md            # 系统代理技术
3. routing-rules.md           # 路由规则技术
4. log-management.md          # 日志管理技术
5. third-party-libs.md        # 第三方库技术
```

#### 🎨 界面开发
```
1. view-layer.md              # SwiftUI 视图层
2. view-files.md              # 视图文件详解
3. settings-config.md         # 设置界面开发
4. base-utilities.md          # UI 工具和扩展
5. core-files.md              # 界面核心文件
```

## 📊 文档统计

### 文档数量
- **学习路径**: 4 个文档
- **模块文档**: 6 个文档
- **功能文档**: 8 个文档
- **文件详解**: 6 个文档
- **依赖分析**: 3 个文档
- **总计**: 27 个专业文档 + 2 个索引文档

### 内容覆盖
- **代码示例**: 500+ 个 Swift 代码片段
- **架构图表**: 50+ 个系统架构图
- **功能说明**: 100+ 个功能特性描述
- **最佳实践**: 200+ 个开发建议
- **技术要点**: 300+ 个关键知识点

### 技术深度
- **入门级**: 30% (基础概念和简单示例)
- **中级**: 50% (实际应用和最佳实践)
- **高级**: 20% (架构设计和性能优化)

## 🔍 快速查找

### 按关键词查找

#### Swift 相关
- **SwiftUI**: `view-layer.md`, `view-files.md`
- **MVVM**: `app-architecture.md`, `architecture-deep-dive.md`
- **Async/Await**: `handler-layer.md`, `advanced-path.md`
- **Actor**: `protocol-layer.md`, `advanced-path.md`
- **Combine**: `intermediate-path.md`, `view-layer.md`

#### 数据库相关
- **GRDB**: `database-layer.md`, `model-files.md`
- **SQLite**: `database-layer.md`, `third-party-libs.md`
- **Migration**: `database-layer.md`, `core-files.md`
- **Repository**: `database-layer.md`, `handler-layer.md`

#### 网络相关
- **V2ray**: `protocol-layer.md`, `proxy-management.md`
- **VMess**: `protocol-layer.md`, `protocol-files.md`
- **Subscription**: `subscription-sync.md`, `handler-files.md`
- **Proxy**: `system-proxy.md`, `proxy-management.md`

#### 系统集成
- **macOS**: `system-frameworks.md`, `system-proxy.md`
- **SystemConfiguration**: `system-frameworks.md`, `base-utilities.md`
- **Security**: `system-frameworks.md`, `protocol-layer.md`
- **ServiceManagement**: `system-frameworks.md`, `advanced-path.md`

### 按难度查找

#### 🟢 简单 (适合初学者)
```
- beginner-path.md
- app-architecture.md
- view-layer.md
- core-files.md
- settings-config.md
```

#### 🟡 中等 (需要一定经验)
```
- intermediate-path.md
- database-layer.md
- handler-layer.md
- proxy-management.md
- subscription-sync.md
- traffic-stats.md
- model-files.md
- view-files.md
```

#### 🔴 困难 (需要深厚经验)
```
- advanced-path.md
- architecture-deep-dive.md
- protocol-layer.md
- system-proxy.md
- routing-rules.md
- log-management.md
- ping-testing.md
- protocol-files.md
- handler-files.md
- swift-packages.md
- third-party-libs.md
- system-frameworks.md
```

## 📈 学习进度追踪

### 基础阶段 ✅
- [ ] 完成初学者学习路径
- [ ] 理解应用整体架构
- [ ] 掌握 SwiftUI 基础
- [ ] 熟悉核心文件结构
- [ ] 学会使用基础工具

### 进阶阶段 ⏳
- [ ] 完成中级学习路径
- [ ] 深入数据库设计
- [ ] 理解业务逻辑处理
- [ ] 掌握代理管理功能
- [ ] 学会订阅同步机制

### 高级阶段 🎯
- [ ] 完成高级学习路径
- [ ] 精通架构设计原理
- [ ] 掌握协议层实现
- [ ] 理解系统集成技术
- [ ] 具备性能优化能力

### 专家阶段 🏆
- [ ] 能够设计新的架构模式
- [ ] 可以实现新的代理协议
- [ ] 具备系统级编程能力
- [ ] 能够优化性能瓶颈
- [ ] 可以指导团队开发

---

**使用建议**: 建议将此索引文件加入书签，作为学习过程中的快速参考。根据您的当前水平和学习目标，选择合适的文档开始您的 V2rayU 学习之旅！
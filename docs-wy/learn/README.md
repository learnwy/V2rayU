# V2rayU 学习文档体系

欢迎来到 V2rayU 的完整学习文档体系！这里包含了从入门到精通的全方位学习资源，帮助您深入理解和掌握 V2rayU 的架构设计、功能实现和开发技巧。

## 📚 文档结构概览

### 🎯 [学习路径 (Learning Paths)](./learning-paths/)

根据您的技能水平选择合适的学习路径：

- **[初学者路径](./learning-paths/beginner-path.md)** - 适合 Swift 和 macOS 开发新手
- **[中级开发者路径](./learning-paths/intermediate-path.md)** - 适合有一定经验的开发者
- **[高级开发者路径](./learning-paths/advanced-path.md)** - 适合资深开发者和技术领导
- **[架构深度解析](./learning-paths/architecture-deep-dive.md)** - 深入理解 V2rayU 架构设计

### 🏗️ [模块文档 (Modules)](./modules/)

深入了解 V2rayU 的各个核心模块：

- **[应用架构模块](./modules/app-architecture.md)** - 整体架构设计和 MVVM 模式
- **[数据库层模块](./modules/database-layer.md)** - GRDB 数据库设计和操作
- **[处理器层模块](./modules/handler-layer.md)** - 业务逻辑处理和服务管理
- **[协议层模块](./modules/protocol-layer.md)** - 各种代理协议的实现
- **[视图层模块](./modules/view-layer.md)** - SwiftUI 界面设计和交互
- **[基础工具模块](./modules/base-utilities.md)** - 通用工具类和扩展方法

### ⚡ [功能文档 (Features)](./features/)

详细了解 V2rayU 的各项核心功能：

- **[代理管理功能](./features/proxy-management.md)** - 服务器配置和连接管理
- **[订阅同步功能](./features/subscription-sync.md)** - 订阅源管理和自动更新
- **[系统代理功能](./features/system-proxy.md)** - 系统级代理设置和 PAC 配置
- **[流量统计功能](./features/traffic-stats.md)** - 网络流量监控和统计
- **[延迟测试功能](./features/ping-testing.md)** - 服务器延迟检测和优化
- **[路由规则功能](./features/routing-rules.md)** - 智能路由和规则配置
- **[日志管理功能](./features/log-management.md)** - 日志记录和分析系统
- **[设置配置功能](./features/settings-config.md)** - 应用设置和用户偏好

### 📁 [文件详解 (Files)](./files/)

深入分析 V2rayU 的关键源代码文件：

- **[核心文件详解](./files/core-files.md)** - 应用核心文件和入口点
- **[模型文件详解](./files/model-files.md)** - 数据模型和实体定义
- **[视图文件详解](./files/view-files.md)** - SwiftUI 视图组件实现
- **[处理器文件详解](./files/handler-files.md)** - 业务逻辑处理器实现
- **[协议文件详解](./files/protocol-files.md)** - 代理协议具体实现
- **[工具文件详解](./files/utility-files.md)** - 辅助工具和扩展实现

### 🔗 [依赖分析 (Dependencies)](./dependencies/)

了解 V2rayU 的技术栈和依赖关系：

- **[Swift 包依赖分析](./dependencies/swift-packages.md)** - 第三方 Swift 包使用分析
- **[第三方库分析](./dependencies/third-party-libs.md)** - 外部库集成和使用
- **[系统框架使用](./dependencies/system-frameworks.md)** - macOS 系统框架依赖

## 🚀 快速开始

### 新手入门

如果您是第一次接触 V2rayU 或 macOS 开发，建议按以下顺序学习：

1. 📖 阅读 [初学者学习路径](./learning-paths/beginner-path.md)
2. 🏗️ 了解 [应用架构模块](./modules/app-architecture.md)
3. 👀 查看 [核心文件详解](./files/core-files.md)
4. 🔧 学习 [基础工具模块](./modules/base-utilities.md)

### 有经验的开发者

如果您已经有 Swift 和 macOS 开发经验，可以直接从以下内容开始：

1. 🎯 选择 [中级](./learning-paths/intermediate-path.md) 或 [高级学习路径](./learning-paths/advanced-path.md)
2. 🏛️ 深入 [架构深度解析](./learning-paths/architecture-deep-dive.md)
3. ⚙️ 研究感兴趣的 [功能模块](./features/)
4. 📋 分析相关的 [源代码文件](./files/)

### 架构师和技术领导

如果您关注系统设计和架构决策，重点关注：

1. 🏗️ [架构深度解析](./learning-paths/architecture-deep-dive.md)
2. 🎯 [高级开发者路径](./learning-paths/advanced-path.md)
3. 🔗 [依赖分析](./dependencies/) 全部内容
4. 📐 各模块的设计模式和最佳实践

## 🎨 技术栈概览

### 核心技术

- **语言**: Swift 5.7+
- **UI 框架**: SwiftUI
- **架构模式**: MVVM + 分层架构
- **数据库**: SQLite (GRDB.swift)
- **网络**: URLSession + Network.framework
- **并发**: async/await + Actor

### 主要依赖

- **GRDB.swift**: SQLite 数据库操作
- **Sparkle**: 应用自动更新
- **Alamofire**: 网络请求 (部分功能)
- **SwiftyJSON**: JSON 数据处理
- **CryptoKit**: 加密和哈希计算

### 系统集成

- **SystemConfiguration**: 网络配置管理
- **Security**: 钥匙串和权限管理
- **ServiceManagement**: 系统服务管理
- **ApplicationServices**: 系统代理设置

## 📖 学习建议

### 理论与实践结合

1. **先理解架构**: 从整体架构开始，理解各模块的职责和关系
2. **深入关键模块**: 重点学习核心业务逻辑和数据流
3. **动手实践**: 尝试修改代码，添加新功能或优化现有功能
4. **测试验证**: 编写测试用例，验证理解的正确性

### 循序渐进

1. **基础概念**: 先掌握 Swift、SwiftUI 和 MVVM 基础
2. **模块理解**: 逐个学习各功能模块的实现
3. **系统集成**: 了解与 macOS 系统的集成方式
4. **性能优化**: 学习性能监控和优化技巧

### 实际应用

1. **问题导向**: 从实际问题出发，寻找解决方案
2. **代码阅读**: 仔细阅读和分析源代码实现
3. **文档参考**: 结合官方文档和最佳实践
4. **社区交流**: 参与开源社区讨论和贡献

## 🤝 贡献指南

我们欢迎您为 V2rayU 学习文档做出贡献：

### 文档改进

- 修正错误和不准确的信息
- 补充缺失的内容和示例
- 改进文档结构和可读性
- 添加更多实用的代码示例

### 内容扩展

- 添加新的学习主题和模块
- 创建更多实践教程和案例
- 补充性能优化和调试技巧
- 增加常见问题和解决方案

### 质量保证

- 审查和验证技术内容的准确性
- 测试代码示例的可执行性
- 检查文档的完整性和一致性
- 提供反馈和改进建议

## 📞 获取帮助

如果您在学习过程中遇到问题，可以通过以下方式获取帮助：

1. **查阅文档**: 首先查看相关的学习文档和 API 文档
2. **搜索问题**: 在 GitHub Issues 中搜索类似问题
3. **提交 Issue**: 如果找不到答案，请提交详细的问题描述
4. **社区讨论**: 参与社区讨论，与其他开发者交流

## 📄 许可证

本学习文档遵循与 V2rayU 项目相同的开源许可证。详细信息请参考项目根目录的 LICENSE 文件。

---

**开始您的 V2rayU 学习之旅吧！** 🎉

选择适合您的学习路径，深入探索这个优秀的 macOS 代理客户端的设计和实现。无论您是想要理解其架构设计，还是希望为项目做出贡献，这些文档都将为您提供全面的指导和支持。
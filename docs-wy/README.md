# V2rayU

一个基于 SwiftUI 开发的现代化 macOS V2ray 客户端应用。

## 项目简介

V2rayU 是一个功能强大的 macOS 代理客户端，支持多种代理协议，提供直观的用户界面和丰富的功能特性。应用采用现代化的 SwiftUI 框架开发，支持 macOS 系统的原生特性。

## 主要功能

### 🚀 代理协议支持
- **VMess**: V2ray 原生协议
- **VLESS**: 轻量级协议
- **Trojan**: 伪装流量协议
- **Shadowsocks**: 经典代理协议
- **多种传输方式**: TCP、WebSocket、HTTP/2、gRPC、QUIC 等

### 📡 订阅管理
- 支持订阅链接自动更新
- 批量导入服务器配置
- 支持 Clash YAML 格式解析
- 自动同步和更新服务器列表

### ⚡ 网络功能
- 系统代理自动配置
- PAC 模式和全局模式
- 智能路由规则
- 实时流量统计
- 服务器延迟测试

### 🎨 用户体验
- 现代化 SwiftUI 界面
- 支持浅色/深色主题
- 多语言支持（中文/英文）
- 菜单栏快速操作
- 拖拽排序支持

## 系统要求

- macOS 12.0 或更高版本
- 支持 Intel 和 Apple Silicon 处理器
- 需要管理员权限安装核心组件

## 安装说明

### 从源码构建

1. **克隆项目**
   ```bash
   git clone https://github.com/yanue/V2rayU.git
   cd V2rayU
   ```

2. **打开项目**
   ```bash
   open V2rayU.xcodeproj
   ```

3. **构建运行**
   - 在 Xcode 中选择目标设备
   - 按 `Cmd + R` 运行项目

### 首次运行

1. 应用会提示安装 V2rayUTool 组件
2. 输入管理员密码完成安装
3. 核心文件将安装到 `~/.V2rayU/` 目录

## 使用指南

### 添加服务器

1. **手动添加**
   - 点击菜单栏图标
   - 选择 "配置" → "添加服务器"
   - 填写服务器信息

2. **订阅导入**
   - 选择 "订阅" → "添加订阅"
   - 输入订阅链接
   - 点击同步更新

3. **链接导入**
   - 支持 vmess://, vless://, trojan://, ss:// 等协议链接
   - 直接粘贴链接自动识别

### 启动代理

1. 选择服务器节点
2. 点击 "启动" 按钮
3. 选择代理模式：
   - **PAC 模式**: 智能分流
   - **全局模式**: 全部流量代理
   - **手动模式**: 仅设置代理端口

### 路由规则

- 支持自定义路由规则
- 内置常用分流规则
- 支持域名、IP、地理位置匹配
- 可配置直连、代理、阻断策略

## 配置文件

### 目录结构
```
~/.V2rayU/
├── config.json          # V2ray 配置文件
├── .V2rayU.db           # 应用数据库
├── v2ray-core/          # V2ray 核心文件
│   ├── v2ray            # 主程序
│   ├── geoip.dat        # IP 地理位置数据
│   └── geosite.dat      # 域名分类数据
├── V2rayUTool           # 系统代理工具
├── v2ray-core.log       # V2ray 日志
└── V2rayU.log           # 应用日志
```

### 数据备份

重要配置文件：
- `~/.V2rayU/.V2rayU.db`: 服务器配置和应用设置
- 可通过应用内导出功能备份配置

## 故障排除

### 常见问题

1. **无法启动代理**
   - 检查服务器配置是否正确
   - 确认网络连接正常
   - 查看日志文件排查错误

2. **系统代理设置失败**
   - 确认已安装 V2rayUTool
   - 检查管理员权限
   - 重新安装核心组件

3. **订阅更新失败**
   - 检查订阅链接有效性
   - 确认网络连接
   - 尝试手动更新

### 日志查看

```bash
# V2ray 核心日志
tail -f ~/.V2rayU/v2ray-core.log

# 应用日志
tail -f ~/.V2rayU/V2rayU.log
```

## 开发相关

- 查看 [DEVELOPMENT.md](./DEVELOPMENT.md) 了解开发环境搭建
- 查看 [LEARNING_GUIDE.md](./LEARNING_GUIDE.md) 了解项目学习指南

## 技术栈

- **框架**: SwiftUI + Combine
- **数据库**: GRDB.swift
- **网络**: URLSession + Combine
- **架构**: MVVM
- **依赖管理**: Swift Package Manager

## 许可证

本项目采用开源许可证，具体请查看 LICENSE 文件。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进项目。

## 免责声明

本软件仅供学习和研究使用，请遵守当地法律法规。使用本软件所产生的任何后果由用户自行承担。
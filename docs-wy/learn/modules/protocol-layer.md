# 协议层模块详解

## 📋 概述

协议层模块是V2rayU的核心组件，负责处理各种代理协议的解析、配置生成和连接管理。本模块支持VMess、VLess、Shadowsocks、Trojan等主流代理协议，提供统一的接口和灵活的扩展机制。

## 🏗️ 架构设计

### 1. 协议抽象层

```swift
// MARK: - 代理协议基础接口
protocol ProxyProtocol {
    var type: ProxyType { get }
    var name: String { get }
    var version: String { get }
    
    func validateConfig(_ config: ProxyConfig) throws
    func generateConfig(_ config: ProxyConfig) throws -> [String: Any]
    func parseFromURL(_ url: String) throws -> ProxyConfig
    func generateShareURL(_ config: ProxyConfig) throws -> String
}

// MARK: - 代理类型枚举
enum ProxyType: String, CaseIterable, Codable {
    case vmess = "vmess"
    case vless = "vless"
    case shadowsocks = "ss"
    case trojan = "trojan"
    case http = "http"
    case socks5 = "socks5"
    
    var displayName: String {
        switch self {
        case .vmess: return "VMess"
        case .vless: return "VLess"
        case .shadowsocks: return "Shadowsocks"
        case .trojan: return "Trojan"
        case .http: return "HTTP"
        case .socks5: return "SOCKS5"
        }
    }
    
    var defaultPort: Int {
        switch self {
        case .vmess, .vless: return 443
        case .shadowsocks: return 8388
        case .trojan: return 443
        case .http: return 8080
        case .socks5: return 1080
        }
    }
    
    var supportsTLS: Bool {
        switch self {
        case .vmess, .vless, .trojan: return true
        case .shadowsocks, .http, .socks5: return false
        }
    }
}

// MARK: - 协议错误类型
enum ProtocolError: Error, LocalizedError {
    case unsupportedProtocol(String)
    case invalidURL(String)
    case invalidConfig(String)
    case missingRequiredField(String)
    case invalidFieldValue(String, String)
    case parseError(String)
    case generateError(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedProtocol(let type):
            return "不支持的协议类型: \(type)"
        case .invalidURL(let url):
            return "无效的URL: \(url)"
        case .invalidConfig(let message):
            return "无效的配置: \(message)"
        case .missingRequiredField(let field):
            return "缺少必需字段: \(field)"
        case .invalidFieldValue(let field, let value):
            return "字段值无效: \(field) = \(value)"
        case .parseError(let message):
            return "解析错误: \(message)"
        case .generateError(let message):
            return "生成错误: \(message)"
        }
    }
}
```

## 🔧 协议实现

### 1. VMess协议实现

```swift
// MARK: - VMess协议实现
struct VMessProtocol: ProxyProtocol {
    let type: ProxyType = .vmess
    let name = "VMess"
    let version = "1.0"
    
    // MARK: - 配置验证
    func validateConfig(_ config: ProxyConfig) throws {
        // 验证服务器地址
        guard !config.serverAddress.isEmpty else {
            throw ProtocolError.missingRequiredField("serverAddress")
        }
        
        // 验证端口
        guard config.serverPort > 0 && config.serverPort <= 65535 else {
            throw ProtocolError.invalidFieldValue("serverPort", "\(config.serverPort)")
        }
        
        // 验证用户ID
        guard let userId = config.userId, !userId.isEmpty else {
            throw ProtocolError.missingRequiredField("userId")
        }
        
        // 验证UUID格式
        guard UUID(uuidString: userId) != nil else {
            throw ProtocolError.invalidFieldValue("userId", userId)
        }
        
        // 验证加密方法
        if let security = config.security {
            let validSecurities = ["auto", "aes-128-gcm", "chacha20-poly1305", "none"]
            guard validSecurities.contains(security) else {
                throw ProtocolError.invalidFieldValue("security", security)
            }
        }
        
        // 验证传输协议
        if let network = config.network {
            let validNetworks = ["tcp", "kcp", "ws", "http", "quic", "grpc"]
            guard validNetworks.contains(network) else {
                throw ProtocolError.invalidFieldValue("network", network)
            }
        }
    }
    
    // MARK: - 配置生成
    func generateConfig(_ config: ProxyConfig) throws -> [String: Any] {
        try validateConfig(config)
        
        var vmessConfig: [String: Any] = [
            "v": "2",
            "ps": config.name,
            "add": config.serverAddress,
            "port": config.serverPort,
            "id": config.userId ?? "",
            "aid": config.alterId ?? 0,
            "scy": config.security ?? "auto",
            "net": config.network ?? "tcp",
            "type": config.headerType ?? "none",
            "host": config.host ?? "",
            "path": config.path ?? "",
            "tls": config.tls ?? "none",
            "sni": config.serverName ?? "",
            "alpn": config.alpn ?? ""
        ]
        
        // WebSocket特定配置
        if config.network == "ws" {
            vmessConfig["ws-opts"] = [
                "path": config.path ?? "/",
                "headers": [
                    "Host": config.host ?? config.serverAddress
                ]
            ]
        }
        
        // HTTP/2特定配置
        if config.network == "http" {
            vmessConfig["http-opts"] = [
                "method": "GET",
                "path": [config.path ?? "/"],
                "headers": [
                    "Host": [config.host ?? config.serverAddress]
                ]
            ]
        }
        
        // gRPC特定配置
        if config.network == "grpc" {
            vmessConfig["grpc-opts"] = [
                "grpc-service-name": config.serviceName ?? ""
            ]
        }
        
        // TLS配置
        if config.tls == "tls" {
            vmessConfig["tls-opts"] = [
                "server-name": config.serverName ?? config.serverAddress,
                "skip-cert-verify": config.allowInsecure ?? false
            ]
            
            if let alpn = config.alpn, !alpn.isEmpty {
                vmessConfig["alpn"] = alpn.components(separatedBy: ",")
            }
        }
        
        return vmessConfig
    }
    
    // MARK: - URL解析
    func parseFromURL(_ url: String) throws -> ProxyConfig {
        guard url.hasPrefix("vmess://") else {
            throw ProtocolError.invalidURL("不是有效的VMess URL")
        }
        
        let base64String = String(url.dropFirst(8)) // 移除 "vmess://"
        
        guard let data = Data(base64Encoded: base64String),
              let jsonString = String(data: data, encoding: .utf8),
              let jsonData = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ProtocolError.parseError("无法解析VMess配置")
        }
        
        var config = ProxyConfig()
        config.protocolType = .vmess
        config.name = json["ps"] as? String ?? "VMess"
        config.serverAddress = json["add"] as? String ?? ""
        config.serverPort = json["port"] as? Int ?? 443
        config.userId = json["id"] as? String
        config.alterId = json["aid"] as? Int
        config.security = json["scy"] as? String
        config.network = json["net"] as? String
        config.headerType = json["type"] as? String
        config.host = json["host"] as? String
        config.path = json["path"] as? String
        config.tls = json["tls"] as? String
        config.serverName = json["sni"] as? String
        config.alpn = json["alpn"] as? String
        
        try validateConfig(config)
        return config
    }
    
    // MARK: - 分享URL生成
    func generateShareURL(_ config: ProxyConfig) throws -> String {
        let vmessConfig = try generateConfig(config)
        
        let jsonData = try JSONSerialization.data(withJSONObject: vmessConfig)
        let base64String = jsonData.base64EncodedString()
        
        return "vmess://\(base64String)"
    }
}
```

### 2. VLess协议实现

```swift
// MARK: - VLess协议实现
struct VLessProtocol: ProxyProtocol {
    let type: ProxyType = .vless
    let name = "VLess"
    let version = "1.0"
    
    // MARK: - 配置验证
    func validateConfig(_ config: ProxyConfig) throws {
        // 验证服务器地址
        guard !config.serverAddress.isEmpty else {
            throw ProtocolError.missingRequiredField("serverAddress")
        }
        
        // 验证端口
        guard config.serverPort > 0 && config.serverPort <= 65535 else {
            throw ProtocolError.invalidFieldValue("serverPort", "\(config.serverPort)")
        }
        
        // 验证用户ID
        guard let userId = config.userId, !userId.isEmpty else {
            throw ProtocolError.missingRequiredField("userId")
        }
        
        // 验证UUID格式
        guard UUID(uuidString: userId) != nil else {
            throw ProtocolError.invalidFieldValue("userId", userId)
        }
        
        // 验证加密方法（VLess只支持none）
        if let encryption = config.encryption {
            guard encryption == "none" else {
                throw ProtocolError.invalidFieldValue("encryption", encryption)
            }
        }
        
        // 验证流控
        if let flow = config.flow {
            let validFlows = ["", "xtls-rprx-origin", "xtls-rprx-direct", "xtls-rprx-splice"]
            guard validFlows.contains(flow) else {
                throw ProtocolError.invalidFieldValue("flow", flow)
            }
        }
    }
    
    // MARK: - 配置生成
    func generateConfig(_ config: ProxyConfig) throws -> [String: Any] {
        try validateConfig(config)
        
        var vlessConfig: [String: Any] = [
            "name": config.name,
            "type": "vless",
            "server": config.serverAddress,
            "port": config.serverPort,
            "uuid": config.userId ?? "",
            "encryption": config.encryption ?? "none",
            "flow": config.flow ?? "",
            "network": config.network ?? "tcp",
            "udp": true
        ]
        
        // WebSocket配置
        if config.network == "ws" {
            vlessConfig["ws-opts"] = [
                "path": config.path ?? "/",
                "headers": [
                    "Host": config.host ?? config.serverAddress
                ]
            ]
        }
        
        // gRPC配置
        if config.network == "grpc" {
            vlessConfig["grpc-opts"] = [
                "grpc-service-name": config.serviceName ?? ""
            ]
        }
        
        // TLS/XTLS配置
        if config.tls == "tls" || config.tls == "xtls" {
            vlessConfig["tls"] = true
            vlessConfig["servername"] = config.serverName ?? config.serverAddress
            vlessConfig["skip-cert-verify"] = config.allowInsecure ?? false
            
            if let alpn = config.alpn, !alpn.isEmpty {
                vlessConfig["alpn"] = alpn.components(separatedBy: ",")
            }
        }
        
        return vlessConfig
    }
    
    // MARK: - URL解析
    func parseFromURL(_ url: String) throws -> ProxyConfig {
        guard url.hasPrefix("vless://") else {
            throw ProtocolError.invalidURL("不是有效的VLess URL")
        }
        
        guard let urlComponents = URLComponents(string: url) else {
            throw ProtocolError.parseError("无法解析VLess URL")
        }
        
        var config = ProxyConfig()
        config.protocolType = .vless
        config.userId = urlComponents.user
        config.serverAddress = urlComponents.host ?? ""
        config.serverPort = urlComponents.port ?? 443
        config.name = urlComponents.fragment ?? "VLess"
        
        // 解析查询参数
        if let queryItems = urlComponents.queryItems {
            for item in queryItems {
                switch item.name {
                case "encryption":
                    config.encryption = item.value
                case "flow":
                    config.flow = item.value
                case "security":
                    config.tls = item.value
                case "sni":
                    config.serverName = item.value
                case "alpn":
                    config.alpn = item.value
                case "type":
                    config.network = item.value
                case "host":
                    config.host = item.value
                case "path":
                    config.path = item.value
                case "serviceName":
                    config.serviceName = item.value
                default:
                    break
                }
            }
        }
        
        try validateConfig(config)
        return config
    }
    
    // MARK: - 分享URL生成
    func generateShareURL(_ config: ProxyConfig) throws -> String {
        try validateConfig(config)
        
        var components = URLComponents()
        components.scheme = "vless"
        components.user = config.userId
        components.host = config.serverAddress
        components.port = config.serverPort
        components.fragment = config.name
        
        var queryItems: [URLQueryItem] = []
        
        if let encryption = config.encryption {
            queryItems.append(URLQueryItem(name: "encryption", value: encryption))
        }
        
        if let flow = config.flow, !flow.isEmpty {
            queryItems.append(URLQueryItem(name: "flow", value: flow))
        }
        
        if let tls = config.tls {
            queryItems.append(URLQueryItem(name: "security", value: tls))
        }
        
        if let serverName = config.serverName {
            queryItems.append(URLQueryItem(name: "sni", value: serverName))
        }
        
        if let alpn = config.alpn {
            queryItems.append(URLQueryItem(name: "alpn", value: alpn))
        }
        
        if let network = config.network {
            queryItems.append(URLQueryItem(name: "type", value: network))
        }
        
        if let host = config.host {
            queryItems.append(URLQueryItem(name: "host", value: host))
        }
        
        if let path = config.path {
            queryItems.append(URLQueryItem(name: "path", value: path))
        }
        
        if let serviceName = config.serviceName {
            queryItems.append(URLQueryItem(name: "serviceName", value: serviceName))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url?.absoluteString else {
            throw ProtocolError.generateError("无法生成VLess URL")
        }
        
        return url
    }
}
```

### 3. Shadowsocks协议实现

```swift
// MARK: - Shadowsocks协议实现
struct ShadowsocksProtocol: ProxyProtocol {
    let type: ProxyType = .shadowsocks
    let name = "Shadowsocks"
    let version = "1.0"
    
    // MARK: - 支持的加密方法
    static let supportedMethods = [
        "aes-128-gcm", "aes-192-gcm", "aes-256-gcm",
        "aes-128-cfb", "aes-192-cfb", "aes-256-cfb",
        "aes-128-ctr", "aes-192-ctr", "aes-256-ctr",
        "chacha20-ietf", "chacha20-ietf-poly1305",
        "xchacha20-ietf-poly1305",
        "rc4-md5", "bf-cfb", "cast5-cfb", "des-cfb",
        "rc2-cfb", "seed-cfb", "salsa20", "chacha20",
        "table"
    ]
    
    // MARK: - 配置验证
    func validateConfig(_ config: ProxyConfig) throws {
        // 验证服务器地址
        guard !config.serverAddress.isEmpty else {
            throw ProtocolError.missingRequiredField("serverAddress")
        }
        
        // 验证端口
        guard config.serverPort > 0 && config.serverPort <= 65535 else {
            throw ProtocolError.invalidFieldValue("serverPort", "\(config.serverPort)")
        }
        
        // 验证密码
        guard let password = config.password, !password.isEmpty else {
            throw ProtocolError.missingRequiredField("password")
        }
        
        // 验证加密方法
        guard let method = config.method, !method.isEmpty else {
            throw ProtocolError.missingRequiredField("method")
        }
        
        guard Self.supportedMethods.contains(method) else {
            throw ProtocolError.invalidFieldValue("method", method)
        }
    }
    
    // MARK: - 配置生成
    func generateConfig(_ config: ProxyConfig) throws -> [String: Any] {
        try validateConfig(config)
        
        var ssConfig: [String: Any] = [
            "name": config.name,
            "type": "ss",
            "server": config.serverAddress,
            "port": config.serverPort,
            "cipher": config.method ?? "",
            "password": config.password ?? "",
            "udp": true
        ]
        
        // 插件配置
        if let plugin = config.plugin {
            ssConfig["plugin"] = plugin
            
            if let pluginOpts = config.pluginOpts {
                ssConfig["plugin-opts"] = pluginOpts
            }
        }
        
        return ssConfig
    }
    
    // MARK: - URL解析
    func parseFromURL(_ url: String) throws -> ProxyConfig {
        guard url.hasPrefix("ss://") else {
            throw ProtocolError.invalidURL("不是有效的Shadowsocks URL")
        }
        
        let urlString = String(url.dropFirst(5)) // 移除 "ss://"
        
        // 处理两种格式：
        // 1. ss://base64(method:password)@server:port#name
        // 2. ss://base64(method:password@server:port)#name
        
        var config = ProxyConfig()
        config.protocolType = .shadowsocks
        
        if let atIndex = urlString.firstIndex(of: "@") {
            // 格式1: ss://base64(method:password)@server:port#name
            let encodedPart = String(urlString[..<atIndex])
            let serverPart = String(urlString[urlString.index(after: atIndex)...])
            
            // 解码认证信息
            guard let authData = Data(base64Encoded: encodedPart),
                  let authString = String(data: authData, encoding: .utf8) else {
                throw ProtocolError.parseError("无法解码认证信息")
            }
            
            let authComponents = authString.components(separatedBy: ":")
            guard authComponents.count == 2 else {
                throw ProtocolError.parseError("认证信息格式错误")
            }
            
            config.method = authComponents[0]
            config.password = authComponents[1]
            
            // 解析服务器信息
            let serverComponents = serverPart.components(separatedBy: "#")
            let serverInfo = serverComponents[0]
            
            if serverComponents.count > 1 {
                config.name = serverComponents[1].removingPercentEncoding ?? "Shadowsocks"
            } else {
                config.name = "Shadowsocks"
            }
            
            let hostPort = serverInfo.components(separatedBy: ":")
            guard hostPort.count == 2,
                  let port = Int(hostPort[1]) else {
                throw ProtocolError.parseError("服务器信息格式错误")
            }
            
            config.serverAddress = hostPort[0]
            config.serverPort = port
            
        } else {
            // 格式2: ss://base64(method:password@server:port)#name
            let components = urlString.components(separatedBy: "#")
            let encodedPart = components[0]
            
            if components.count > 1 {
                config.name = components[1].removingPercentEncoding ?? "Shadowsocks"
            } else {
                config.name = "Shadowsocks"
            }
            
            guard let data = Data(base64Encoded: encodedPart),
                  let decodedString = String(data: data, encoding: .utf8) else {
                throw ProtocolError.parseError("无法解码配置信息")
            }
            
            guard let atIndex = decodedString.firstIndex(of: "@") else {
                throw ProtocolError.parseError("配置格式错误")
            }
            
            let authPart = String(decodedString[..<atIndex])
            let serverPart = String(decodedString[decodedString.index(after: atIndex)...])
            
            let authComponents = authPart.components(separatedBy: ":")
            guard authComponents.count == 2 else {
                throw ProtocolError.parseError("认证信息格式错误")
            }
            
            config.method = authComponents[0]
            config.password = authComponents[1]
            
            let hostPort = serverPart.components(separatedBy: ":")
            guard hostPort.count == 2,
                  let port = Int(hostPort[1]) else {
                throw ProtocolError.parseError("服务器信息格式错误")
            }
            
            config.serverAddress = hostPort[0]
            config.serverPort = port
        }
        
        try validateConfig(config)
        return config
    }
    
    // MARK: - 分享URL生成
    func generateShareURL(_ config: ProxyConfig) throws -> String {
        try validateConfig(config)
        
        let authString = "\(config.method ?? ""):\(config.password ?? "")"
        let authData = authString.data(using: .utf8)!
        let encodedAuth = authData.base64EncodedString()
        
        let name = config.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? config.name
        
        return "ss://\(encodedAuth)@\(config.serverAddress):\(config.serverPort)#\(name)"
    }
}
```

### 4. Trojan协议实现

```swift
// MARK: - Trojan协议实现
struct TrojanProtocol: ProxyProtocol {
    let type: ProxyType = .trojan
    let name = "Trojan"
    let version = "1.0"
    
    // MARK: - 配置验证
    func validateConfig(_ config: ProxyConfig) throws {
        // 验证服务器地址
        guard !config.serverAddress.isEmpty else {
            throw ProtocolError.missingRequiredField("serverAddress")
        }
        
        // 验证端口
        guard config.serverPort > 0 && config.serverPort <= 65535 else {
            throw ProtocolError.invalidFieldValue("serverPort", "\(config.serverPort)")
        }
        
        // 验证密码
        guard let password = config.password, !password.isEmpty else {
            throw ProtocolError.missingRequiredField("password")
        }
        
        // Trojan通常使用TLS
        if config.tls != "tls" && config.tls != nil {
            throw ProtocolError.invalidFieldValue("tls", config.tls ?? "")
        }
    }
    
    // MARK: - 配置生成
    func generateConfig(_ config: ProxyConfig) throws -> [String: Any] {
        try validateConfig(config)
        
        var trojanConfig: [String: Any] = [
            "name": config.name,
            "type": "trojan",
            "server": config.serverAddress,
            "port": config.serverPort,
            "password": config.password ?? "",
            "udp": true,
            "sni": config.serverName ?? config.serverAddress,
            "skip-cert-verify": config.allowInsecure ?? false
        ]
        
        // ALPN配置
        if let alpn = config.alpn, !alpn.isEmpty {
            trojanConfig["alpn"] = alpn.components(separatedBy: ",")
        }
        
        // WebSocket配置（Trojan-Go支持）
        if config.network == "ws" {
            trojanConfig["network"] = "ws"
            trojanConfig["ws-opts"] = [
                "path": config.path ?? "/",
                "headers": [
                    "Host": config.host ?? config.serverAddress
                ]
            ]
        }
        
        return trojanConfig
    }
    
    // MARK: - URL解析
    func parseFromURL(_ url: String) throws -> ProxyConfig {
        guard url.hasPrefix("trojan://") else {
            throw ProtocolError.invalidURL("不是有效的Trojan URL")
        }
        
        guard let urlComponents = URLComponents(string: url) else {
            throw ProtocolError.parseError("无法解析Trojan URL")
        }
        
        var config = ProxyConfig()
        config.protocolType = .trojan
        config.password = urlComponents.user
        config.serverAddress = urlComponents.host ?? ""
        config.serverPort = urlComponents.port ?? 443
        config.name = urlComponents.fragment ?? "Trojan"
        config.tls = "tls" // Trojan默认使用TLS
        config.serverName = config.serverAddress // 默认SNI
        
        // 解析查询参数
        if let queryItems = urlComponents.queryItems {
            for item in queryItems {
                switch item.name {
                case "sni":
                    config.serverName = item.value
                case "alpn":
                    config.alpn = item.value
                case "allowInsecure":
                    config.allowInsecure = item.value == "1" || item.value?.lowercased() == "true"
                case "type":
                    config.network = item.value
                case "host":
                    config.host = item.value
                case "path":
                    config.path = item.value
                default:
                    break
                }
            }
        }
        
        try validateConfig(config)
        return config
    }
    
    // MARK: - 分享URL生成
    func generateShareURL(_ config: ProxyConfig) throws -> String {
        try validateConfig(config)
        
        var components = URLComponents()
        components.scheme = "trojan"
        components.user = config.password
        components.host = config.serverAddress
        components.port = config.serverPort
        components.fragment = config.name
        
        var queryItems: [URLQueryItem] = []
        
        if let serverName = config.serverName, serverName != config.serverAddress {
            queryItems.append(URLQueryItem(name: "sni", value: serverName))
        }
        
        if let alpn = config.alpn {
            queryItems.append(URLQueryItem(name: "alpn", value: alpn))
        }
        
        if config.allowInsecure == true {
            queryItems.append(URLQueryItem(name: "allowInsecure", value: "1"))
        }
        
        if let network = config.network, network != "tcp" {
            queryItems.append(URLQueryItem(name: "type", value: network))
        }
        
        if let host = config.host {
            queryItems.append(URLQueryItem(name: "host", value: host))
        }
        
        if let path = config.path {
            queryItems.append(URLQueryItem(name: "path", value: path))
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let url = components.url?.absoluteString else {
            throw ProtocolError.generateError("无法生成Trojan URL")
        }
        
        return url
    }
}
```

## 🏭 协议工厂

### 1. 协议管理器

```swift
// MARK: - 协议管理器
class ProtocolManager {
    
    // MARK: - 单例
    static let shared = ProtocolManager()
    
    // MARK: - 协议注册表
    private var protocols: [ProxyType: ProxyProtocol] = [:]
    
    private init() {
        registerDefaultProtocols()
    }
    
    // MARK: - 注册默认协议
    private func registerDefaultProtocols() {
        register(VMessProtocol())
        register(VLessProtocol())
        register(ShadowsocksProtocol())
        register(TrojanProtocol())
    }
    
    // MARK: - 协议注册
    func register(_ protocol: ProxyProtocol) {
        protocols[`protocol`.type] = `protocol`
    }
    
    // MARK: - 获取协议实现
    func getProtocol(for type: ProxyType) -> ProxyProtocol? {
        return protocols[type]
    }
    
    // MARK: - 获取所有支持的协议
    func getSupportedProtocols() -> [ProxyType] {
        return Array(protocols.keys).sorted { $0.rawValue < $1.rawValue }
    }
    
    // MARK: - 验证配置
    func validateConfig(_ config: ProxyConfig) throws {
        guard let protocol = getProtocol(for: config.protocolType) else {
            throw ProtocolError.unsupportedProtocol(config.protocolType.rawValue)
        }
        
        try `protocol`.validateConfig(config)
    }
    
    // MARK: - 生成配置
    func generateConfig(_ config: ProxyConfig) throws -> [String: Any] {
        guard let protocol = getProtocol(for: config.protocolType) else {
            throw ProtocolError.unsupportedProtocol(config.protocolType.rawValue)
        }
        
        return try `protocol`.generateConfig(config)
    }
    
    // MARK: - 解析URL
    func parseFromURL(_ url: String) throws -> ProxyConfig {
        // 根据URL前缀确定协议类型
        let protocolType: ProxyType
        
        if url.hasPrefix("vmess://") {
            protocolType = .vmess
        } else if url.hasPrefix("vless://") {
            protocolType = .vless
        } else if url.hasPrefix("ss://") {
            protocolType = .shadowsocks
        } else if url.hasPrefix("trojan://") {
            protocolType = .trojan
        } else {
            throw ProtocolError.unsupportedProtocol("未知协议")
        }
        
        guard let protocol = getProtocol(for: protocolType) else {
            throw ProtocolError.unsupportedProtocol(protocolType.rawValue)
        }
        
        return try `protocol`.parseFromURL(url)
    }
    
    // MARK: - 生成分享URL
    func generateShareURL(_ config: ProxyConfig) throws -> String {
        guard let protocol = getProtocol(for: config.protocolType) else {
            throw ProtocolError.unsupportedProtocol(config.protocolType.rawValue)
        }
        
        return try `protocol`.generateShareURL(config)
    }
    
    // MARK: - 批量解析
    func parseMultipleURLs(_ urls: [String]) -> [Result<ProxyConfig, Error>] {
        return urls.map { url in
            Result {
                try parseFromURL(url)
            }
        }
    }
    
    // MARK: - 批量生成分享URL
    func generateMultipleShareURLs(_ configs: [ProxyConfig]) -> [Result<String, Error>] {
        return configs.map { config in
            Result {
                try generateShareURL(config)
            }
        }
    }
}
```

### 2. 配置解析器

```swift
// MARK: - 配置解析器
class ConfigParser {
    
    private let protocolManager = ProtocolManager.shared
    
    // MARK: - 解析订阅内容
    func parseSubscriptionContent(_ content: String) throws -> [ProxyConfig] {
        var configs: [ProxyConfig] = []
        
        // 按行分割内容
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 跳过空行和注释
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            // 尝试解析每一行
            do {
                let config = try protocolManager.parseFromURL(trimmedLine)
                configs.append(config)
            } catch {
                // 记录解析失败的行，但继续处理其他行
                print("解析失败: \(trimmedLine), 错误: \(error)")
            }
        }
        
        return configs
    }
    
    // MARK: - 导出配置
    func exportProxies(_ configs: [ProxyConfig]) throws -> String {
        var urls: [String] = []
        
        for config in configs {
            do {
                let url = try protocolManager.generateShareURL(config)
                urls.append(url)
            } catch {
                print("生成URL失败: \(config.name), 错误: \(error)")
            }
        }
        
        return urls.joined(separator: "\n")
    }
    
    // MARK: - 解析Clash配置
    func parseClashConfig(_ yamlContent: String) throws -> [ProxyConfig] {
        // 这里可以实现Clash YAML格式的解析
        // 由于Swift没有内置YAML解析器，这里只是示例
        throw ProtocolError.parseError("Clash配置解析暂未实现")
    }
    
    // MARK: - 生成Clash配置
    func generateClashConfig(_ configs: [ProxyConfig]) throws -> String {
        var clashConfig = """
        port: 7890
        socks-port: 7891
        allow-lan: false
        mode: Rule
        log-level: info
        external-controller: 127.0.0.1:9090
        
        proxies:
        """
        
        for config in configs {
            do {
                let proxyConfig = try protocolManager.generateConfig(config)
                let yamlProxy = try convertToClashYAML(proxyConfig)
                clashConfig += "\n  - \(yamlProxy)"
            } catch {
                print("生成Clash配置失败: \(config.name), 错误: \(error)")
            }
        }
        
        clashConfig += """
        
        
        proxy-groups:
          - name: "Proxy"
            type: select
            proxies:
        """
        
        for config in configs {
            clashConfig += "\n              - \"\(config.name)\""
        }
        
        clashConfig += """
        
        
        rules:
          - DOMAIN-SUFFIX,google.com,Proxy
          - DOMAIN-KEYWORD,google,Proxy
          - DOMAIN,google.com,Proxy
          - DOMAIN-SUFFIX,ad.com,REJECT
          - GEOIP,CN,DIRECT
          - MATCH,Proxy
        """
        
        return clashConfig
    }
    
    // MARK: - 转换为Clash YAML格式
    private func convertToClashYAML(_ config: [String: Any]) throws -> String {
        // 简化的YAML生成，实际应该使用专门的YAML库
        var yaml = ""
        
        for (key, value) in config {
            if let stringValue = value as? String {
                yaml += "\(key): \"\(stringValue)\", "
            } else if let intValue = value as? Int {
                yaml += "\(key): \(intValue), "
            } else if let boolValue = value as? Bool {
                yaml += "\(key): \(boolValue), "
            }
        }
        
        // 移除最后的逗号和空格
        if yaml.hasSuffix(", ") {
            yaml = String(yaml.dropLast(2))
        }
        
        return "{ \(yaml) }"
    }
}
```

## 🧪 测试支持

### 1. 协议测试基类

```swift
// MARK: - 协议测试基类
class ProtocolTestCase: XCTestCase {
    
    var protocolManager: ProtocolManager!
    
    override func setUp() {
        super.setUp()
        protocolManager = ProtocolManager.shared
    }
    
    override func tearDown() {
        protocolManager = nil
        super.tearDown()
    }
}

// MARK: - VMess协议测试
class VMessProtocolTests: ProtocolTestCase {
    
    func testVMessURLParsing() throws {
        let vmessURL = "vmess://eyJ2IjoiMiIsInBzIjoidGVzdCIsImFkZCI6IjEyNy4wLjAuMSIsInBvcnQiOjQ0MywiaWQiOiIxMjM0NTY3OC0xMjM0LTEyMzQtMTIzNC0xMjM0NTY3ODkwYWIiLCJhaWQiOjAsInNjeSI6ImF1dG8iLCJuZXQiOiJ0Y3AiLCJ0eXBlIjoibm9uZSIsImhvc3QiOiIiLCJwYXRoIjoiIiwidGxzIjoidGxzIiwic25pIjoiIn0="
        
        let config = try protocolManager.parseFromURL(vmessURL)
        
        XCTAssertEqual(config.protocolType, .vmess)
        XCTAssertEqual(config.name, "test")
        XCTAssertEqual(config.serverAddress, "127.0.0.1")
        XCTAssertEqual(config.serverPort, 443)
        XCTAssertEqual(config.userId, "12345678-1234-1234-1234-123456789ab")
    }
    
    func testVMessConfigGeneration() throws {
        var config = ProxyConfig()
        config.protocolType = .vmess
        config.name = "test"
        config.serverAddress = "127.0.0.1"
        config.serverPort = 443
        config.userId = "12345678-1234-1234-1234-123456789ab"
        config.alterId = 0
        config.security = "auto"
        config.network = "tcp"
        config.tls = "tls"
        
        let generatedConfig = try protocolManager.generateConfig(config)
        
        XCTAssertEqual(generatedConfig["ps"] as? String, "test")
        XCTAssertEqual(generatedConfig["add"] as? String, "127.0.0.1")
        XCTAssertEqual(generatedConfig["port"] as? Int, 443)
        XCTAssertEqual(generatedConfig["id"] as? String, "12345678-1234-1234-1234-123456789ab")
    }
}
```

## 📚 相关文档

- [应用架构模块](app-architecture.md)
- [数据库层模块](database-layer.md)
- [处理器层模块](handler-layer.md)
- [视图层模块](view-layer.md)
- [基础工具模块](base-utilities.md)

---

*本文档详细介绍了V2rayU协议层的设计与实现，为开发者提供了完整的代理协议处理解决方案。*
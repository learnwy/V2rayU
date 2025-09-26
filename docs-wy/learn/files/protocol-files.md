# 协议文件详解

## 📋 概述

本文档详细解析V2rayU应用的协议文件，包括V2ray协议支持、网络协议处理、加密传输、协议转换等核心网络通信功能的实现。

---

## 🏗️ 文件结构

```
V2rayU/Protocols/
├── V2ray/
│   ├── V2rayProtocol.swift           # V2ray协议基础
│   ├── VMESSProtocol.swift           # VMESS协议实现
│   ├── VLESSProtocol.swift           # VLESS协议实现
│   ├── TrojanProtocol.swift          # Trojan协议实现
│   ├── ShadowsocksProtocol.swift     # Shadowsocks协议实现
│   └── SocksProtocol.swift           # SOCKS协议实现
├── Transport/
│   ├── TransportProtocol.swift       # 传输协议基础
│   ├── TCPTransport.swift            # TCP传输
│   ├── UDPTransport.swift            # UDP传输
│   ├── WebSocketTransport.swift      # WebSocket传输
│   ├── HTTP2Transport.swift          # HTTP/2传输
│   ├── QUICTransport.swift           # QUIC传输
│   └── GRPCTransport.swift           # gRPC传输
├── Security/
│   ├── SecurityProtocol.swift        # 安全协议基础
│   ├── TLSSecurity.swift             # TLS安全层
│   ├── XTLSSecurity.swift            # XTLS安全层
│   ├── RealitySecurity.swift         # Reality安全层
│   └── CertificateManager.swift      # 证书管理
├── Routing/
│   ├── RoutingProtocol.swift         # 路由协议基础
│   ├── DomainMatcher.swift           # 域名匹配器
│   ├── IPMatcher.swift               # IP匹配器
│   ├── GeoIPMatcher.swift            # GeoIP匹配器
│   └── RoutingRule.swift             # 路由规则
├── DNS/
│   ├── DNSProtocol.swift             # DNS协议基础
│   ├── DoHResolver.swift             # DNS over HTTPS
│   ├── DoTResolver.swift             # DNS over TLS
│   ├── DoQResolver.swift             # DNS over QUIC
│   └── DNSCache.swift                # DNS缓存
└── Utilities/
    ├── ProtocolParser.swift          # 协议解析器
    ├── ConfigGenerator.swift         # 配置生成器
    ├── ProtocolValidator.swift       # 协议验证器
    └── NetworkUtils.swift            # 网络工具
```

---

## 🔌 V2ray协议

### V2rayProtocol.swift

**作用**：定义V2ray协议的基础接口和通用功能。

```swift
import Foundation

// MARK: - Protocol Definition
protocol V2rayProtocol {
    var protocolName: String { get }
    var version: String { get }
    var supportedTransports: [TransportType] { get }
    var supportedSecurity: [SecurityType] { get }
    
    func generateConfig(from configuration: ProxyConfiguration) throws -> [String: Any]
    func validate(configuration: ProxyConfiguration) throws
    func parseURL(_ url: String) throws -> ProxyConfiguration
    func generateURL(from configuration: ProxyConfiguration) throws -> String
}

// MARK: - Base Implementation
class BaseV2rayProtocol: V2rayProtocol {
    let protocolName: String
    let version: String
    let supportedTransports: [TransportType]
    let supportedSecurity: [SecurityType]
    
    init(name: String, version: String, transports: [TransportType], security: [SecurityType]) {
        self.protocolName = name
        self.version = version
        self.supportedTransports = transports
        self.supportedSecurity = security
    }
    
    func generateConfig(from configuration: ProxyConfiguration) throws -> [String: Any] {
        fatalError("Subclasses must implement generateConfig")
    }
    
    func validate(configuration: ProxyConfiguration) throws {
        // 基础验证
        guard !configuration.serverAddress.isEmpty else {
            throw ProtocolError.invalidServerAddress
        }
        
        guard configuration.serverPort > 0 && configuration.serverPort <= 65535 else {
            throw ProtocolError.invalidPort
        }
        
        // 传输协议验证
        if let transport = configuration.transport,
           !supportedTransports.contains(transport) {
            throw ProtocolError.unsupportedTransport(transport)
        }
        
        // 安全协议验证
        if let security = configuration.security,
           !supportedSecurity.contains(security) {
            throw ProtocolError.unsupportedSecurity(security)
        }
    }
    
    func parseURL(_ url: String) throws -> ProxyConfiguration {
        fatalError("Subclasses must implement parseURL")
    }
    
    func generateURL(from configuration: ProxyConfiguration) throws -> String {
        fatalError("Subclasses must implement generateURL")
    }
    
    // MARK: - Helper Methods
    func generateInbound(port: Int, protocol: String = "socks") -> [String: Any] {
        return [
            "tag": "\(protocol)-in",
            "port": port,
            "protocol": protocol,
            "settings": [
                "auth": "noauth",
                "udp": true
            ]
        ]
    }
    
    func generateOutbound(from configuration: ProxyConfiguration) throws -> [String: Any] {
        var outbound: [String: Any] = [
            "tag": "proxy",
            "protocol": protocolName.lowercased(),
            "settings": try generateProtocolSettings(from: configuration)
        ]
        
        // 添加流设置
        if let streamSettings = try generateStreamSettings(from: configuration) {
            outbound["streamSettings"] = streamSettings
        }
        
        return outbound
    }
    
    func generateProtocolSettings(from configuration: ProxyConfiguration) throws -> [String: Any] {
        fatalError("Subclasses must implement generateProtocolSettings")
    }
    
    func generateStreamSettings(from configuration: ProxyConfiguration) throws -> [String: Any]? {
        guard let transport = configuration.transport else { return nil }
        
        var streamSettings: [String: Any] = [
            "network": transport.rawValue
        ]
        
        // 传输协议设置
        switch transport {
        case .tcp:
            if let tcpSettings = configuration.tcpSettings {
                streamSettings["tcpSettings"] = generateTCPSettings(tcpSettings)
            }
        case .ws:
            if let wsSettings = configuration.wsSettings {
                streamSettings["wsSettings"] = generateWSSettings(wsSettings)
            }
        case .http2:
            if let h2Settings = configuration.h2Settings {
                streamSettings["httpSettings"] = generateH2Settings(h2Settings)
            }
        case .grpc:
            if let grpcSettings = configuration.grpcSettings {
                streamSettings["grpcSettings"] = generateGRPCSettings(grpcSettings)
            }
        case .quic:
            if let quicSettings = configuration.quicSettings {
                streamSettings["quicSettings"] = generateQUICSettings(quicSettings)
            }
        }
        
        // 安全设置
        if let security = configuration.security {
            streamSettings["security"] = security.rawValue
            
            switch security {
            case .tls:
                if let tlsSettings = configuration.tlsSettings {
                    streamSettings["tlsSettings"] = generateTLSSettings(tlsSettings)
                }
            case .xtls:
                if let xtlsSettings = configuration.xtlsSettings {
                    streamSettings["xtlsSettings"] = generateXTLSSettings(xtlsSettings)
                }
            case .reality:
                if let realitySettings = configuration.realitySettings {
                    streamSettings["realitySettings"] = generateRealitySettings(realitySettings)
                }
            case .none:
                break
            }
        }
        
        return streamSettings
    }
    
    // MARK: - Transport Settings Generators
    private func generateTCPSettings(_ settings: TCPSettings) -> [String: Any] {
        var tcpSettings: [String: Any] = [:]
        
        if let header = settings.header {
            tcpSettings["header"] = [
                "type": header.type,
                "request": header.request ?? [:],
                "response": header.response ?? [:]
            ]
        }
        
        return tcpSettings
    }
    
    private func generateWSSettings(_ settings: WSSettings) -> [String: Any] {
        var wsSettings: [String: Any] = [:]
        
        if let path = settings.path {
            wsSettings["path"] = path
        }
        
        if let headers = settings.headers, !headers.isEmpty {
            wsSettings["headers"] = headers
        }
        
        return wsSettings
    }
    
    private func generateH2Settings(_ settings: H2Settings) -> [String: Any] {
        var h2Settings: [String: Any] = [:]
        
        if let hosts = settings.hosts, !hosts.isEmpty {
            h2Settings["host"] = hosts
        }
        
        if let path = settings.path {
            h2Settings["path"] = path
        }
        
        return h2Settings
    }
    
    private func generateGRPCSettings(_ settings: GRPCSettings) -> [String: Any] {
        var grpcSettings: [String: Any] = [:]
        
        if let serviceName = settings.serviceName {
            grpcSettings["serviceName"] = serviceName
        }
        
        grpcSettings["multiMode"] = settings.multiMode
        
        return grpcSettings
    }
    
    private func generateQUICSettings(_ settings: QUICSettings) -> [String: Any] {
        var quicSettings: [String: Any] = [:]
        
        if let security = settings.security {
            quicSettings["security"] = security
        }
        
        if let key = settings.key {
            quicSettings["key"] = key
        }
        
        if let header = settings.header {
            quicSettings["header"] = [
                "type": header.type
            ]
        }
        
        return quicSettings
    }
    
    // MARK: - Security Settings Generators
    private func generateTLSSettings(_ settings: TLSSettings) -> [String: Any] {
        var tlsSettings: [String: Any] = [:]
        
        if let serverName = settings.serverName {
            tlsSettings["serverName"] = serverName
        }
        
        if let alpn = settings.alpn, !alpn.isEmpty {
            tlsSettings["alpn"] = alpn
        }
        
        tlsSettings["allowInsecure"] = settings.allowInsecure
        
        if let fingerprint = settings.fingerprint {
            tlsSettings["fingerprint"] = fingerprint
        }
        
        return tlsSettings
    }
    
    private func generateXTLSSettings(_ settings: XTLSSettings) -> [String: Any] {
        var xtlsSettings: [String: Any] = [:]
        
        if let serverName = settings.serverName {
            xtlsSettings["serverName"] = serverName
        }
        
        if let alpn = settings.alpn, !alpn.isEmpty {
            xtlsSettings["alpn"] = alpn
        }
        
        xtlsSettings["allowInsecure"] = settings.allowInsecure
        
        return xtlsSettings
    }
    
    private func generateRealitySettings(_ settings: RealitySettings) -> [String: Any] {
        var realitySettings: [String: Any] = [:]
        
        if let serverName = settings.serverName {
            realitySettings["serverName"] = serverName
        }
        
        if let fingerprint = settings.fingerprint {
            realitySettings["fingerprint"] = fingerprint
        }
        
        if let publicKey = settings.publicKey {
            realitySettings["publicKey"] = publicKey
        }
        
        if let shortId = settings.shortId {
            realitySettings["shortId"] = shortId
        }
        
        if let spiderX = settings.spiderX {
            realitySettings["spiderX"] = spiderX
        }
        
        return realitySettings
    }
}

// MARK: - Enums
enum TransportType: String, CaseIterable {
    case tcp = "tcp"
    case ws = "ws"
    case http2 = "h2"
    case grpc = "grpc"
    case quic = "quic"
    
    var displayName: String {
        switch self {
        case .tcp: return "TCP"
        case .ws: return "WebSocket"
        case .http2: return "HTTP/2"
        case .grpc: return "gRPC"
        case .quic: return "QUIC"
        }
    }
}

enum SecurityType: String, CaseIterable {
    case none = "none"
    case tls = "tls"
    case xtls = "xtls"
    case reality = "reality"
    
    var displayName: String {
        switch self {
        case .none: return "无加密"
        case .tls: return "TLS"
        case .xtls: return "XTLS"
        case .reality: return "Reality"
        }
    }
}

enum ProtocolError: LocalizedError {
    case invalidServerAddress
    case invalidPort
    case invalidUUID
    case invalidPassword
    case unsupportedTransport(TransportType)
    case unsupportedSecurity(SecurityType)
    case configGenerationFailed(String)
    case urlParsingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidServerAddress:
            return "无效的服务器地址"
        case .invalidPort:
            return "无效的端口号"
        case .invalidUUID:
            return "无效的UUID"
        case .invalidPassword:
            return "无效的密码"
        case .unsupportedTransport(let transport):
            return "不支持的传输协议: \(transport.displayName)"
        case .unsupportedSecurity(let security):
            return "不支持的安全协议: \(security.displayName)"
        case .configGenerationFailed(let message):
            return "配置生成失败: \(message)"
        case .urlParsingFailed(let message):
            return "URL解析失败: \(message)"
        }
    }
}
```

### VMESSProtocol.swift

**作用**：实现VMESS协议的具体功能。

```swift
import Foundation

class VMESSProtocol: BaseV2rayProtocol {
    
    init() {
        super.init(
            name: "VMESS",
            version: "1.0",
            transports: [.tcp, .ws, .http2, .grpc, .quic],
            security: [.none, .tls, .xtls, .reality]
        )
    }
    
    override func generateProtocolSettings(from configuration: ProxyConfiguration) throws -> [String: Any] {
        guard let vmessConfig = configuration.vmessConfig else {
            throw ProtocolError.configGenerationFailed("VMESS配置缺失")
        }
        
        // 验证UUID
        guard isValidUUID(vmessConfig.uuid) else {
            throw ProtocolError.invalidUUID
        }
        
        let vnext: [String: Any] = [
            "address": configuration.serverAddress,
            "port": configuration.serverPort,
            "users": [[
                "id": vmessConfig.uuid,
                "alterId": vmessConfig.alterId,
                "security": vmessConfig.security,
                "level": vmessConfig.level
            ]]
        ]
        
        return ["vnext": [vnext]]
    }
    
    override func parseURL(_ url: String) throws -> ProxyConfiguration {
        // 解析vmess://协议URL
        guard url.hasPrefix("vmess://") else {
            throw ProtocolError.urlParsingFailed("不是有效的VMESS URL")
        }
        
        let base64String = String(url.dropFirst(8)) // 移除"vmess://"
        
        guard let data = Data(base64Encoded: base64String),
              let jsonString = String(data: data, encoding: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProtocolError.urlParsingFailed("无法解析VMESS URL")
        }
        
        guard let address = json["add"] as? String,
              let port = json["port"] as? Int,
              let uuid = json["id"] as? String else {
            throw ProtocolError.urlParsingFailed("VMESS URL缺少必要参数")
        }
        
        var config = ProxyConfiguration(
            id: UUID(),
            name: json["ps"] as? String ?? "VMESS",
            serverAddress: address,
            serverPort: port,
            protocol: .vmess
        )
        
        // VMESS特定配置
        config.vmessConfig = VMESSConfig(
            uuid: uuid,
            alterId: json["aid"] as? Int ?? 0,
            security: json["scy"] as? String ?? "auto",
            level: 0
        )
        
        // 传输协议
        if let net = json["net"] as? String {
            config.transport = TransportType(rawValue: net)
        }
        
        // 安全协议
        if let tls = json["tls"] as? String, !tls.isEmpty {
            config.security = SecurityType(rawValue: tls)
        }
        
        // WebSocket设置
        if config.transport == .ws {
            config.wsSettings = WSSettings(
                path: json["path"] as? String,
                headers: json["host"].flatMap { ["Host": $0 as? String].compactMapValues { $0 } }
            )
        }
        
        // HTTP/2设置
        if config.transport == .http2 {
            config.h2Settings = H2Settings(
                hosts: (json["host"] as? String).map { [$0] },
                path: json["path"] as? String
            )
        }
        
        // gRPC设置
        if config.transport == .grpc {
            config.grpcSettings = GRPCSettings(
                serviceName: json["path"] as? String,
                multiMode: false
            )
        }
        
        // TLS设置
        if config.security == .tls {
            config.tlsSettings = TLSSettings(
                serverName: json["sni"] as? String ?? json["host"] as? String,
                allowInsecure: json["skip-cert-verify"] as? Bool ?? false,
                alpn: (json["alpn"] as? String)?.components(separatedBy: ","),
                fingerprint: json["fp"] as? String
            )
        }
        
        return config
    }
    
    override func generateURL(from configuration: ProxyConfiguration) throws -> String {
        guard let vmessConfig = configuration.vmessConfig else {
            throw ProtocolError.configGenerationFailed("VMESS配置缺失")
        }
        
        var json: [String: Any] = [
            "v": "2",
            "ps": configuration.name,
            "add": configuration.serverAddress,
            "port": configuration.serverPort,
            "id": vmessConfig.uuid,
            "aid": vmessConfig.alterId,
            "scy": vmessConfig.security,
            "net": configuration.transport?.rawValue ?? "tcp",
            "type": "none",
            "host": "",
            "path": "",
            "tls": configuration.security?.rawValue ?? "",
            "sni": "",
            "alpn": ""
        ]
        
        // 传输协议特定设置
        switch configuration.transport {
        case .ws:
            if let wsSettings = configuration.wsSettings {
                json["path"] = wsSettings.path ?? ""
                json["host"] = wsSettings.headers?["Host"] ?? ""
            }
        case .http2:
            if let h2Settings = configuration.h2Settings {
                json["path"] = h2Settings.path ?? ""
                json["host"] = h2Settings.hosts?.first ?? ""
            }
        case .grpc:
            if let grpcSettings = configuration.grpcSettings {
                json["path"] = grpcSettings.serviceName ?? ""
                json["type"] = grpcSettings.multiMode ? "multi" : "gun"
            }
        default:
            break
        }
        
        // TLS设置
        if let tlsSettings = configuration.tlsSettings {
            json["sni"] = tlsSettings.serverName ?? ""
            json["alpn"] = tlsSettings.alpn?.joined(separator: ",") ?? ""
            json["fp"] = tlsSettings.fingerprint ?? ""
        }
        
        // 序列化为JSON
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let base64String = jsonData.base64EncodedString()
        
        return "vmess://" + base64String
    }
    
    override func validate(configuration: ProxyConfiguration) throws {
        try super.validate(configuration: configuration)
        
        guard let vmessConfig = configuration.vmessConfig else {
            throw ProtocolError.configGenerationFailed("VMESS配置缺失")
        }
        
        // 验证UUID格式
        guard isValidUUID(vmessConfig.uuid) else {
            throw ProtocolError.invalidUUID
        }
        
        // 验证alterId
        guard vmessConfig.alterId >= 0 && vmessConfig.alterId <= 65535 else {
            throw ProtocolError.configGenerationFailed("无效的alterId")
        }
        
        // 验证安全方法
        let validSecurityMethods = ["auto", "aes-128-gcm", "chacha20-poly1305", "none"]
        guard validSecurityMethods.contains(vmessConfig.security) else {
            throw ProtocolError.configGenerationFailed("无效的安全方法")
        }
    }
    
    // MARK: - Helper Methods
    private func isValidUUID(_ uuid: String) -> Bool {
        let uuidRegex = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", uuidRegex)
        return predicate.evaluate(with: uuid)
    }
}

// MARK: - VMESS Configuration
struct VMESSConfig: Codable {
    let uuid: String
    let alterId: Int
    let security: String
    let level: Int
    
    init(uuid: String, alterId: Int = 0, security: String = "auto", level: Int = 0) {
        self.uuid = uuid
        self.alterId = alterId
        self.security = security
        self.level = level
    }
}
```

### TrojanProtocol.swift

**作用**：实现Trojan协议的具体功能。

```swift
import Foundation

class TrojanProtocol: BaseV2rayProtocol {
    
    init() {
        super.init(
            name: "Trojan",
            version: "1.0",
            transports: [.tcp, .ws, .grpc],
            security: [.tls, .xtls, .reality]
        )
    }
    
    override func generateProtocolSettings(from configuration: ProxyConfiguration) throws -> [String: Any] {
        guard let trojanConfig = configuration.trojanConfig else {
            throw ProtocolError.configGenerationFailed("Trojan配置缺失")
        }
        
        guard !trojanConfig.password.isEmpty else {
            throw ProtocolError.invalidPassword
        }
        
        let server: [String: Any] = [
            "address": configuration.serverAddress,
            "port": configuration.serverPort,
            "password": trojanConfig.password,
            "level": trojanConfig.level
        ]
        
        return ["servers": [server]]
    }
    
    override func parseURL(_ url: String) throws -> ProxyConfiguration {
        // 解析trojan://协议URL
        guard url.hasPrefix("trojan://") else {
            throw ProtocolError.urlParsingFailed("不是有效的Trojan URL")
        }
        
        guard let urlComponents = URLComponents(string: url) else {
            throw ProtocolError.urlParsingFailed("无法解析Trojan URL")
        }
        
        guard let host = urlComponents.host,
              let password = urlComponents.user else {
            throw ProtocolError.urlParsingFailed("Trojan URL缺少必要参数")
        }
        
        let port = urlComponents.port ?? 443
        let name = urlComponents.fragment ?? "Trojan"
        
        var config = ProxyConfiguration(
            id: UUID(),
            name: name,
            serverAddress: host,
            serverPort: port,
            protocol: .trojan
        )
        
        // Trojan特定配置
        config.trojanConfig = TrojanConfig(
            password: password,
            level: 0
        )
        
        // 解析查询参数
        let queryItems = urlComponents.queryItems ?? []
        let queryDict = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
        
        // 传输协议
        if let type = queryDict["type"] {
            config.transport = TransportType(rawValue: type)
        }
        
        // 安全协议（Trojan默认使用TLS）
        config.security = .tls
        if let security = queryDict["security"] {
            config.security = SecurityType(rawValue: security)
        }
        
        // WebSocket设置
        if config.transport == .ws {
            config.wsSettings = WSSettings(
                path: queryDict["path"],
                headers: queryDict["host"].map { ["Host": $0] }
            )
        }
        
        // gRPC设置
        if config.transport == .grpc {
            config.grpcSettings = GRPCSettings(
                serviceName: queryDict["serviceName"],
                multiMode: queryDict["mode"] == "multi"
            )
        }
        
        // TLS设置
        config.tlsSettings = TLSSettings(
            serverName: queryDict["sni"] ?? host,
            allowInsecure: queryDict["allowInsecure"] == "1",
            alpn: queryDict["alpn"]?.components(separatedBy: ","),
            fingerprint: queryDict["fp"]
        )
        
        return config
    }
    
    override func generateURL(from configuration: ProxyConfiguration) throws -> String {
        guard let trojanConfig = configuration.trojanConfig else {
            throw ProtocolError.configGenerationFailed("Trojan配置缺失")
        }
        
        var components = URLComponents()
        components.scheme = "trojan"
        components.user = trojanConfig.password
        components.host = configuration.serverAddress
        components.port = configuration.serverPort
        components.fragment = configuration.name
        
        var queryItems: [URLQueryItem] = []
        
        // 传输协议
        if let transport = configuration.transport {
            queryItems.append(URLQueryItem(name: "type", value: transport.rawValue))
        }
        
        // 安全协议
        if let security = configuration.security {
            queryItems.append(URLQueryItem(name: "security", value: security.rawValue))
        }
        
        // WebSocket设置
        if let wsSettings = configuration.wsSettings {
            if let path = wsSettings.path {
                queryItems.append(URLQueryItem(name: "path", value: path))
            }
            if let host = wsSettings.headers?["Host"] {
                queryItems.append(URLQueryItem(name: "host", value: host))
            }
        }
        
        // gRPC设置
        if let grpcSettings = configuration.grpcSettings {
            if let serviceName = grpcSettings.serviceName {
                queryItems.append(URLQueryItem(name: "serviceName", value: serviceName))
            }
            queryItems.append(URLQueryItem(name: "mode", value: grpcSettings.multiMode ? "multi" : "gun"))
        }
        
        // TLS设置
        if let tlsSettings = configuration.tlsSettings {
            if let serverName = tlsSettings.serverName {
                queryItems.append(URLQueryItem(name: "sni", value: serverName))
            }
            if tlsSettings.allowInsecure {
                queryItems.append(URLQueryItem(name: "allowInsecure", value: "1"))
            }
            if let alpn = tlsSettings.alpn {
                queryItems.append(URLQueryItem(name: "alpn", value: alpn.joined(separator: ",")))
            }
            if let fingerprint = tlsSettings.fingerprint {
                queryItems.append(URLQueryItem(name: "fp", value: fingerprint))
            }
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let url = components.url?.absoluteString else {
            throw ProtocolError.urlParsingFailed("无法生成Trojan URL")
        }
        
        return url
    }
    
    override func validate(configuration: ProxyConfiguration) throws {
        try super.validate(configuration: configuration)
        
        guard let trojanConfig = configuration.trojanConfig else {
            throw ProtocolError.configGenerationFailed("Trojan配置缺失")
        }
        
        // 验证密码
        guard !trojanConfig.password.isEmpty else {
            throw ProtocolError.invalidPassword
        }
        
        // Trojan必须使用TLS
        guard configuration.security != .none else {
            throw ProtocolError.configGenerationFailed("Trojan协议必须使用TLS加密")
        }
    }
}

// MARK: - Trojan Configuration
struct TrojanConfig: Codable {
    let password: String
    let level: Int
    
    init(password: String, level: Int = 0) {
        self.password = password
        self.level = level
    }
}
```

---

## 🔒 安全协议

### TLSSecurity.swift

**作用**：实现TLS安全层的配置和管理。

```swift
import Foundation
import Security

class TLSSecurity {
    
    // MARK: - TLS Configuration
    static func generateTLSConfig(from settings: TLSSettings) -> [String: Any] {
        var tlsConfig: [String: Any] = [:]
        
        // 服务器名称
        if let serverName = settings.serverName {
            tlsConfig["serverName"] = serverName
        }
        
        // ALPN协议
        if let alpn = settings.alpn, !alpn.isEmpty {
            tlsConfig["alpn"] = alpn
        }
        
        // 证书验证
        tlsConfig["allowInsecure"] = settings.allowInsecure
        
        // 指纹验证
        if let fingerprint = settings.fingerprint {
            tlsConfig["fingerprint"] = fingerprint
        }
        
        // 证书配置
        if let certificates = settings.certificates, !certificates.isEmpty {
            tlsConfig["certificates"] = certificates.map { cert in
                return [
                    "certificateFile": cert.certificateFile,
                    "keyFile": cert.keyFile
                ]
            }
        }
        
        // 最小TLS版本
        if let minVersion = settings.minVersion {
            tlsConfig["minVersion"] = minVersion
        }
        
        // 最大TLS版本
        if let maxVersion = settings.maxVersion {
            tlsConfig["maxVersion"] = maxVersion
        }
        
        // 密码套件
        if let cipherSuites = settings.cipherSuites, !cipherSuites.isEmpty {
            tlsConfig["cipherSuites"] = cipherSuites
        }
        
        return tlsConfig
    }
    
    // MARK: - Certificate Validation
    static func validateCertificate(_ certificate: Data, for serverName: String) -> Bool {
        guard let cert = SecCertificateCreateWithData(nil, certificate) else {
            return false
        }
        
        // 创建信任策略
        let policy = SecPolicyCreateSSL(true, serverName as CFString)
        
        // 创建信任对象
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(cert, policy, &trust)
        
        guard status == errSecSuccess, let trust = trust else {
            return false
        }
        
        // 评估信任
        var result: SecTrustResultType = .invalid
        let evaluateStatus = SecTrustEvaluate(trust, &result)
        
        return evaluateStatus == errSecSuccess && 
               (result == .unspecified || result == .proceed)
    }
    
    // MARK: - Fingerprint Verification
    static func verifyFingerprint(_ certificate: Data, expectedFingerprint: String) -> Bool {
        let actualFingerprint = generateFingerprint(certificate)
        return actualFingerprint.lowercased() == expectedFingerprint.lowercased()
    }
    
    static func generateFingerprint(_ certificate: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        certificate.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(certificate.count), &digest)
        }
        
        return digest.map { String(format: "%02x", $0) }.joined(separator: ":")
    }
    
    // MARK: - ALPN Support
    static func getSupportedALPNProtocols() -> [String] {
        return ["h2", "http/1.1", "h3"]
    }
    
    // MARK: - Cipher Suites
    static func getRecommendedCipherSuites() -> [String] {
        return [
            "TLS_AES_128_GCM_SHA256",
            "TLS_AES_256_GCM_SHA384",
            "TLS_CHACHA20_POLY1305_SHA256",
            "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
            "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
            "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
            "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
            "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
            "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"
        ]
    }
}

// MARK: - TLS Settings
struct TLSSettings: Codable {
    let serverName: String?
    let allowInsecure: Bool
    let alpn: [String]?
    let fingerprint: String?
    let certificates: [TLSCertificate]?
    let minVersion: String?
    let maxVersion: String?
    let cipherSuites: [String]?
    
    init(serverName: String? = nil,
         allowInsecure: Bool = false,
         alpn: [String]? = nil,
         fingerprint: String? = nil,
         certificates: [TLSCertificate]? = nil,
         minVersion: String? = nil,
         maxVersion: String? = nil,
         cipherSuites: [String]? = nil) {
        self.serverName = serverName
        self.allowInsecure = allowInsecure
        self.alpn = alpn
        self.fingerprint = fingerprint
        self.certificates = certificates
        self.minVersion = minVersion
        self.maxVersion = maxVersion
        self.cipherSuites = cipherSuites
    }
}

struct TLSCertificate: Codable {
    let certificateFile: String
    let keyFile: String
    
    init(certificateFile: String, keyFile: String) {
        self.certificateFile = certificateFile
        self.keyFile = keyFile
    }
}
```

---

## 🔗 相关文档

- [协议层模块](../modules/protocol-layer.md)
- [核心文件详解](core-files.md)
- [处理器文件详解](handler-files.md)
- [应用架构模块](../modules/app-architecture.md)

---

## 📝 总结

协议文件是V2rayU应用的网络通信核心，负责实现各种代理协议的支持和网络传输功能。通过模块化的设计和标准化的接口，确保了协议的可扩展性和兼容性。

### 设计特点

1. **协议抽象**：通过协议接口实现统一的协议管理
2. **模块化设计**：每个协议独立实现，便于维护和扩展
3. **安全优先**：完善的TLS/XTLS/Reality安全层支持
4. **传输灵活**：支持多种传输协议和组合方式
5. **配置验证**：严格的配置验证和错误处理机制

这些协议文件共同构成了V2rayU应用的网络通信基础，为用户提供了安全可靠的代理连接服务。
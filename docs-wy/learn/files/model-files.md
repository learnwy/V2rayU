# 模型文件详解

## 📋 概述

本文档详细解析V2rayU项目中的数据模型文件，包括服务器配置、订阅管理、用户设置等核心数据结构的定义、关系和使用方法。

## 🏗️ 模型分类

### 1. 核心配置模型
- `V2rayConfig.swift` - V2ray配置模型
- `ServerConfig.swift` - 服务器配置模型
- `ProtocolConfig.swift` - 协议配置模型

### 2. 订阅管理模型
- `Subscription.swift` - 订阅模型
- `SubscriptionGroup.swift` - 订阅分组模型
- `ServerNode.swift` - 服务器节点模型

### 3. 用户设置模型
- `AppSettings.swift` - 应用设置模型
- `ProxySettings.swift` - 代理设置模型
- `UISettings.swift` - 界面设置模型

### 4. 统计数据模型
- `TrafficData.swift` - 流量数据模型
- `ConnectionLog.swift` - 连接日志模型
- `PerformanceMetrics.swift` - 性能指标模型

## 📁 详细模型解析

### 1. V2rayConfig.swift

**文件路径**: `V2rayU/Models/V2rayConfig.swift`

**功能描述**: V2ray核心配置的完整数据模型，包含所有V2ray支持的配置选项。

```swift
import Foundation

/// V2ray完整配置模型
struct V2rayConfig: Codable, Equatable {
    // MARK: - 基础配置
    let log: LogConfig?
    let api: APIConfig?
    let dns: DNSConfig?
    let routing: RoutingConfig?
    let policy: PolicyConfig?
    let inbounds: [InboundConfig]
    let outbounds: [OutboundConfig]
    let transport: TransportConfig?
    let stats: StatsConfig?
    let reverse: ReverseConfig?
    let fakedns: [FakeDNSConfig]?
    
    // MARK: - 初始化
    init(
        log: LogConfig? = nil,
        api: APIConfig? = nil,
        dns: DNSConfig? = nil,
        routing: RoutingConfig? = nil,
        policy: PolicyConfig? = nil,
        inbounds: [InboundConfig] = [],
        outbounds: [OutboundConfig] = [],
        transport: TransportConfig? = nil,
        stats: StatsConfig? = nil,
        reverse: ReverseConfig? = nil,
        fakedns: [FakeDNSConfig]? = nil
    ) {
        self.log = log
        self.api = api
        self.dns = dns
        self.routing = routing
        self.policy = policy
        self.inbounds = inbounds
        self.outbounds = outbounds
        self.transport = transport
        self.stats = stats
        self.reverse = reverse
        self.fakedns = fakedns
    }
    
    // MARK: - 便利方法
    
    /// 创建默认配置
    static func defaultConfig() -> V2rayConfig {
        return V2rayConfig(
            log: LogConfig.default,
            api: APIConfig.default,
            dns: DNSConfig.default,
            routing: RoutingConfig.default,
            policy: PolicyConfig.default,
            inbounds: [InboundConfig.defaultSOCKS(), InboundConfig.defaultHTTP()],
            outbounds: [OutboundConfig.defaultDirect(), OutboundConfig.defaultBlocked()],
            stats: StatsConfig.default
        )
    }
    
    /// 添加服务器配置
    func withServer(_ server: ServerConfig) -> V2rayConfig {
        var config = self
        let outbound = OutboundConfig.fromServer(server)
        
        // 插入到第一个位置（作为主要出站）
        config.outbounds.insert(outbound, at: 0)
        
        return config
    }
    
    /// 验证配置
    func validate() throws {
        // 验证入站配置
        if inbounds.isEmpty {
            throw ConfigError.noInbounds
        }
        
        // 验证出站配置
        if outbounds.isEmpty {
            throw ConfigError.noOutbounds
        }
        
        // 验证端口冲突
        let inboundPorts = inbounds.compactMap { $0.port }
        let uniquePorts = Set(inboundPorts)
        if inboundPorts.count != uniquePorts.count {
            throw ConfigError.portConflict
        }
        
        // 验证路由配置
        try routing?.validate()
    }
    
    /// 获取主要出站
    var primaryOutbound: OutboundConfig? {
        return outbounds.first { $0.tag != "direct" && $0.tag != "blocked" }
    }
    
    /// 获取SOCKS端口
    var socksPort: Int? {
        return inbounds.first { $0.protocol == "socks" }?.port
    }
    
    /// 获取HTTP端口
    var httpPort: Int? {
        return inbounds.first { $0.protocol == "http" }?.port
    }
}

// MARK: - 日志配置
struct LogConfig: Codable, Equatable {
    let access: String?
    let error: String?
    let loglevel: String?
    let dnsLog: Bool?
    
    static let `default` = LogConfig(
        access: "",
        error: "",
        loglevel: "warning",
        dnsLog: false
    )
}

// MARK: - API配置
struct APIConfig: Codable, Equatable {
    let tag: String
    let services: [String]
    
    static let `default` = APIConfig(
        tag: "api",
        services: ["HandlerService", "LoggerService", "StatsService"]
    )
}

// MARK: - DNS配置
struct DNSConfig: Codable, Equatable {
    let hosts: [String: String]?
    let servers: [DNSServer]
    let clientIp: String?
    let tag: String?
    let queryStrategy: String?
    let disableCache: Bool?
    let disableFallback: Bool?
    
    static let `default` = DNSConfig(
        hosts: nil,
        servers: [
            DNSServer(address: "https://1.1.1.1/dns-query", domains: ["geosite:geolocation-!cn"]),
            DNSServer(address: "223.5.5.5", domains: ["geosite:cn"])
        ],
        clientIp: nil,
        tag: "dns_inbound",
        queryStrategy: "UseIP",
        disableCache: false,
        disableFallback: false
    )
}

struct DNSServer: Codable, Equatable {
    let address: String
    let port: Int?
    let domains: [String]?
    let expectIPs: [String]?
    let skipFallback: Bool?
    
    init(
        address: String,
        port: Int? = nil,
        domains: [String]? = nil,
        expectIPs: [String]? = nil,
        skipFallback: Bool? = nil
    ) {
        self.address = address
        self.port = port
        self.domains = domains
        self.expectIPs = expectIPs
        self.skipFallback = skipFallback
    }
}

// MARK: - 路由配置
struct RoutingConfig: Codable, Equatable {
    let domainStrategy: String?
    let domainMatcher: String?
    let rules: [RoutingRule]
    let balancers: [Balancer]?
    
    static let `default` = RoutingConfig(
        domainStrategy: "IPIfNonMatch",
        domainMatcher: "hybrid",
        rules: [
            // API规则
            RoutingRule(
                type: "field",
                inboundTag: ["api"],
                outboundTag: "api"
            ),
            // 直连规则
            RoutingRule(
                type: "field",
                domain: ["geosite:cn"],
                outboundTag: "direct"
            ),
            RoutingRule(
                type: "field",
                ip: ["geoip:cn", "geoip:private"],
                outboundTag: "direct"
            ),
            // 阻断规则
            RoutingRule(
                type: "field",
                domain: ["geosite:category-ads-all"],
                outboundTag: "blocked"
            )
        ],
        balancers: nil
    )
    
    func validate() throws {
        // 验证规则
        for rule in rules {
            try rule.validate()
        }
    }
}

struct RoutingRule: Codable, Equatable {
    let type: String
    let domain: [String]?
    let ip: [String]?
    let port: String?
    let sourcePort: String?
    let network: String?
    let source: [String]?
    let user: [String]?
    let inboundTag: [String]?
    let protocol: [String]?
    let attrs: String?
    let outboundTag: String
    let balancerTag: String?
    
    init(
        type: String = "field",
        domain: [String]? = nil,
        ip: [String]? = nil,
        port: String? = nil,
        sourcePort: String? = nil,
        network: String? = nil,
        source: [String]? = nil,
        user: [String]? = nil,
        inboundTag: [String]? = nil,
        protocol: [String]? = nil,
        attrs: String? = nil,
        outboundTag: String,
        balancerTag: String? = nil
    ) {
        self.type = type
        self.domain = domain
        self.ip = ip
        self.port = port
        self.sourcePort = sourcePort
        self.network = network
        self.source = source
        self.user = user
        self.inboundTag = inboundTag
        self.protocol = `protocol`
        self.attrs = attrs
        self.outboundTag = outboundTag
        self.balancerTag = balancerTag
    }
    
    func validate() throws {
        if outboundTag.isEmpty && balancerTag?.isEmpty != false {
            throw ConfigError.invalidRoutingRule
        }
    }
}

struct Balancer: Codable, Equatable {
    let tag: String
    let selector: [String]
    let strategy: BalancerStrategy?
    
    enum BalancerStrategy: String, Codable, CaseIterable {
        case random = "random"
        case leastPing = "leastPing"
        case roundRobin = "roundRobin"
    }
}

// MARK: - 策略配置
struct PolicyConfig: Codable, Equatable {
    let levels: [String: LevelPolicy]?
    let system: SystemPolicy?
    
    static let `default` = PolicyConfig(
        levels: [
            "0": LevelPolicy(
                handshake: 4,
                connIdle: 300,
                uplinkOnly: 2,
                downlinkOnly: 5,
                statsUserUplink: false,
                statsUserDownlink: false,
                bufferSize: 512
            )
        ],
        system: SystemPolicy(
            statsInboundUplink: false,
            statsInboundDownlink: false,
            statsOutboundUplink: false,
            statsOutboundDownlink: false
        )
    )
}

struct LevelPolicy: Codable, Equatable {
    let handshake: Int?
    let connIdle: Int?
    let uplinkOnly: Int?
    let downlinkOnly: Int?
    let statsUserUplink: Bool?
    let statsUserDownlink: Bool?
    let bufferSize: Int?
}

struct SystemPolicy: Codable, Equatable {
    let statsInboundUplink: Bool?
    let statsInboundDownlink: Bool?
    let statsOutboundUplink: Bool?
    let statsOutboundDownlink: Bool?
}

// MARK: - 入站配置
struct InboundConfig: Codable, Equatable {
    let tag: String?
    let port: Int?
    let listen: String?
    let `protocol`: String
    let settings: InboundSettings?
    let streamSettings: StreamSettings?
    let sniffing: SniffingConfig?
    let allocate: AllocateConfig?
    
    static func defaultSOCKS(port: Int = 1080) -> InboundConfig {
        return InboundConfig(
            tag: "socks",
            port: port,
            listen: "127.0.0.1",
            protocol: "socks",
            settings: InboundSettings.socks(
                SOCKSInboundSettings(
                    auth: "noauth",
                    accounts: nil,
                    udp: true,
                    ip: "127.0.0.1",
                    userLevel: 0
                )
            ),
            streamSettings: nil,
            sniffing: SniffingConfig(
                enabled: true,
                destOverride: ["http", "tls"]
            ),
            allocate: nil
        )
    }
    
    static func defaultHTTP(port: Int = 1087) -> InboundConfig {
        return InboundConfig(
            tag: "http",
            port: port,
            listen: "127.0.0.1",
            protocol: "http",
            settings: InboundSettings.http(
                HTTPInboundSettings(
                    timeout: 0,
                    accounts: nil,
                    allowTransparent: false,
                    userLevel: 0
                )
            ),
            streamSettings: nil,
            sniffing: SniffingConfig(
                enabled: true,
                destOverride: ["http", "tls"]
            ),
            allocate: nil
        )
    }
}

// MARK: - 出站配置
struct OutboundConfig: Codable, Equatable {
    let tag: String?
    let sendThrough: String?
    let `protocol`: String
    let settings: OutboundSettings?
    let streamSettings: StreamSettings?
    let proxySettings: ProxySettings?
    let mux: MuxConfig?
    
    static func defaultDirect() -> OutboundConfig {
        return OutboundConfig(
            tag: "direct",
            sendThrough: nil,
            protocol: "freedom",
            settings: OutboundSettings.freedom(
                FreedomOutboundSettings(
                    domainStrategy: "UseIP",
                    redirect: nil,
                    userLevel: 0
                )
            ),
            streamSettings: nil,
            proxySettings: nil,
            mux: nil
        )
    }
    
    static func defaultBlocked() -> OutboundConfig {
        return OutboundConfig(
            tag: "blocked",
            sendThrough: nil,
            protocol: "blackhole",
            settings: OutboundSettings.blackhole(
                BlackholeOutboundSettings(
                    response: BlackholeResponse(type: "http")
                )
            ),
            streamSettings: nil,
            proxySettings: nil,
            mux: nil
        )
    }
    
    static func fromServer(_ server: ServerConfig) -> OutboundConfig {
        switch server.protocol {
        case .vmess:
            return createVMessOutbound(server)
        case .vless:
            return createVLESSOutbound(server)
        case .trojan:
            return createTrojanOutbound(server)
        case .shadowsocks:
            return createShadowsocksOutbound(server)
        }
    }
    
    private static func createVMessOutbound(_ server: ServerConfig) -> OutboundConfig {
        guard case .vmess(let vmessConfig) = server.protocolSettings else {
            fatalError("Invalid protocol settings for VMess")
        }
        
        return OutboundConfig(
            tag: server.name,
            sendThrough: nil,
            protocol: "vmess",
            settings: OutboundSettings.vmess(
                VMessOutboundSettings(
                    vnext: [
                        VMessServer(
                            address: server.address,
                            port: server.port,
                            users: [
                                VMessUser(
                                    id: vmessConfig.uuid,
                                    alterId: vmessConfig.alterId,
                                    security: vmessConfig.security,
                                    level: 0
                                )
                            ]
                        )
                    ]
                )
            ),
            streamSettings: server.streamSettings,
            proxySettings: nil,
            mux: server.muxSettings
        )
    }
    
    private static func createVLESSOutbound(_ server: ServerConfig) -> OutboundConfig {
        guard case .vless(let vlessConfig) = server.protocolSettings else {
            fatalError("Invalid protocol settings for VLESS")
        }
        
        return OutboundConfig(
            tag: server.name,
            sendThrough: nil,
            protocol: "vless",
            settings: OutboundSettings.vless(
                VLESSOutboundSettings(
                    vnext: [
                        VLESSServer(
                            address: server.address,
                            port: server.port,
                            users: [
                                VLESSUser(
                                    id: vlessConfig.uuid,
                                    encryption: vlessConfig.encryption,
                                    flow: vlessConfig.flow,
                                    level: 0
                                )
                            ]
                        )
                    ]
                )
            ),
            streamSettings: server.streamSettings,
            proxySettings: nil,
            mux: server.muxSettings
        )
    }
    
    private static func createTrojanOutbound(_ server: ServerConfig) -> OutboundConfig {
        guard case .trojan(let trojanConfig) = server.protocolSettings else {
            fatalError("Invalid protocol settings for Trojan")
        }
        
        return OutboundConfig(
            tag: server.name,
            sendThrough: nil,
            protocol: "trojan",
            settings: OutboundSettings.trojan(
                TrojanOutboundSettings(
                    servers: [
                        TrojanServer(
                            address: server.address,
                            port: server.port,
                            password: trojanConfig.password,
                            email: trojanConfig.email,
                            level: 0
                        )
                    ]
                )
            ),
            streamSettings: server.streamSettings,
            proxySettings: nil,
            mux: nil // Trojan通常不使用mux
        )
    }
    
    private static func createShadowsocksOutbound(_ server: ServerConfig) -> OutboundConfig {
        guard case .shadowsocks(let ssConfig) = server.protocolSettings else {
            fatalError("Invalid protocol settings for Shadowsocks")
        }
        
        return OutboundConfig(
            tag: server.name,
            sendThrough: nil,
            protocol: "shadowsocks",
            settings: OutboundSettings.shadowsocks(
                ShadowsocksOutboundSettings(
                    servers: [
                        ShadowsocksServer(
                            address: server.address,
                            port: server.port,
                            method: ssConfig.method,
                            password: ssConfig.password,
                            uot: ssConfig.uot,
                            level: 0
                        )
                    ]
                )
            ),
            streamSettings: nil, // Shadowsocks通常不使用streamSettings
            proxySettings: nil,
            mux: nil
        )
    }
}

// MARK: - 传输配置
struct TransportConfig: Codable, Equatable {
    let tcpSettings: TCPConfig?
    let kcpSettings: KCPConfig?
    let wsSettings: WebSocketConfig?
    let httpSettings: HTTPConfig?
    let dsSettings: DomainSocketConfig?
    let quicSettings: QUICConfig?
    let grpcSettings: GRPCConfig?
}

// MARK: - 统计配置
struct StatsConfig: Codable, Equatable {
    static let `default` = StatsConfig()
}

// MARK: - 反向代理配置
struct ReverseConfig: Codable, Equatable {
    let bridges: [BridgeConfig]?
    let portals: [PortalConfig]?
}

struct BridgeConfig: Codable, Equatable {
    let tag: String
    let domain: String
}

struct PortalConfig: Codable, Equatable {
    let tag: String
    let domain: String
}

// MARK: - FakeDNS配置
struct FakeDNSConfig: Codable, Equatable {
    let ipPool: String
    let poolSize: Int
}

// MARK: - 配置错误
enum ConfigError: LocalizedError {
    case noInbounds
    case noOutbounds
    case portConflict
    case invalidRoutingRule
    case invalidProtocolSettings
    case invalidStreamSettings
    
    var errorDescription: String? {
        switch self {
        case .noInbounds:
            return "没有入站配置"
        case .noOutbounds:
            return "没有出站配置"
        case .portConflict:
            return "端口冲突"
        case .invalidRoutingRule:
            return "无效的路由规则"
        case .invalidProtocolSettings:
            return "无效的协议设置"
        case .invalidStreamSettings:
            return "无效的传输设置"
        }
    }
}
```

### 2. ServerConfig.swift

**文件路径**: `V2rayU/Models/ServerConfig.swift`

**功能描述**: 服务器配置的数据模型，支持多种代理协议。

```swift
import Foundation

/// 服务器配置模型
struct ServerConfig: Codable, Identifiable, Equatable {
    // MARK: - 基础属性
    let id: UUID
    var name: String
    var address: String
    var port: Int
    var protocol: ProxyProtocol
    var protocolSettings: ProtocolSettings
    var streamSettings: StreamSettings?
    var muxSettings: MuxConfig?
    
    // MARK: - 元数据
    var group: String?
    var remarks: String?
    var isActive: Bool
    var lastUsed: Date?
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - 统计数据
    var totalUpload: UInt64
    var totalDownload: UInt64
    var lastPingTime: TimeInterval?
    var averagePing: TimeInterval?
    
    // MARK: - 订阅信息
    var subscriptionID: UUID?
    var subscriptionIndex: Int?
    
    // MARK: - 初始化
    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        port: Int,
        protocol: ProxyProtocol,
        protocolSettings: ProtocolSettings,
        streamSettings: StreamSettings? = nil,
        muxSettings: MuxConfig? = nil,
        group: String? = nil,
        remarks: String? = nil,
        isActive: Bool = false,
        subscriptionID: UUID? = nil,
        subscriptionIndex: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.port = port
        self.protocol = `protocol`
        self.protocolSettings = protocolSettings
        self.streamSettings = streamSettings
        self.muxSettings = muxSettings
        self.group = group
        self.remarks = remarks
        self.isActive = isActive
        self.subscriptionID = subscriptionID
        self.subscriptionIndex = subscriptionIndex
        
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        self.lastUsed = nil
        self.totalUpload = 0
        self.totalDownload = 0
        self.lastPingTime = nil
        self.averagePing = nil
    }
    
    // MARK: - 计算属性
    
    /// 总流量
    var totalTraffic: UInt64 {
        return totalUpload + totalDownload
    }
    
    /// 格式化的地址
    var formattedAddress: String {
        return "\(address):\(port)"
    }
    
    /// 协议显示名称
    var protocolDisplayName: String {
        return `protocol`.displayName
    }
    
    /// 连接URL
    var connectionURL: String {
        switch `protocol` {
        case .vmess:
            return generateVMessURL()
        case .vless:
            return generateVLESSURL()
        case .trojan:
            return generateTrojanURL()
        case .shadowsocks:
            return generateShadowsocksURL()
        }
    }
    
    /// 是否来自订阅
    var isFromSubscription: Bool {
        return subscriptionID != nil
    }
    
    /// 延迟状态
    var pingStatus: PingStatus {
        guard let ping = lastPingTime else {
            return .unknown
        }
        
        if ping < 0 {
            return .timeout
        } else if ping < 100 {
            return .excellent
        } else if ping < 300 {
            return .good
        } else if ping < 500 {
            return .fair
        } else {
            return .poor
        }
    }
    
    // MARK: - 方法
    
    /// 更新使用时间
    mutating func updateLastUsed() {
        lastUsed = Date()
        updatedAt = Date()
    }
    
    /// 更新流量统计
    mutating func updateTraffic(upload: UInt64, download: UInt64) {
        totalUpload += upload
        totalDownload += download
        updatedAt = Date()
    }
    
    /// 更新延迟
    mutating func updatePing(_ ping: TimeInterval) {
        lastPingTime = ping
        
        // 计算平均延迟
        if let currentAverage = averagePing {
            averagePing = (currentAverage + ping) / 2
        } else {
            averagePing = ping
        }
        
        updatedAt = Date()
    }
    
    /// 验证配置
    func validate() throws {
        // 验证地址
        if address.isEmpty {
            throw ServerConfigError.invalidAddress
        }
        
        // 验证端口
        if port <= 0 || port > 65535 {
            throw ServerConfigError.invalidPort
        }
        
        // 验证协议设置
        try protocolSettings.validate(for: `protocol`)
        
        // 验证传输设置
        try streamSettings?.validate()
    }
    
    /// 克隆配置
    func clone() -> ServerConfig {
        var cloned = self
        cloned.id = UUID()
        cloned.name = "\(name) (Copy)"
        cloned.isActive = false
        cloned.createdAt = Date()
        cloned.updatedAt = Date()
        cloned.lastUsed = nil
        cloned.totalUpload = 0
        cloned.totalDownload = 0
        cloned.lastPingTime = nil
        cloned.averagePing = nil
        return cloned
    }
    
    // MARK: - URL生成
    
    private func generateVMessURL() -> String {
        guard case .vmess(let vmessConfig) = protocolSettings else {
            return ""
        }
        
        let config: [String: Any] = [
            "v": "2",
            "ps": name,
            "add": address,
            "port": port,
            "id": vmessConfig.uuid,
            "aid": vmessConfig.alterId,
            "scy": vmessConfig.security,
            "net": streamSettings?.network ?? "tcp",
            "type": streamSettings?.tcpSettings?.header?.type ?? "none",
            "host": streamSettings?.wsSettings?.headers?["Host"] ?? "",
            "path": streamSettings?.wsSettings?.path ?? "",
            "tls": streamSettings?.security ?? "none",
            "sni": streamSettings?.tlsSettings?.serverName ?? "",
            "alpn": streamSettings?.tlsSettings?.alpn?.joined(separator: ",") ?? ""
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: config),
           let jsonString = String(data: jsonData, encoding: .utf8),
           let encodedString = jsonString.data(using: .utf8)?.base64EncodedString() {
            return "vmess://\(encodedString)"
        }
        
        return ""
    }
    
    private func generateVLESSURL() -> String {
        guard case .vless(let vlessConfig) = protocolSettings else {
            return ""
        }
        
        var components = URLComponents()
        components.scheme = "vless"
        components.user = vlessConfig.uuid
        components.host = address
        components.port = port
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "encryption", value: vlessConfig.encryption)
        ]
        
        if let flow = vlessConfig.flow {
            queryItems.append(URLQueryItem(name: "flow", value: flow))
        }
        
        if let streamSettings = streamSettings {
            queryItems.append(URLQueryItem(name: "type", value: streamSettings.network))
            
            if let security = streamSettings.security {
                queryItems.append(URLQueryItem(name: "security", value: security))
            }
            
            // 添加其他传输层参数
            switch streamSettings.network {
            case "ws":
                if let path = streamSettings.wsSettings?.path {
                    queryItems.append(URLQueryItem(name: "path", value: path))
                }
                if let host = streamSettings.wsSettings?.headers?["Host"] {
                    queryItems.append(URLQueryItem(name: "host", value: host))
                }
            case "grpc":
                if let serviceName = streamSettings.grpcSettings?.serviceName {
                    queryItems.append(URLQueryItem(name: "serviceName", value: serviceName))
                }
            default:
                break
            }
        }
        
        queryItems.append(URLQueryItem(name: "#", value: name))
        components.queryItems = queryItems
        
        return components.url?.absoluteString ?? ""
    }
    
    private func generateTrojanURL() -> String {
        guard case .trojan(let trojanConfig) = protocolSettings else {
            return ""
        }
        
        var components = URLComponents()
        components.scheme = "trojan"
        components.user = trojanConfig.password
        components.host = address
        components.port = port
        
        var queryItems: [URLQueryItem] = []
        
        if let streamSettings = streamSettings {
            if let security = streamSettings.security {
                queryItems.append(URLQueryItem(name: "security", value: security))
            }
            
            if let sni = streamSettings.tlsSettings?.serverName {
                queryItems.append(URLQueryItem(name: "sni", value: sni))
            }
            
            if let alpn = streamSettings.tlsSettings?.alpn {
                queryItems.append(URLQueryItem(name: "alpn", value: alpn.joined(separator: ",")))
            }
        }
        
        queryItems.append(URLQueryItem(name: "#", value: name))
        components.queryItems = queryItems
        
        return components.url?.absoluteString ?? ""
    }
    
    private func generateShadowsocksURL() -> String {
        guard case .shadowsocks(let ssConfig) = protocolSettings else {
            return ""
        }
        
        let userInfo = "\(ssConfig.method):\(ssConfig.password)"
        guard let encodedUserInfo = userInfo.data(using: .utf8)?.base64EncodedString() else {
            return ""
        }
        
        return "ss://\(encodedUserInfo)@\(address):\(port)#\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)"
    }
}

// MARK: - 延迟状态
enum PingStatus {
    case unknown
    case timeout
    case excellent  // < 100ms
    case good       // 100-300ms
    case fair       // 300-500ms
    case poor       // > 500ms
    
    var displayName: String {
        switch self {
        case .unknown: return "未知"
        case .timeout: return "超时"
        case .excellent: return "优秀"
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "较差"
        }
    }
    
    var color: NSColor {
        switch self {
        case .unknown: return .systemGray
        case .timeout: return .systemRed
        case .excellent: return .systemGreen
        case .good: return .systemYellow
        case .fair: return .systemOrange
        case .poor: return .systemRed
        }
    }
    
    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .timeout: return "xmark.circle"
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "minus.circle"
        case .poor: return "exclamationmark.circle"
        }
    }
}

// MARK: - 服务器配置错误
enum ServerConfigError: LocalizedError {
    case invalidAddress
    case invalidPort
    case invalidProtocolSettings
    case invalidStreamSettings
    case duplicateName
    
    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "无效的服务器地址"
        case .invalidPort:
            return "无效的端口号"
        case .invalidProtocolSettings:
            return "无效的协议设置"
        case .invalidStreamSettings:
            return "无效的传输设置"
        case .duplicateName:
            return "服务器名称重复"
        }
    }
}

// MARK: - 扩展
extension ServerConfig {
    /// 从URL创建服务器配置
    static func fromURL(_ url: String) throws -> ServerConfig {
        guard let url = URL(string: url) else {
            throw ServerConfigError.invalidAddress
        }
        
        switch url.scheme?.lowercased() {
        case "vmess":
            return try parseVMessURL(url)
        case "vless":
            return try parseVLESSURL(url)
        case "trojan":
            return try parseTrojanURL(url)
        case "ss":
            return try parseShadowsocksURL(url)
        default:
            throw ServerConfigError.invalidProtocolSettings
        }
    }
    
    private static func parseVMessURL(_ url: URL) throws -> ServerConfig {
        // 实现VMess URL解析
        // ...
        throw ServerConfigError.invalidProtocolSettings
    }
    
    private static func parseVLESSURL(_ url: URL) throws -> ServerConfig {
        // 实现VLESS URL解析
        // ...
        throw ServerConfigError.invalidProtocolSettings
    }
    
    private static func parseTrojanURL(_ url: URL) throws -> ServerConfig {
        // 实现Trojan URL解析
        // ...
        throw ServerConfigError.invalidProtocolSettings
    }
    
    private static func parseShadowsocksURL(_ url: URL) throws -> ServerConfig {
        // 实现Shadowsocks URL解析
        // ...
        throw ServerConfigError.invalidProtocolSettings
    }
}
```

### 3. Subscription.swift

**文件路径**: `V2rayU/Models/Subscription.swift`

**功能描述**: 订阅管理的数据模型，支持自动更新和服务器同步。

```swift
import Foundation

/// 订阅模型
struct Subscription: Codable, Identifiable, Equatable {
    // MARK: - 基础属性
    let id: UUID
    var name: String
    var url: String
    var isEnabled: Bool
    var autoUpdate: Bool
    var updateInterval: TimeInterval // 秒
    
    // MARK: - 元数据
    var remarks: String?
    var groupName: String?
    var userAgent: String?
    var customHeaders: [String: String]?
    
    // MARK: - 状态信息
    var lastUpdateTime: Date?
    var lastSuccessTime: Date?
    var lastErrorMessage: String?
    var updateCount: Int
    var serverCount: Int
    var activeServerCount: Int
    
    // MARK: - 时间戳
    let createdAt: Date
    var updatedAt: Date
    
    // MARK: - 统计信息
    var totalTraffic: UInt64
    var usedTraffic: UInt64
    var expiryDate: Date?
    
    // MARK: - 初始化
    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        isEnabled: Bool = true,
        autoUpdate: Bool = true,
        updateInterval: TimeInterval = 3600, // 1小时
        remarks: String? = nil,
        groupName: String? = nil,
        userAgent: String? = nil,
        customHeaders: [String: String]? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
        self.autoUpdate = autoUpdate
        self.updateInterval = updateInterval
        self.remarks = remarks
        self.groupName = groupName
        self.userAgent = userAgent
        self.customHeaders = customHeaders
        
        // 状态信息
        self.lastUpdateTime = nil
        self.lastSuccessTime = nil
        self.lastErrorMessage = nil
        self.updateCount = 0
        self.serverCount = 0
        self.activeServerCount = 0
        
        // 时间戳
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // 统计信息
        self.totalTraffic = 0
        self.usedTraffic = 0
        self.expiryDate = nil
    }
    
    // MARK: - 计算属性
    
    /// 更新状态
    var updateStatus: UpdateStatus {
        if let lastError = lastErrorMessage, !lastError.isEmpty {
            return .failed(lastError)
        }
        
        if let lastUpdate = lastUpdateTime {
            let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
            if timeSinceUpdate < updateInterval {
                return .upToDate
            } else {
                return .needsUpdate
            }
        }
        
        return .neverUpdated
    }
    
    /// 下次更新时间
    var nextUpdateTime: Date? {
        guard autoUpdate, let lastUpdate = lastUpdateTime else {
            return nil
        }
        return lastUpdate.addingTimeInterval(updateInterval)
    }
    
    /// 是否需要更新
    var needsUpdate: Bool {
        guard isEnabled && autoUpdate else {
            return false
        }
        
        guard let lastUpdate = lastUpdateTime else {
            return true
        }
        
        return Date().timeIntervalSince(lastUpdate) >= updateInterval
    }
    
    /// 流量使用率
    var trafficUsageRatio: Double {
        guard totalTraffic > 0 else {
            return 0
        }
        return Double(usedTraffic) / Double(totalTraffic)
    }
    
    /// 是否已过期
    var isExpired: Bool {
        guard let expiryDate = expiryDate else {
            return false
        }
        return Date() > expiryDate
    }
    
    /// 剩余天数
    var remainingDays: Int? {
        guard let expiryDate = expiryDate else {
            return nil
        }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expiryDate)
        return components.day
    }
    
    // MARK: - 方法
    
    /// 更新成功
    mutating func updateSucceeded(serverCount: Int) {
        self.lastUpdateTime = Date()
        self.lastSuccessTime = Date()
        self.lastErrorMessage = nil
        self.updateCount += 1
        self.serverCount = serverCount
        self.updatedAt = Date()
    }
    
    /// 更新失败
    mutating func updateFailed(error: String) {
        self.lastUpdateTime = Date()
        self.lastErrorMessage = error
        self.updatedAt = Date()
    }
    
    /// 更新服务器统计
    mutating func updateServerStats(total: Int, active: Int) {
        self.serverCount = total
        self.activeServerCount = active
        self.updatedAt = Date()
    }
    
    /// 更新流量信息
    mutating func updateTrafficInfo(total: UInt64, used: UInt64, expiry: Date?) {
        self.totalTraffic = total
        self.usedTraffic = used
        self.expiryDate = expiry
        self.updatedAt = Date()
    }
    
    /// 验证订阅配置
    func validate() throws {
        // 验证名称
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SubscriptionError.invalidName
        }
        
        // 验证URL
        guard let url = URL(string: url), url.scheme != nil else {
            throw SubscriptionError.invalidURL
        }
        
        // 验证更新间隔
        if updateInterval < 300 { // 最少5分钟
            throw SubscriptionError.invalidUpdateInterval
        }
    }
    
    /// 获取请求头
    func getRequestHeaders() -> [String: String] {
        var headers: [String: String] = [:]
        
        // 默认User-Agent
        headers["User-Agent"] = userAgent ?? "V2rayU/1.0"
        
        // 自定义头部
        if let customHeaders = customHeaders {
            headers.merge(customHeaders) { _, new in new }
        }
        
        return headers
    }
    
    /// 克隆订阅
    func clone() -> Subscription {
        var cloned = self
        cloned.id = UUID()
        cloned.name = "\(name) (Copy)"
        cloned.lastUpdateTime = nil
        cloned.lastSuccessTime = nil
        cloned.lastErrorMessage = nil
        cloned.updateCount = 0
        cloned.serverCount = 0
        cloned.activeServerCount = 0
        cloned.createdAt = Date()
        cloned.updatedAt = Date()
        return cloned
    }
}

// MARK: - 更新状态
enum UpdateStatus {
    case neverUpdated
    case upToDate
    case needsUpdate
    case updating
    case failed(String)
    
    var displayName: String {
        switch self {
        case .neverUpdated:
            return "从未更新"
        case .upToDate:
            return "已是最新"
        case .needsUpdate:
            return "需要更新"
        case .updating:
            return "更新中"
        case .failed(let error):
            return "更新失败: \(error)"
        }
    }
    
    var color: NSColor {
        switch self {
        case .neverUpdated:
            return .systemGray
        case .upToDate:
            return .systemGreen
        case .needsUpdate:
            return .systemYellow
        case .updating:
            return .systemBlue
        case .failed:
            return .systemRed
        }
    }
    
    var icon: String {
        switch self {
        case .neverUpdated:
            return "questionmark.circle"
        case .upToDate:
            return "checkmark.circle.fill"
        case .needsUpdate:
            return "arrow.clockwise.circle"
        case .updating:
            return "arrow.clockwise.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
}

// MARK: - 订阅错误
enum SubscriptionError: LocalizedError {
    case invalidName
    case invalidURL
    case invalidUpdateInterval
    case networkError(Error)
    case parseError(String)
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "无效的订阅名称"
        case .invalidURL:
            return "无效的订阅URL"
        case .invalidUpdateInterval:
            return "无效的更新间隔"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .parseError(let message):
            return "解析错误: \(message)"
        case .serverError(let code):
            return "服务器错误: \(code)"
        }
    }
}

// MARK: - 订阅分组
struct SubscriptionGroup: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var subscriptions: [UUID] // 订阅ID列表
    var isExpanded: Bool
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        subscriptions: [UUID] = [],
        isExpanded: Bool = true
    ) {
        self.id = id
        self.name = name
        self.subscriptions = subscriptions
        self.isExpanded = isExpanded
        
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
    
    mutating func addSubscription(_ subscriptionID: UUID) {
        if !subscriptions.contains(subscriptionID) {
            subscriptions.append(subscriptionID)
            updatedAt = Date()
        }
    }
    
    mutating func removeSubscription(_ subscriptionID: UUID) {
        subscriptions.removeAll { $0 == subscriptionID }
        updatedAt = Date()
    }
}

// MARK: - 扩展
extension Subscription {
    /// 预定义的更新间隔
    static let updateIntervals: [TimeInterval] = [
        300,    // 5分钟
        900,    // 15分钟
        1800,   // 30分钟
        3600,   // 1小时
        7200,   // 2小时
        21600,  // 6小时
        43200,  // 12小时
        86400,  // 24小时
        604800  // 7天
    ]
    
    /// 获取更新间隔的显示名称
    static func displayName(for interval: TimeInterval) -> String {
        switch interval {
        case 300: return "5分钟"
        case 900: return "15分钟"
        case 1800: return "30分钟"
        case 3600: return "1小时"
        case 7200: return "2小时"
        case 21600: return "6小时"
        case 43200: return "12小时"
        case 86400: return "24小时"
        case 604800: return "7天"
        default: return "\(Int(interval / 60))分钟"
        }
    }
}
```

## 🔧 模型关系图

```
V2rayConfig (V2ray配置)
    ├── InboundConfig[] (入站配置)
    ├── OutboundConfig[] (出站配置)
    ├── RoutingConfig (路由配置)
    └── DNSConfig (DNS配置)

ServerConfig (服务器配置)
    ├── ProtocolSettings (协议设置)
    ├── StreamSettings (传输设置)
    ├── MuxConfig (多路复用)
    └── Subscription (所属订阅)

Subscription (订阅)
    ├── ServerConfig[] (服务器列表)
    ├── SubscriptionGroup (分组)
    └── UpdateStatus (更新状态)

AppSettings (应用设置)
    ├── ProxySettings (代理设置)
    ├── UISettings (界面设置)
    └── SecuritySettings (安全设置)
```

## 📚 最佳实践

### 1. 数据模型设计
- **不可变性**: 优先使用不可变数据结构
- **类型安全**: 使用强类型和枚举
- **验证机制**: 内置数据验证方法
- **版本兼容**: 支持配置迁移和向后兼容

### 2. 序列化处理
- **JSON编码**: 使用Codable协议
- **错误处理**: 优雅处理解析错误
- **默认值**: 为可选字段提供合理默认值
- **格式化**: 保持JSON格式的可读性

### 3. 性能优化
- **懒加载**: 按需加载大型数据结构
- **缓存策略**: 缓存频繁访问的计算属性
- **批量操作**: 优化大量数据的处理
- **内存管理**: 及时释放不需要的数据

### 4. 扩展性考虑
- **协议支持**: 易于添加新的代理协议
- **配置选项**: 灵活的配置参数系统
- **插件架构**: 支持功能扩展
- **API兼容**: 保持API的稳定性

数据模型是应用的核心基础，良好的模型设计能够提高代码的可维护性、可扩展性和性能。
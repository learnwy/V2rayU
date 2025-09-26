# 路由规则功能详解

## 📋 概述

路由规则功能是V2rayU的核心特性之一，提供灵活的流量分流和路由控制能力。该功能允许用户根据域名、IP地址、端口、协议等条件，将不同的网络流量路由到不同的代理服务器或直连，实现精细化的网络访问控制。

## 🎯 功能特性

### 1. 规则类型
- **域名规则**: 基于域名匹配的路由规则
- **IP规则**: 基于IP地址和CIDR的路由规则
- **端口规则**: 基于端口号的路由规则
- **协议规则**: 基于协议类型的路由规则
- **地理位置规则**: 基于GeoIP的路由规则
- **进程规则**: 基于应用程序的路由规则

### 2. 匹配模式
- ✅ 精确匹配
- ✅ 通配符匹配
- ✅ 正则表达式匹配
- ✅ 关键词匹配
- ✅ 子域名匹配
- ✅ IP范围匹配

### 3. 核心功能
- ✅ 规则创建和编辑
- ✅ 规则优先级管理
- ✅ 规则分组和标签
- ✅ 规则导入导出
- ✅ 规则模板管理
- ✅ 实时规则匹配
- ✅ 规则统计分析
- ✅ 规则测试验证

## 🏗️ 架构设计

### 1. 组件关系图

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ RoutingRuleView │────│RoutingHandler  │────│   RuleEngine    │
│   (UI Layer)    │    │(Business Logic) │    │ (Rule Matcher)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ RuleEditorView  │    │ RuleRepository  │    │ DomainMatcher   │
│ RuleListView    │    │ RuleValidator   │    │ IPMatcher       │
│ RuleTestView    │    │ RuleImporter    │    │ PortMatcher     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 2. 规则匹配流程

```
网络请求 → 规则引擎 → 规则匹配 → 动作执行 → 流量路由
    ↓           ↓           ↓           ↓           ↓
目标解析 → 规则遍历 → 条件判断 → 代理选择 → 连接建立
```

## 💻 核心实现

### 1. 路由规则数据模型

```swift
// MARK: - 路由规则
struct RoutingRule: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var description: String
    var isEnabled: Bool
    var priority: Int
    var conditions: [RuleCondition]
    var action: RuleAction
    var tags: [String]
    var groupName: String?
    var createdAt: Date
    var updatedAt: Date
    var matchCount: Int
    var lastMatchTime: Date?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        isEnabled: Bool = true,
        priority: Int = 0,
        conditions: [RuleCondition] = [],
        action: RuleAction = .direct,
        tags: [String] = [],
        groupName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        matchCount: Int = 0,
        lastMatchTime: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isEnabled = isEnabled
        self.priority = priority
        self.conditions = conditions
        self.action = action
        self.tags = tags
        self.groupName = groupName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.matchCount = matchCount
        self.lastMatchTime = lastMatchTime
    }
    
    // MARK: - 计算属性
    
    var isValid: Bool {
        return !name.isEmpty && !conditions.isEmpty
    }
    
    var formattedPriority: String {
        return "优先级 \(priority)"
    }
    
    var formattedMatchCount: String {
        if matchCount == 0 {
            return "未匹配"
        } else if matchCount < 1000 {
            return "\(matchCount)次"
        } else {
            return "\(matchCount / 1000)k次"
        }
    }
    
    var statusColor: Color {
        if !isEnabled {
            return .gray
        } else if matchCount > 0 {
            return .green
        } else {
            return .blue
        }
    }
    
    // MARK: - 匹配方法
    
    func matches(request: NetworkRequest) -> Bool {
        guard isEnabled else { return false }
        
        // 所有条件都必须匹配
        return conditions.allSatisfy { condition in
            condition.matches(request: request)
        }
    }
    
    mutating func recordMatch() {
        matchCount += 1
        lastMatchTime = Date()
        updatedAt = Date()
    }
}

// MARK: - 规则条件
struct RuleCondition: Codable, Identifiable, Equatable {
    let id: String
    var type: ConditionType
    var operator: ConditionOperator
    var value: String
    var isNegated: Bool
    var isCaseSensitive: Bool
    
    init(
        id: String = UUID().uuidString,
        type: ConditionType,
        operator: ConditionOperator,
        value: String,
        isNegated: Bool = false,
        isCaseSensitive: Bool = false
    ) {
        self.id = id
        self.type = type
        self.operator = `operator`
        self.value = value
        self.isNegated = isNegated
        self.isCaseSensitive = isCaseSensitive
    }
    
    // MARK: - 匹配方法
    
    func matches(request: NetworkRequest) -> Bool {
        let result: Bool
        
        switch type {
        case .domain:
            result = matchesDomain(request.host)
        case .ip:
            result = matchesIP(request.destinationIP)
        case .port:
            result = matchesPort(request.port)
        case .protocol:
            result = matchesProtocol(request.protocol)
        case .geoip:
            result = matchesGeoIP(request.destinationIP)
        case .process:
            result = matchesProcess(request.processName)
        case .url:
            result = matchesURL(request.url)
        case .userAgent:
            result = matchesUserAgent(request.userAgent)
        }
        
        return isNegated ? !result : result
    }
    
    // MARK: - 私有匹配方法
    
    private func matchesDomain(_ domain: String?) -> Bool {
        guard let domain = domain else { return false }
        
        let targetDomain = isCaseSensitive ? domain : domain.lowercased()
        let ruleValue = isCaseSensitive ? value : value.lowercased()
        
        switch `operator` {
        case .equals:
            return targetDomain == ruleValue
        case .contains:
            return targetDomain.contains(ruleValue)
        case .startsWith:
            return targetDomain.hasPrefix(ruleValue)
        case .endsWith:
            return targetDomain.hasSuffix(ruleValue)
        case .regex:
            return targetDomain.range(of: ruleValue, options: .regularExpression) != nil
        case .wildcard:
            return matchesWildcard(targetDomain, pattern: ruleValue)
        case .subdomain:
            return targetDomain == ruleValue || targetDomain.hasSuffix(".\(ruleValue)")
        }
    }
    
    private func matchesIP(_ ip: String?) -> Bool {
        guard let ip = ip else { return false }
        
        switch `operator` {
        case .equals:
            return ip == value
        case .contains:
            return ip.contains(value)
        case .cidr:
            return matchesCIDR(ip, cidr: value)
        case .range:
            return matchesIPRange(ip, range: value)
        default:
            return false
        }
    }
    
    private func matchesPort(_ port: Int) -> Bool {
        switch `operator` {
        case .equals:
            return port == Int(value)
        case .range:
            return matchesPortRange(port, range: value)
        case .greaterThan:
            return port > (Int(value) ?? 0)
        case .lessThan:
            return port < (Int(value) ?? 65535)
        default:
            return false
        }
    }
    
    private func matchesProtocol(_ protocol: String?) -> Bool {
        guard let protocol = protocol else { return false }
        return protocol.lowercased() == value.lowercased()
    }
    
    private func matchesGeoIP(_ ip: String?) -> Bool {
        guard let ip = ip else { return false }
        // 实现GeoIP匹配逻辑
        return GeoIPDatabase.shared.getCountryCode(for: ip) == value.uppercased()
    }
    
    private func matchesProcess(_ processName: String?) -> Bool {
        guard let processName = processName else { return false }
        
        let targetProcess = isCaseSensitive ? processName : processName.lowercased()
        let ruleValue = isCaseSensitive ? value : value.lowercased()
        
        switch `operator` {
        case .equals:
            return targetProcess == ruleValue
        case .contains:
            return targetProcess.contains(ruleValue)
        case .startsWith:
            return targetProcess.hasPrefix(ruleValue)
        case .endsWith:
            return targetProcess.hasSuffix(ruleValue)
        default:
            return false
        }
    }
    
    private func matchesURL(_ url: String?) -> Bool {
        guard let url = url else { return false }
        return matchesDomain(url) // 简化实现
    }
    
    private func matchesUserAgent(_ userAgent: String?) -> Bool {
        guard let userAgent = userAgent else { return false }
        return matchesDomain(userAgent) // 简化实现
    }
    
    // MARK: - 辅助方法
    
    private func matchesWildcard(_ text: String, pattern: String) -> Bool {
        let regex = pattern
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")
        
        return text.range(of: "^\(regex)$", options: .regularExpression) != nil
    }
    
    private func matchesCIDR(_ ip: String, cidr: String) -> Bool {
        // 实现CIDR匹配逻辑
        let components = cidr.split(separator: "/")
        guard components.count == 2,
              let network = String(components[0]).ipToUInt32(),
              let prefixLength = Int(components[1]),
              let targetIP = ip.ipToUInt32() else {
            return false
        }
        
        let mask = UInt32.max << (32 - prefixLength)
        return (network & mask) == (targetIP & mask)
    }
    
    private func matchesIPRange(_ ip: String, range: String) -> Bool {
        let components = range.split(separator: "-")
        guard components.count == 2,
              let startIP = String(components[0]).ipToUInt32(),
              let endIP = String(components[1]).ipToUInt32(),
              let targetIP = ip.ipToUInt32() else {
            return false
        }
        
        return targetIP >= startIP && targetIP <= endIP
    }
    
    private func matchesPortRange(_ port: Int, range: String) -> Bool {
        let components = range.split(separator: "-")
        guard components.count == 2,
              let startPort = Int(components[0]),
              let endPort = Int(components[1]) else {
            return false
        }
        
        return port >= startPort && port <= endPort
    }
}

// MARK: - 条件类型
enum ConditionType: String, CaseIterable, Codable {
    case domain = "domain"
    case ip = "ip"
    case port = "port"
    case protocol = "protocol"
    case geoip = "geoip"
    case process = "process"
    case url = "url"
    case userAgent = "userAgent"
    
    var displayName: String {
        switch self {
        case .domain: return "域名"
        case .ip: return "IP地址"
        case .port: return "端口"
        case .protocol: return "协议"
        case .geoip: return "地理位置"
        case .process: return "进程"
        case .url: return "URL"
        case .userAgent: return "User-Agent"
        }
    }
    
    var supportedOperators: [ConditionOperator] {
        switch self {
        case .domain:
            return [.equals, .contains, .startsWith, .endsWith, .regex, .wildcard, .subdomain]
        case .ip:
            return [.equals, .contains, .cidr, .range]
        case .port:
            return [.equals, .range, .greaterThan, .lessThan]
        case .protocol:
            return [.equals]
        case .geoip:
            return [.equals]
        case .process:
            return [.equals, .contains, .startsWith, .endsWith]
        case .url:
            return [.equals, .contains, .startsWith, .endsWith, .regex]
        case .userAgent:
            return [.equals, .contains, .startsWith, .endsWith]
        }
    }
}

// MARK: - 条件操作符
enum ConditionOperator: String, CaseIterable, Codable {
    case equals = "equals"
    case contains = "contains"
    case startsWith = "startsWith"
    case endsWith = "endsWith"
    case regex = "regex"
    case wildcard = "wildcard"
    case subdomain = "subdomain"
    case cidr = "cidr"
    case range = "range"
    case greaterThan = "greaterThan"
    case lessThan = "lessThan"
    
    var displayName: String {
        switch self {
        case .equals: return "等于"
        case .contains: return "包含"
        case .startsWith: return "开始于"
        case .endsWith: return "结束于"
        case .regex: return "正则表达式"
        case .wildcard: return "通配符"
        case .subdomain: return "子域名"
        case .cidr: return "CIDR"
        case .range: return "范围"
        case .greaterThan: return "大于"
        case .lessThan: return "小于"
        }
    }
    
    var symbol: String {
        switch self {
        case .equals: return "="
        case .contains: return "⊃"
        case .startsWith: return "^*"
        case .endsWith: return "*$"
        case .regex: return ".*"
        case .wildcard: return "*"
        case .subdomain: return ".*."
        case .cidr: return "/"
        case .range: return "-"
        case .greaterThan: return ">"
        case .lessThan: return "<"
        }
    }
}

// MARK: - 规则动作
enum RuleAction: Codable, Equatable {
    case direct
    case proxy(String) // proxyID
    case block
    case reject
    case group(String) // groupName
    
    var displayName: String {
        switch self {
        case .direct:
            return "直连"
        case .proxy(let proxyID):
            return "代理: \(proxyID)"
        case .block:
            return "阻止"
        case .reject:
            return "拒绝"
        case .group(let groupName):
            return "分组: \(groupName)"
        }
    }
    
    var actionType: ActionType {
        switch self {
        case .direct: return .direct
        case .proxy: return .proxy
        case .block: return .block
        case .reject: return .reject
        case .group: return .group
        }
    }
    
    var color: Color {
        switch self {
        case .direct: return .green
        case .proxy: return .blue
        case .block: return .red
        case .reject: return .orange
        case .group: return .purple
        }
    }
}

// MARK: - 动作类型
enum ActionType: String, CaseIterable {
    case direct = "direct"
    case proxy = "proxy"
    case block = "block"
    case reject = "reject"
    case group = "group"
    
    var displayName: String {
        switch self {
        case .direct: return "直连"
        case .proxy: return "代理"
        case .block: return "阻止"
        case .reject: return "拒绝"
        case .group: return "分组"
        }
    }
}

// MARK: - 网络请求
struct NetworkRequest {
    let host: String?
    let destinationIP: String?
    let port: Int
    let protocol: String?
    let processName: String?
    let url: String?
    let userAgent: String?
    let timestamp: Date
    
    init(
        host: String? = nil,
        destinationIP: String? = nil,
        port: Int = 80,
        protocol: String? = nil,
        processName: String? = nil,
        url: String? = nil,
        userAgent: String? = nil,
        timestamp: Date = Date()
    ) {
        self.host = host
        self.destinationIP = destinationIP
        self.port = port
        self.protocol = `protocol`
        self.processName = processName
        self.url = url
        self.userAgent = userAgent
        self.timestamp = timestamp
    }
}
```

### 2. 规则引擎实现

```swift
// MARK: - 规则引擎协议
protocol RuleEngineProtocol {
    func matchRule(for request: NetworkRequest) async -> RoutingRule?
    func addRule(_ rule: RoutingRule) async throws
    func updateRule(_ rule: RoutingRule) async throws
    func removeRule(id: String) async throws
    func getAllRules() async -> [RoutingRule]
    func testRule(_ rule: RoutingRule, against request: NetworkRequest) -> Bool
}

// MARK: - 规则引擎实现
class RuleEngine: RuleEngineProtocol, ObservableObject {
    private let logger = Logger(subsystem: "V2rayU", category: "RuleEngine")
    private let repository: RoutingRuleRepository
    
    @Published var rules: [RoutingRule] = []
    @Published var isEnabled = true
    @Published var matchStatistics: [String: Int] = [:] // ruleID -> matchCount
    
    private var sortedRules: [RoutingRule] = []
    private let ruleQueue = DispatchQueue(label: "rule.engine.queue", qos: .userInitiated)
    
    init(repository: RoutingRuleRepository) {
        self.repository = repository
        
        Task {
            await loadRules()
        }
    }
    
    // MARK: - 公共方法
    
    /// 匹配规则
    func matchRule(for request: NetworkRequest) async -> RoutingRule? {
        guard isEnabled else { return nil }
        
        return await withCheckedContinuation { continuation in
            ruleQueue.async {
                // 按优先级遍历规则
                for rule in self.sortedRules {
                    if rule.matches(request: request) {
                        // 记录匹配
                        Task { @MainActor in
                            self.recordRuleMatch(rule.id)
                        }
                        
                        self.logger.info("规则匹配: \(rule.name) -> \(rule.action.displayName)")
                        continuation.resume(returning: rule)
                        return
                    }
                }
                
                // 没有匹配的规则
                continuation.resume(returning: nil)
            }
        }
    }
    
    /// 添加规则
    func addRule(_ rule: RoutingRule) async throws {
        try await repository.saveRule(rule)
        
        await MainActor.run {
            self.rules.append(rule)
            self.updateSortedRules()
        }
        
        logger.info("规则已添加: \(rule.name)")
    }
    
    /// 更新规则
    func updateRule(_ rule: RoutingRule) async throws {
        var updatedRule = rule
        updatedRule.updatedAt = Date()
        
        try await repository.updateRule(updatedRule)
        
        await MainActor.run {
            if let index = self.rules.firstIndex(where: { $0.id == rule.id }) {
                self.rules[index] = updatedRule
                self.updateSortedRules()
            }
        }
        
        logger.info("规则已更新: \(rule.name)")
    }
    
    /// 删除规则
    func removeRule(id: String) async throws {
        try await repository.deleteRule(id: id)
        
        await MainActor.run {
            self.rules.removeAll { $0.id == id }
            self.updateSortedRules()
            self.matchStatistics.removeValue(forKey: id)
        }
        
        logger.info("规则已删除: \(id)")
    }
    
    /// 获取所有规则
    func getAllRules() async -> [RoutingRule] {
        return await MainActor.run {
            return self.rules
        }
    }
    
    /// 测试规则
    func testRule(_ rule: RoutingRule, against request: NetworkRequest) -> Bool {
        return rule.matches(request: request)
    }
    
    /// 批量导入规则
    func importRules(_ rules: [RoutingRule]) async throws {
        for rule in rules {
            try await repository.saveRule(rule)
        }
        
        await MainActor.run {
            self.rules.append(contentsOf: rules)
            self.updateSortedRules()
        }
        
        logger.info("批量导入规则: \(rules.count)个")
    }
    
    /// 导出规则
    func exportRules(ids: [String]? = nil) async -> [RoutingRule] {
        let allRules = await getAllRules()
        
        if let ids = ids {
            return allRules.filter { ids.contains($0.id) }
        } else {
            return allRules
        }
    }
    
    /// 重新排序规则
    func reorderRules(_ rules: [RoutingRule]) async throws {
        var updatedRules: [RoutingRule] = []
        
        for (index, rule) in rules.enumerated() {
            var updatedRule = rule
            updatedRule.priority = index
            updatedRule.updatedAt = Date()
            
            try await repository.updateRule(updatedRule)
            updatedRules.append(updatedRule)
        }
        
        await MainActor.run {
            self.rules = updatedRules
            self.updateSortedRules()
        }
        
        logger.info("规则顺序已更新")
    }
    
    /// 启用/禁用规则
    func toggleRule(id: String) async throws {
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            throw RoutingRuleError.ruleNotFound
        }
        
        var rule = rules[index]
        rule.isEnabled.toggle()
        rule.updatedAt = Date()
        
        try await updateRule(rule)
        
        logger.info("规则状态已切换: \(rule.name) -> \(rule.isEnabled ? "启用" : "禁用")")
    }
    
    // MARK: - 私有方法
    
    private func loadRules() async {
        do {
            let loadedRules = try await repository.getAllRules()
            
            await MainActor.run {
                self.rules = loadedRules
                self.updateSortedRules()
                
                // 加载统计数据
                for rule in loadedRules {
                    self.matchStatistics[rule.id] = rule.matchCount
                }
            }
            
            logger.info("规则加载完成: \(loadedRules.count)个")
        } catch {
            logger.error("规则加载失败: \(error)")
        }
    }
    
    private func updateSortedRules() {
        sortedRules = rules
            .filter { $0.isEnabled }
            .sorted { $0.priority < $1.priority }
    }
    
    private func recordRuleMatch(_ ruleID: String) {
        matchStatistics[ruleID, default: 0] += 1
        
        // 更新规则的匹配计数
        if let index = rules.firstIndex(where: { $0.id == ruleID }) {
            rules[index].recordMatch()
            
            // 异步保存到数据库
            Task {
                do {
                    try await repository.updateRule(rules[index])
                } catch {
                    logger.error("更新规则匹配计数失败: \(error)")
                }
            }
        }
    }
}

// MARK: - GeoIP数据库
class GeoIPDatabase {
    static let shared = GeoIPDatabase()
    
    private let logger = Logger(subsystem: "V2rayU", category: "GeoIPDatabase")
    private var countryData: [String: String] = [:] // IP -> CountryCode
    
    private init() {
        loadGeoIPData()
    }
    
    func getCountryCode(for ip: String) -> String? {
        // 简化实现，实际应该使用GeoIP数据库
        return countryData[ip] ?? detectCountryByIP(ip)
    }
    
    private func loadGeoIPData() {
        // 加载GeoIP数据库
        // 这里使用简化的实现
        countryData = [
            "8.8.8.8": "US",
            "1.1.1.1": "US",
            "114.114.114.114": "CN",
            "223.5.5.5": "CN"
        ]
    }
    
    private func detectCountryByIP(_ ip: String) -> String? {
        // 简化的IP地理位置检测
        if ip.hasPrefix("192.168.") || ip.hasPrefix("10.") || ip.hasPrefix("172.") {
            return "LOCAL"
        }
        
        // 默认返回未知
        return "UNKNOWN"
    }
}

// MARK: - String扩展
extension String {
    func ipToUInt32() -> UInt32? {
        let components = self.split(separator: ".").compactMap { UInt32($0) }
        guard components.count == 4,
              components.allSatisfy({ $0 <= 255 }) else {
            return nil
        }
        
        return (components[0] << 24) + (components[1] << 16) + (components[2] << 8) + components[3]
    }
}
```

### 3. 路由规则处理器实现

```swift
// MARK: - 路由规则处理器
@MainActor
class RoutingRuleHandler: AsyncHandler {
    private let ruleEngine: RuleEngineProtocol
    private let repository: RoutingRuleRepository
    private let proxyRepository: ProxyRepository
    
    @Published var rules: [RoutingRule] = []
    @Published var selectedRules: Set<String> = []
    @Published var searchText = ""
    @Published var filterGroup: String? = nil
    @Published var filterAction: ActionType? = nil
    @Published var sortOrder: RuleSortOrder = .priority
    @Published var groups: [String] = []
    @Published var ruleTemplates: [RuleTemplate] = []
    
    init(
        ruleEngine: RuleEngineProtocol,
        repository: RoutingRuleRepository,
        proxyRepository: ProxyRepository
    ) {
        self.ruleEngine = ruleEngine
        self.repository = repository
        self.proxyRepository = proxyRepository
        super.init()
        
        loadRuleTemplates()
    }
    
    // MARK: - 公共方法
    
    /// 加载所有规则
    func loadRules() async {
        await performAsyncOperation {
            let loadedRules = await self.ruleEngine.getAllRules()
            
            await MainActor.run {
                self.rules = loadedRules
                self.updateGroups()
            }
            
            self.logger.info("规则加载完成: \(loadedRules.count)个")
        }
    }
    
    /// 创建新规则
    func createRule(_ rule: RoutingRule) async {
        await performAsyncOperation {
            try await self.ruleEngine.addRule(rule)
            
            await MainActor.run {
                self.rules.append(rule)
                self.updateGroups()
            }
            
            self.logger.info("规则创建成功: \(rule.name)")
        }
    }
    
    /// 更新规则
    func updateRule(_ rule: RoutingRule) async {
        await performAsyncOperation {
            try await self.ruleEngine.updateRule(rule)
            
            await MainActor.run {
                if let index = self.rules.firstIndex(where: { $0.id == rule.id }) {
                    self.rules[index] = rule
                    self.updateGroups()
                }
            }
            
            self.logger.info("规则更新成功: \(rule.name)")
        }
    }
    
    /// 删除规则
    func deleteRule(id: String) async {
        await performAsyncOperation {
            try await self.ruleEngine.removeRule(id: id)
            
            await MainActor.run {
                self.rules.removeAll { $0.id == id }
                self.selectedRules.remove(id)
                self.updateGroups()
            }
            
            self.logger.info("规则删除成功: \(id)")
        }
    }
    
    /// 批量删除规则
    func deleteSelectedRules() async {
        guard !selectedRules.isEmpty else { return }
        
        await performAsyncOperation {
            for ruleID in self.selectedRules {
                try await self.ruleEngine.removeRule(id: ruleID)
            }
            
            await MainActor.run {
                self.rules.removeAll { self.selectedRules.contains($0.id) }
                self.selectedRules.removeAll()
                self.updateGroups()
            }
            
            self.logger.info("批量删除规则成功: \(self.selectedRules.count)个")
        }
    }
    
    /// 切换规则状态
    func toggleRule(id: String) async {
        await performAsyncOperation {
            try await self.ruleEngine.toggleRule(id: id)
            
            await MainActor.run {
                if let index = self.rules.firstIndex(where: { $0.id == id }) {
                    self.rules[index].isEnabled.toggle()
                }
            }
            
            self.logger.info("规则状态切换成功: \(id)")
        }
    }
    
    /// 重新排序规则
    func reorderRules(_ newOrder: [RoutingRule]) async {
        await performAsyncOperation {
            try await self.ruleEngine.reorderRules(newOrder)
            
            await MainActor.run {
                self.rules = newOrder
            }
            
            self.logger.info("规则重新排序成功")
        }
    }
    
    /// 导入规则
    func importRules(from url: URL) async {
        await performAsyncOperation {
            let data = try Data(contentsOf: url)
            let importedRules = try JSONDecoder().decode([RoutingRule].self, from: data)
            
            try await self.ruleEngine.importRules(importedRules)
            
            await MainActor.run {
                self.rules.append(contentsOf: importedRules)
                self.updateGroups()
            }
            
            self.logger.info("规则导入成功: \(importedRules.count)个")
        }
    }
    
    /// 导出规则
    func exportRules(ids: [String]? = nil) async -> URL? {
        do {
            let rulesToExport = await ruleEngine.exportRules(ids: ids)
            let data = try JSONEncoder().encode(rulesToExport)
            
            let fileName = "routing_rules_\(Date().timeIntervalSince1970).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: url)
            
            logger.info("规则导出成功: \(url.path)")
            return url
        } catch {
            await MainActor.run {
                self.error = error
            }
            logger.error("规则导出失败: \(error)")
            return nil
        }
    }
    
    /// 测试规则
    func testRule(_ rule: RoutingRule, with testData: NetworkRequest) -> Bool {
        return ruleEngine.testRule(rule, against: testData)
    }
    
    /// 从模板创建规则
    func createRuleFromTemplate(_ template: RuleTemplate) -> RoutingRule {
        return RoutingRule(
            name: template.name,
            description: template.description,
            conditions: template.conditions,
            action: template.action,
            tags: template.tags,
            groupName: template.groupName
        )
    }
    
    /// 获取过滤后的规则
    func getFilteredRules() -> [RoutingRule] {
        var filteredRules = rules
        
        // 搜索过滤
        if !searchText.isEmpty {
            filteredRules = filteredRules.filter { rule in
                rule.name.localizedCaseInsensitiveContains(searchText) ||
                rule.description.localizedCaseInsensitiveContains(searchText) ||
                rule.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // 分组过滤
        if let filterGroup = filterGroup {
            filteredRules = filteredRules.filter { $0.groupName == filterGroup }
        }
        
        // 动作过滤
        if let filterAction = filterAction {
            filteredRules = filteredRules.filter { $0.action.actionType == filterAction }
        }
        
        // 排序
        switch sortOrder {
        case .priority:
            filteredRules.sort { $0.priority < $1.priority }
        case .name:
            filteredRules.sort { $0.name < $1.name }
        case .createdAt:
            filteredRules.sort { $0.createdAt > $1.createdAt }
        case .updatedAt:
            filteredRules.sort { $0.updatedAt > $1.updatedAt }
        case .matchCount:
            filteredRules.sort { $0.matchCount > $1.matchCount }
        }
        
        return filteredRules
    }
    
    // MARK: - 私有方法
    
    private func updateGroups() {
        let uniqueGroups = Set(rules.compactMap { $0.groupName })
        groups = Array(uniqueGroups).sorted()
    }
    
    private func loadRuleTemplates() {
        ruleTemplates = [
            RuleTemplate(
                name: "国内直连",
                description: "中国大陆网站直接连接",
                conditions: [
                    RuleCondition(type: .geoip, operator: .equals, value: "CN")
                ],
                action: .direct,
                tags: ["国内", "直连"],
                groupName: "地理位置"
            ),
            RuleTemplate(
                name: "广告拦截",
                description: "拦截广告域名",
                conditions: [
                    RuleCondition(type: .domain, operator: .contains, value: "ads"),
                    RuleCondition(type: .domain, operator: .contains, value: "analytics")
                ],
                action: .block,
                tags: ["广告", "拦截"],
                groupName: "安全"
            ),
            RuleTemplate(
                name: "流媒体代理",
                description: "流媒体网站使用代理",
                conditions: [
                    RuleCondition(type: .domain, operator: .contains, value: "netflix"),
                    RuleCondition(type: .domain, operator: .contains, value: "youtube")
                ],
                action: .proxy("default"),
                tags: ["流媒体", "代理"],
                groupName: "娱乐"
            )
        ]
    }
}

// MARK: - 规则模板
struct RuleTemplate: Codable, Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let conditions: [RuleCondition]
    let action: RuleAction
    let tags: [String]
    let groupName: String?
    
    init(
        name: String,
        description: String,
        conditions: [RuleCondition],
        action: RuleAction,
        tags: [String] = [],
        groupName: String? = nil
    ) {
        self.name = name
        self.description = description
        self.conditions = conditions
        self.action = action
        self.tags = tags
        self.groupName = groupName
    }
}

// MARK: - 排序选项
enum RuleSortOrder: String, CaseIterable {
    case priority = "priority"
    case name = "name"
    case createdAt = "createdAt"
    case updatedAt = "updatedAt"
    case matchCount = "matchCount"
    
    var displayName: String {
        switch self {
        case .priority: return "优先级"
        case .name: return "名称"
        case .createdAt: return "创建时间"
        case .updatedAt: return "更新时间"
        case .matchCount: return "匹配次数"
        }
    }
}

// MARK: - 路由规则错误
enum RoutingRuleError: LocalizedError {
    case ruleNotFound
    case invalidCondition
    case invalidAction
    case duplicateRule
    case importError(String)
    case exportError(String)
    
    var errorDescription: String? {
        switch self {
        case .ruleNotFound:
            return "规则未找到"
        case .invalidCondition:
            return "无效的规则条件"
        case .invalidAction:
            return "无效的规则动作"
        case .duplicateRule:
            return "重复的规则"
        case .importError(let reason):
            return "导入失败: \(reason)"
        case .exportError(let reason):
            return "导出失败: \(reason)"
        }
    }
}
```

### 4. 用户界面实现

```swift
// MARK: - 路由规则主视图
struct RoutingRuleView: View {
    @StateObject private var handler = HandlerManager.shared.routingRuleHandler
    @State private var showingRuleEditor = false
    @State private var showingImportSheet = false
    @State private var editingRule: RoutingRule?
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            RuleToolbarView(handler: handler) {
                showingRuleEditor = true
            }
            
            // 过滤器
            RuleFilterView(handler: handler)
            
            // 规则列表
            RuleListView(handler: handler) { rule in
                editingRule = rule
                showingRuleEditor = true
            }
        }
        .navigationTitle("路由规则")
        .sheet(isPresented: $showingRuleEditor) {
            RuleEditorView(
                rule: editingRule,
                handler: handler
            ) {
                editingRule = nil
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            RuleImportView(handler: handler)
        }
        .task {
            await handler.loadRules()
        }
    }
}

// MARK: - 规则工具栏
struct RuleToolbarView: View {
    @ObservedObject var handler: RoutingRuleHandler
    let onAddRule: () -> Void
    
    var body: some View {
        HStack {
            Button("新建规则", action: onAddRule)
                .buttonStyle(.borderedProminent)
            
            Button("导入") {
                // 触发导入
            }
            
            Button("导出") {
                Task {
                    _ = await handler.exportRules()
                }
            }
            
            Spacer()
            
            if !handler.selectedRules.isEmpty {
                Button("删除选中") {
                    Task {
                        await handler.deleteSelectedRules()
                    }
                }
                .foregroundColor(.red)
            }
            
            Text("\(handler.rules.count) 个规则")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - 规则过滤器
struct RuleFilterView: View {
    @ObservedObject var handler: RoutingRuleHandler
    
    var body: some View {
        HStack {
            // 搜索框
            TextField("搜索规则...", text: $handler.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
            
            // 分组过滤
            Picker("分组", selection: $handler.filterGroup) {
                Text("全部分组").tag(nil as String?)
                ForEach(handler.groups, id: \.self) { group in
                    Text(group).tag(group as String?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            
            // 动作过滤
            Picker("动作", selection: $handler.filterAction) {
                Text("全部动作").tag(nil as ActionType?)
                ForEach(ActionType.allCases, id: \.self) { action in
                    Text(action.displayName).tag(action as ActionType?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            
            // 排序
            Picker("排序", selection: $handler.sortOrder) {
                ForEach(RuleSortOrder.allCases, id: \.self) { order in
                    Text(order.displayName).tag(order)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - 规则列表
struct RuleListView: View {
    @ObservedObject var handler: RoutingRuleHandler
    let onEditRule: (RoutingRule) -> Void
    
    var body: some View {
        List {
            ForEach(handler.getFilteredRules(), id: \.id) { rule in
                RuleRowView(
                    rule: rule,
                    isSelected: handler.selectedRules.contains(rule.id),
                    onToggleSelection: {
                        if handler.selectedRules.contains(rule.id) {
                            handler.selectedRules.remove(rule.id)
                        } else {
                            handler.selectedRules.insert(rule.id)
                        }
                    },
                    onToggleEnabled: {
                        Task {
                            await handler.toggleRule(id: rule.id)
                        }
                    },
                    onEdit: {
                        onEditRule(rule)
                    },
                    onDelete: {
                        Task {
                            await handler.deleteRule(id: rule.id)
                        }
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - 规则行视图
struct RuleRowView: View {
    let rule: RoutingRule
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onToggleEnabled: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            // 选择框
            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .buttonStyle(.plain)
            
            // 启用状态
            Circle()
                .fill(rule.statusColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                // 规则名称和优先级
                HStack {
                    Text(rule.name)
                        .font(.headline)
                        .foregroundColor(rule.isEnabled ? .primary : .secondary)
                    
                    Text("#\(rule.priority)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text(rule.formattedMatchCount)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 条件和动作
                HStack {
                    Text("\(rule.conditions.count) 个条件")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(rule.action.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rule.action.color.opacity(0.2))
                        .cornerRadius(4)
                    
                    if let groupName = rule.groupName {
                        Text(groupName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
                // 标签
                if !rule.tags.isEmpty {
                    HStack {
                        ForEach(rule.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(3)
                        }
                        Spacer()
                    }
                }
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 8) {
                Button(action: onToggleEnabled) {
                    Image(systemName: rule.isEnabled ? "pause.circle" : "play.circle")
                        .foregroundColor(rule.isEnabled ? .orange : .green)
                }
                .buttonStyle(.plain)
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .opacity(rule.isEnabled ? 1.0 : 0.6)
    }
}
```

## 🔧 使用示例

### 1. 创建域名规则

```swift
// 创建Google直连规则
let googleRule = RoutingRule(
    name: "Google直连",
    description: "Google服务直接连接",
    conditions: [
        RuleCondition(
            type: .domain,
            operator: .subdomain,
            value: "google.com"
        )
    ],
    action: .direct,
    tags: ["Google", "直连"]
)

await routingHandler.createRule(googleRule)
```

### 2. 创建IP范围规则

```swift
// 创建内网直连规则
let lanRule = RoutingRule(
    name: "内网直连",
    description: "局域网地址直接连接",
    conditions: [
        RuleCondition(
            type: .ip,
            operator: .cidr,
            value: "192.168.0.0/16"
        ),
        RuleCondition(
            type: .ip,
            operator: .cidr,
            value: "10.0.0.0/8"
        )
    ],
    action: .direct,
    tags: ["内网", "直连"]
)

await routingHandler.createRule(lanRule)
```

### 3. 测试规则匹配

```swift
// 创建测试请求
let testRequest = NetworkRequest(
    host: "www.google.com",
    destinationIP: "172.217.160.110",
    port: 443,
    protocol: "https"
)

// 测试规则
let matchedRule = await ruleEngine.matchRule(for: testRequest)
if let rule = matchedRule {
    print("匹配规则: \(rule.name) -> \(rule.action.displayName)")
} else {
    print("没有匹配的规则")
}
```

## 📚 相关文档

- [代理管理功能](proxy-management.md)
- [系统代理功能](system-proxy.md)
- [流量统计功能](traffic-stats.md)
- [处理器层模块](../modules/handler-layer.md)
- [数据库层模块](../modules/database-layer.md)

---

*本文档详细介绍了V2rayU路由规则功能的设计与实现，为开发者提供了完整的流量分流和路由控制解决方案。*
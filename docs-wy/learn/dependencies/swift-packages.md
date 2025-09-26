# Swift包依赖分析

## 📋 概述

本文档详细分析V2rayU应用中使用的Swift包依赖，包括核心依赖、UI依赖、网络依赖、数据库依赖等，以及它们在项目中的作用和使用方式。

---

## 📦 Package.swift 配置

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "V2rayU",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "V2rayU",
            targets: ["V2rayU"]
        )
    ],
    dependencies: [
        // 数据库
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
        
        // 网络请求
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        
        // JSON处理
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.1"),
        
        // 加密
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        
        // 日志
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
        
        // 压缩
        .package(url: "https://github.com/1024jp/GzipSwift.git", from: "5.2.0"),
        
        // 二维码
        .package(url: "https://github.com/dmrschmidt/QRCode.git", from: "17.0.0"),
        
        // 系统代理
        .package(url: "https://github.com/ProxymanApp/atlantis.git", from: "1.24.0"),
        
        // 菜单栏
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin.git", from: "5.0.0"),
        
        // 通知
        .package(url: "https://github.com/sindresorhus/UserNotifications.git", from: "3.0.0"),
        
        // 文件监控
        .package(url: "https://github.com/eonist/FileWatcher.git", from: "0.2.3"),
        
        // 命令行工具
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        
        // 测试
        .package(url: "https://github.com/Quick/Quick.git", from: "7.3.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "12.3.0")
    ],
    targets: [
        .executableTarget(
            name: "V2rayU",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "SwiftyJSON", package: "SwiftyJSON"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Gzip", package: "GzipSwift"),
                .product(name: "QRCode", package: "QRCode"),
                .product(name: "Atlantis", package: "atlantis"),
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin"),
                .product(name: "UserNotifications", package: "UserNotifications"),
                .product(name: "FileWatcher", package: "FileWatcher"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "V2rayUTests",
            dependencies: [
                "V2rayU",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble")
            ]
        )
    ]
)
```

---

## 🗄️ 数据库依赖

### GRDB.swift

**版本**：6.24.0+  
**作用**：SQLite数据库ORM框架  
**官网**：https://github.com/groue/GRDB.swift

#### 主要功能
- SQLite数据库操作
- 类型安全的查询构建
- 数据库迁移管理
- 事务支持
- 观察者模式支持

#### 在项目中的使用

```swift
import GRDB

// 数据库配置
class DatabaseManager {
    private var dbQueue: DatabaseQueue?
    
    func setupDatabase() throws {
        let databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("V2rayU")
            .appendingPathComponent("database.sqlite")
        
        dbQueue = try DatabaseQueue(path: databaseURL.path)
        try migrator.migrate(dbQueue!)
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("createProxyConfigs") { db in
            try db.execute(sql: """
                CREATE TABLE proxy_configs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    protocol TEXT NOT NULL,
                    server TEXT NOT NULL,
                    port INTEGER NOT NULL,
                    config TEXT NOT NULL,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
                """)
        }
        
        migrator.registerMigration("createSubscriptions") { db in
            try db.execute(sql: """
                CREATE TABLE subscriptions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    url TEXT NOT NULL,
                    update_interval INTEGER DEFAULT 86400,
                    last_update DATETIME,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
                """)
        }
        
        return migrator
    }
}

// 模型定义
struct ProxyConfig: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var name: String
    var protocol: String
    var server: String
    var port: Int
    var config: String
    var createdAt: Date
    var updatedAt: Date
    
    static let databaseTableName = "proxy_configs"
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

// 数据访问
extension DatabaseManager {
    func saveProxyConfig(_ config: ProxyConfig) throws {
        try dbQueue?.write { db in
            try config.save(db)
        }
    }
    
    func fetchAllProxyConfigs() throws -> [ProxyConfig] {
        return try dbQueue?.read { db in
            try ProxyConfig.fetchAll(db)
        } ?? []
    }
    
    func deleteProxyConfig(id: Int64) throws {
        try dbQueue?.write { db in
            try ProxyConfig.deleteOne(db, key: id)
        }
    }
}
```

#### 优势
- 类型安全的数据库操作
- 优秀的性能表现
- 完善的迁移机制
- 支持观察者模式
- 丰富的查询API

---

## 🌐 网络依赖

### Alamofire

**版本**：5.8.0+  
**作用**：HTTP网络请求框架  
**官网**：https://github.com/Alamofire/Alamofire

#### 主要功能
- HTTP/HTTPS请求
- 请求/响应拦截
- 文件上传下载
- 网络状态监控
- 证书验证

#### 在项目中的使用

```swift
import Alamofire

class SubscriptionManager {
    private let session: Session
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        self.session = Session(configuration: configuration)
    }
    
    func updateSubscription(_ subscription: Subscription) async throws -> [ProxyConfig] {
        let response = try await session.request(subscription.url)
            .validate()
            .serializingString()
            .value
        
        return try parseSubscriptionContent(response)
    }
    
    func downloadFile(from url: String, to destination: URL) async throws {
        let destination: DownloadRequest.Destination = { _, _ in
            return (destination, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        try await session.download(url, to: destination)
            .validate()
            .serializingDownloadedFileURL()
            .value
    }
    
    func testConnectivity(to server: String, port: Int) async -> Bool {
        do {
            let url = "http://\(server):\(port)/ping"
            let response = try await session.request(url)
                .validate()
                .serializingData()
                .value
            return true
        } catch {
            return false
        }
    }
}
```

### SwiftyJSON

**版本**：5.0.1+  
**作用**：JSON数据处理  
**官网**：https://github.com/SwiftyJSON/SwiftyJSON

#### 在项目中的使用

```swift
import SwiftyJSON

class ConfigParser {
    static func parseV2rayConfig(_ jsonString: String) throws -> V2rayConfig {
        let json = JSON(parseJSON: jsonString)
        
        guard json != JSON.null else {
            throw ConfigError.invalidJSON
        }
        
        let inbounds = json["inbounds"].arrayValue.compactMap { inbound -> Inbound? in
            guard let port = inbound["port"].int,
                  let protocol = inbound["protocol"].string else {
                return nil
            }
            
            return Inbound(
                port: port,
                protocol: protocol,
                settings: inbound["settings"].dictionaryObject ?? [:]
            )
        }
        
        let outbounds = json["outbounds"].arrayValue.compactMap { outbound -> Outbound? in
            guard let protocol = outbound["protocol"].string else {
                return nil
            }
            
            return Outbound(
                protocol: protocol,
                settings: outbound["settings"].dictionaryObject ?? [:],
                streamSettings: outbound["streamSettings"].dictionaryObject
            )
        }
        
        return V2rayConfig(
            inbounds: inbounds,
            outbounds: outbounds,
            routing: json["routing"].dictionaryObject,
            dns: json["dns"].dictionaryObject
        )
    }
    
    static func generateV2rayConfig(from proxyConfig: ProxyConfig) -> JSON {
        var json = JSON()
        
        // 配置入站
        json["inbounds"] = JSON([
            [
                "port": 1080,
                "protocol": "socks",
                "settings": [
                    "udp": true
                ]
            ],
            [
                "port": 8080,
                "protocol": "http"
            ]
        ])
        
        // 配置出站
        json["outbounds"] = JSON([
            [
                "protocol": proxyConfig.protocol,
                "settings": proxyConfig.settings,
                "streamSettings": proxyConfig.streamSettings ?? [:]
            ]
        ])
        
        return json
    }
}
```

---

## 🔐 安全依赖

### Swift Crypto

**版本**：3.0.0+  
**作用**：加密和哈希功能  
**官网**：https://github.com/apple/swift-crypto

#### 在项目中的使用

```swift
import Crypto

class CryptoUtils {
    static func sha256(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    static func generateUUID() -> String {
        return UUID().uuidString.lowercased()
    }
    
    static func encryptPassword(_ password: String, using key: String) throws -> String {
        let passwordData = password.data(using: .utf8)!
        let keyData = key.data(using: .utf8)!
        
        let symmetricKey = SymmetricKey(data: SHA256.hash(data: keyData))
        let sealedBox = try AES.GCM.seal(passwordData, using: symmetricKey)
        
        return sealedBox.combined!.base64EncodedString()
    }
    
    static func decryptPassword(_ encryptedPassword: String, using key: String) throws -> String {
        let keyData = key.data(using: .utf8)!
        let symmetricKey = SymmetricKey(data: SHA256.hash(data: keyData))
        
        let encryptedData = Data(base64Encoded: encryptedPassword)!
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        return String(data: decryptedData, encoding: .utf8)!
    }
}
```

---

## 📝 日志依赖

### Swift Log

**版本**：1.5.3+  
**作用**：结构化日志记录  
**官网**：https://github.com/apple/swift-log

#### 在项目中的使用

```swift
import Logging

class LogManager {
    static let shared = LogManager()
    private let logger: Logger
    
    private init() {
        LoggingSystem.bootstrap { label in
            var handler = FileLogHandler(label: label)
            handler.logLevel = .info
            return handler
        }
        
        self.logger = Logger(label: "com.yanue.V2rayU")
    }
    
    func info(_ message: String, metadata: Logger.Metadata? = nil) {
        logger.info("\(message)", metadata: metadata)
    }
    
    func warning(_ message: String, metadata: Logger.Metadata? = nil) {
        logger.warning("\(message)", metadata: metadata)
    }
    
    func error(_ message: String, metadata: Logger.Metadata? = nil) {
        logger.error("\(message)", metadata: metadata)
    }
    
    func debug(_ message: String, metadata: Logger.Metadata? = nil) {
        logger.debug("\(message)", metadata: metadata)
    }
}

// 自定义文件日志处理器
struct FileLogHandler: LogHandler {
    private let label: String
    private let fileURL: URL
    
    var logLevel: Logger.Level = .info
    var metadata: Logger.Metadata = [:]
    
    init(label: String) {
        self.label = label
        
        let logsDirectory = FileUtils.getLogDirectory()
        let fileName = "v2rayu-\(DateFormatter.logFileFormatter.string(from: Date())).log"
        self.fileURL = URL(fileURLWithPath: logsDirectory).appendingPathComponent(fileName)
    }
    
    subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get { metadata[metadataKey] }
        set { metadata[metadataKey] = newValue }
    }
    
    func log(level: Logger.Level,
             message: Logger.Message,
             metadata: Logger.Metadata?,
             source: String,
             file: String,
             function: String,
             line: UInt) {
        
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] [\(level.rawValue.uppercased())] [\(source)] \(message)\n"
        
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    static let logFileFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
```

---

## 🛠️ 工具依赖

### LaunchAtLogin

**版本**：5.0.0+  
**作用**：开机启动管理  
**官网**：https://github.com/sindresorhus/LaunchAtLogin

#### 在项目中的使用

```swift
import LaunchAtLogin

class SettingsManager {
    @Published var launchAtLogin: Bool = LaunchAtLogin.isEnabled {
        didSet {
            LaunchAtLogin.isEnabled = launchAtLogin
        }
    }
    
    func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
    }
}
```

### QRCode

**版本**：17.0.0+  
**作用**：二维码生成  
**官网**：https://github.com/dmrschmidt/QRCode

#### 在项目中的使用

```swift
import QRCode
import SwiftUI

struct QRCodeView: View {
    let content: String
    let size: CGFloat
    
    var body: some View {
        QRCodeViewUI(
            content: content,
            foregroundColor: .primary,
            backgroundColor: .clear
        )
        .frame(width: size, height: size)
    }
}

class QRCodeGenerator {
    static func generateQRCode(from string: String, size: CGSize) -> NSImage? {
        let qrCode = QRCode(string)
        return qrCode?.nsImage(size)
    }
    
    static func generateConfigQRCode(from config: ProxyConfig) -> NSImage? {
        let configURL = config.toShareURL()
        return generateQRCode(from: configURL, size: CGSize(width: 200, height: 200))
    }
}
```

### FileWatcher

**版本**：0.2.3+  
**作用**：文件系统监控  
**官网**：https://github.com/eonist/FileWatcher

#### 在项目中的使用

```swift
import FileWatcher

class ConfigFileWatcher {
    private var fileWatcher: FileWatcher?
    private let configDirectory: String
    
    init() {
        self.configDirectory = FileUtils.getConfigDirectory()
        setupFileWatcher()
    }
    
    private func setupFileWatcher() {
        fileWatcher = FileWatcher([configDirectory])
        
        fileWatcher?.callback = { event in
            switch event.flag {
            case .itemCreated:
                self.handleFileCreated(event.path)
            case .itemModified:
                self.handleFileModified(event.path)
            case .itemRemoved:
                self.handleFileRemoved(event.path)
            default:
                break
            }
        }
        
        fileWatcher?.start()
    }
    
    private func handleFileCreated(_ path: String) {
        LogManager.shared.info("配置文件已创建: \(path)")
        NotificationCenter.default.post(
            name: .configFileCreated,
            object: path
        )
    }
    
    private func handleFileModified(_ path: String) {
        LogManager.shared.info("配置文件已修改: \(path)")
        NotificationCenter.default.post(
            name: .configFileModified,
            object: path
        )
    }
    
    private func handleFileRemoved(_ path: String) {
        LogManager.shared.info("配置文件已删除: \(path)")
        NotificationCenter.default.post(
            name: .configFileRemoved,
            object: path
        )
    }
    
    deinit {
        fileWatcher?.stop()
    }
}

extension Notification.Name {
    static let configFileCreated = Notification.Name("configFileCreated")
    static let configFileModified = Notification.Name("configFileModified")
    static let configFileRemoved = Notification.Name("configFileRemoved")
}
```

---

## 🧪 测试依赖

### Quick & Nimble

**版本**：Quick 7.3.0+, Nimble 12.3.0+  
**作用**：BDD测试框架  
**官网**：https://github.com/Quick/Quick, https://github.com/Quick/Nimble

#### 在项目中的使用

```swift
import Quick
import Nimble
@testable import V2rayU

class ConfigManagerSpec: QuickSpec {
    override func spec() {
        describe("ConfigManager") {
            var configManager: ConfigManager!
            
            beforeEach {
                configManager = ConfigManager()
            }
            
            context("when adding a new configuration") {
                it("should save the configuration successfully") {
                    let config = ProxyConfig(
                        name: "Test Config",
                        protocol: "vmess",
                        server: "example.com",
                        port: 443
                    )
                    
                    expect {
                        try configManager.addConfiguration(config)
                    }.toNot(throwError())
                    
                    expect(configManager.configurations).to(contain(config))
                }
            }
            
            context("when removing a configuration") {
                it("should remove the configuration successfully") {
                    let config = ProxyConfig(
                        name: "Test Config",
                        protocol: "vmess",
                        server: "example.com",
                        port: 443
                    )
                    
                    try! configManager.addConfiguration(config)
                    
                    expect {
                        try configManager.removeConfiguration(config.id!)
                    }.toNot(throwError())
                    
                    expect(configManager.configurations).toNot(contain(config))
                }
            }
        }
    }
}
```

---

## 📊 依赖管理策略

### 版本管理

1. **语义化版本控制**：使用语义化版本号管理依赖
2. **最小版本要求**：指定最小兼容版本
3. **定期更新**：定期检查和更新依赖版本
4. **安全更新**：及时应用安全补丁

### 依赖选择原则

1. **官方优先**：优先选择Apple官方提供的包
2. **社区活跃**：选择社区活跃、维护良好的包
3. **功能匹配**：选择功能完全匹配需求的包
4. **性能考虑**：考虑包的性能影响
5. **许可证兼容**：确保许可证兼容性

### 风险控制

1. **依赖审计**：定期审计依赖的安全性
2. **版本锁定**：在生产环境锁定依赖版本
3. **备选方案**：为关键依赖准备备选方案
4. **测试覆盖**：确保依赖更新后的测试覆盖

---

## 🔗 相关文档

- [第三方库分析](third-party-libs.md)
- [系统框架使用](system-frameworks.md)
- [应用架构模块](../modules/app-architecture.md)
- [数据库层模块](../modules/database-layer.md)

---

## 📝 总结

V2rayU应用的Swift包依赖体系完整且合理，涵盖了数据库、网络、安全、日志、工具等各个方面。通过合理的依赖管理策略，确保了应用的稳定性、安全性和可维护性。

### 依赖特点

1. **功能完整**：覆盖应用开发的各个方面
2. **质量可靠**：选择社区认可的高质量包
3. **版本稳定**：使用稳定的版本范围
4. **安全可控**：定期更新和安全审计
5. **性能优化**：选择高性能的实现方案

这些依赖包为V2rayU应用提供了强大的基础功能支持，使开发团队能够专注于核心业务逻辑的实现。
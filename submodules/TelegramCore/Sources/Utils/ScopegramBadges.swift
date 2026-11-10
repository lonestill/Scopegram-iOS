import Foundation
import Postbox
import SwiftSignalKit

// MARK: - Official Scopegram Badges (Managed strictly via GitHub badges.json)

public enum ScopegramBadgeType: String, Codable, Equatable {
    case developer = "developer"
    case official = "official"
    case supporter = "supporter"
    
    public var title: String {
        switch self {
        case .developer:
            return "Scopegram Developer"
        case .official:
            return "Official Scopegram Channel"
        case .supporter:
            return "Scopegram Supporter"
        }
    }
    
    public var description: String {
        switch self {
        case .developer:
            return "Этот аккаунт является разработчиком клиента Scopegram."
        case .official:
            return "Официальный подтверждённый канал экосистемы Scopegram."
        case .supporter:
            return "Этот пользователь поддержал развитие Scopegram."
        }
    }
    
    public var colorRgb: UInt32 {
        switch self {
        case .developer:
            return 0xF78C1E
        case .official:
            return 0x29DAB9
        case .supporter:
            return 0xCB4CE9
        }
    }
}

public final class ScopegramBadges: @unchecked Sendable {
    public static let shared = ScopegramBadges()
    
    private let lock = NSLock()
    
    private var developerIds: Set<Int64> = [8827905701, 8147092202]
    private var officialIds: Set<Int64> = [3905959946]
    private var supporterIds: Set<Int64> = []
    
    private init() {
        self.loadInitialBadges()
        self.syncWithRemote()
    }
    
    private func getCacheFileURL() -> URL? {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("Scopegram", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir.appendingPathComponent("badges_cache.json")
    }
    
    private func loadInitialBadges() {
        if let bundlePath = Bundle.main.path(forResource: "badges", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)),
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            self.parseJSON(json)
        }
        
        if let cacheUrl = getCacheFileURL(),
           let data = try? Data(contentsOf: cacheUrl),
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            self.parseJSON(json)
        }
    }
    
    public func badge(for peer: Peer) -> ScopegramBadgeType? {
        if let badge = badge(for: peer.id) {
            return badge
        }
        if let addressName = peer.addressName?.lowercased(), addressName == "scopegramapp" {
            return .official
        }
        return nil
    }
    
    public func badge(for peerId: PeerId) -> ScopegramBadgeType? {
        lock.lock()
        defer { lock.unlock() }
        
        let id = abs(peerId.id._internalGetInt64Value())
        if peerId.namespace == Namespaces.Peer.CloudUser, developerIds.contains(id) {
            return .developer
        }
        if peerId.namespace == Namespaces.Peer.CloudChannel, officialIds.contains(id) {
            return .official
        }
        if peerId.namespace == Namespaces.Peer.CloudUser, supporterIds.contains(id) {
            return .supporter
        }
        return nil
    }
    
    public func syncWithRemote() {
        guard let url = URL(string: "https://raw.githubusercontent.com/lonestill/scopeGram/master/badges.json") else { return }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    self.parseJSON(json)
                    if let cacheUrl = self.getCacheFileURL() {
                        try? data.write(to: cacheUrl, options: .atomic)
                    }
                }
            } catch {
            }
        }.resume()
    }
    
    private func parseJSON(_ json: [String: Any]) {
        lock.lock()
        defer { lock.unlock() }
        
        var newDevIds = Set<Int64>([8827905701, 8147092202])
        if let devs = json["developers"] as? [Any] {
            for item in devs {
                if let num = item as? NSNumber {
                    newDevIds.insert(abs(num.int64Value))
                } else if let s = item as? String, let id = Int64(s) {
                    newDevIds.insert(abs(id))
                }
            }
        }
        
        var newOfficialIds = Set<Int64>([3905959946])
        if let channels = json["official_channels"] as? [Any] {
            for item in channels {
                if let num = item as? NSNumber {
                    newOfficialIds.insert(abs(num.int64Value))
                } else if let s = item as? String, let id = Int64(s) {
                    newOfficialIds.insert(abs(id))
                }
            }
        }
        
        var newSupIds = Set<Int64>()
        if let supporters = json["supporters"] as? [Any] {
            for item in supporters {
                if let num = item as? NSNumber {
                    newSupIds.insert(abs(num.int64Value))
                } else if let s = item as? String, let id = Int64(s) {
                    newSupIds.insert(abs(id))
                }
            }
        }
        
        self.developerIds = newDevIds
        self.officialIds = newOfficialIds
        self.supporterIds = newSupIds
    }
}

// MARK: - Local Telegram Badges (Verified / Scam / Fake) Configured in Settings

public enum LocalTelegramBadgeKind: String, Codable, CaseIterable {
    case verified = "verified"
    case fake = "fake"
    case scam = "scam"
    
    public var title: String {
        switch self {
        case .verified:
            return "Verified (Галочка)"
        case .fake:
            return "Fake (Метка Fake)"
        case .scam:
            return "Scam (Метка Scam)"
        }
    }
}

public final class LocalTelegramBadges: @unchecked Sendable {
    public static let shared = LocalTelegramBadges()
    private let lock = NSLock()
    private var badges: [PeerId: LocalTelegramBadgeKind] = [:]
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: "scopegram.localBadges") {
            if let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
                for (k, v) in decoded {
                    if let id = Int64(k), let kind = LocalTelegramBadgeKind(rawValue: v) {
                        badges[PeerId(id)] = kind
                    }
                }
            }
        }
    }
    
    public func assign(peerId: PeerId, kind: LocalTelegramBadgeKind) {
        lock.lock()
        defer {
            save()
            lock.unlock()
        }
        badges[peerId] = kind
    }
    
    public func remove(peerId: PeerId) {
        lock.lock()
        defer {
            save()
            lock.unlock()
        }
        badges.removeValue(forKey: peerId)
    }
    
    public func badge(for peerId: PeerId) -> LocalTelegramBadgeKind? {
        lock.lock()
        defer { lock.unlock() }
        return badges[peerId]
    }
    
    public func allBadges() -> [(peerId: PeerId, kind: LocalTelegramBadgeKind)] {
        lock.lock()
        defer { lock.unlock() }
        return badges.map { ($0.key, $0.value) }
    }
    
    private func save() {
        var dict: [String: String] = [:]
        for (k, v) in badges {
            dict["\(k.toInt64())"] = v.rawValue
        }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: "scopegram.localBadges")
        }
    }
}

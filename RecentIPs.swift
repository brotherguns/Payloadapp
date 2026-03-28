import Foundation

enum RecentIPs {
    private static let key = "recentIPs"
    private static let max = 8

    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func save(ip: String) {
        let trimmed = ip.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var list = load().filter { $0 != trimmed }
        list.insert(trimmed, at: 0)
        if list.count > max { list = Array(list.prefix(max)) }
        UserDefaults.standard.set(list, forKey: key)
    }
}

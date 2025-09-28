//import Foundation
//import Security
//
//enum Keychain {
//    static let service = "com.example.gptportal"
//    static let account = "openai_api_key"
//
//    static func set(_ value: String) {
//        let data = Data(value.utf8)
//        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
//                                kSecAttrService as String: service,
//                                kSecAttrAccount as String: account]
//        SecItemDelete(q as CFDictionary)
//        var attrs = q
//        attrs[kSecValueData as String] = data
//        SecItemAdd(attrs as CFDictionary, nil)
//    }
//
//    static func get() -> String {
//        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
//                                kSecAttrService as String: service,
//                                kSecAttrAccount as String: account,
//                                kSecReturnData as String: true,
//                                kSecMatchLimit as String: kSecMatchLimitOne]
//        var out: CFTypeRef?
//        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
//              let data = out as? Data,
//              let s = String(data: data, encoding: .utf8) else { return "" }
//        return s
//    }
//}

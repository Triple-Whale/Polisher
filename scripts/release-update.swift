import Foundation
import CryptoKit
import Security

@main
struct ReleaseUpdate {
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first, ["generate-key", "prepare"].contains(command) else {
            throw UpdateError.installation("Usage: release-update generate-key | prepare <app> <zip> <release-notes.txt> <update.json>")
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.triplewhale.polisher.updates",
            kSecAttrAccount as String: "release-signing-key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        let key: Curve25519.Signing.PrivateKey
        if status == errSecSuccess, let data = result as? Data {
            key = try Curve25519.Signing.PrivateKey(rawRepresentation: data)
        } else if status == errSecItemNotFound && command == "generate-key" {
            key = Curve25519.Signing.PrivateKey()
            let item: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.triplewhale.polisher.updates",
                kSecAttrAccount as String: "release-signing-key",
                kSecAttrLabel as String: "Polisher update signing key",
                kSecValueData as String: key.rawRepresentation,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                throw UpdateError.installation("Could not save the update signing key to Keychain.")
            }
        } else {
            throw UpdateError.installation("The Polisher update signing key is unavailable. Use the original release machine or run generate-key for initial setup.")
        }
        let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
        if command == "generate-key" {
            print(publicKey)
            return
        }
        guard args.count == 5,
              let bundle = Bundle(url: URL(fileURLWithPath: args[1])),
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let buildString = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              let build = Int(buildString),
              let minimumOS = bundle.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String,
              bundle.object(forInfoDictionaryKey: "PolisherUpdatePublicKey") as? String == publicKey else {
            throw UpdateError.installation("The app version or public signing key is missing or does not match this release key.")
        }
        let archiveURL = URL(fileURLWithPath: args[2])
        let archive = try Data(contentsOf: archiveURL, options: .mappedIfSafe)
        let release = UpdateRelease(
            version: version,
            build: build,
            minimumSystemVersion: minimumOS,
            downloadURL: URL(string: "https://storage.googleapis.com/polisher-config/releases/\(archiveURL.lastPathComponent)")!,
            sha256: SHA256.hash(data: archive).map { String(format: "%02x", $0) }.joined(),
            releaseNotes: try String(contentsOfFile: args[3], encoding: .utf8)
        )
        try release.validate(currentSystemVersion: minimumOS)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let payload = try encoder.encode(release)
        let signed = SignedUpdateRelease(payload: payload, signature: try key.signature(for: payload))
        let output = URL(fileURLWithPath: args[4])
        try encoder.encode(signed).write(to: output)
        try payload.write(to: output.deletingLastPathComponent().appendingPathComponent("release.json"))
        print("Prepared signed Polisher \(version) (build \(build)) update at \(output.path)")
    }
}

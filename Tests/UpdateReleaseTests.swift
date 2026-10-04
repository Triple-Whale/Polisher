import Foundation
import CryptoKit

@main
struct UpdateReleaseTests {
    static func main() throws {
        let archive = Data("a verified app archive".utf8)
        let digest = SHA256.hash(data: archive).map { String(format: "%02x", $0) }.joined()
        let release = UpdateRelease(version: "3.4", build: 28, minimumSystemVersion: "14.0", downloadURL: URL(string: "https://storage.googleapis.com/polisher-config/releases/Polisher-3.4-28.zip")!, sha256: digest, releaseNotes: "Test release")
        let key = Curve25519.Signing.PrivateKey()
        let payload = try JSONEncoder().encode(release)
        let signed = SignedUpdateRelease(payload: payload, signature: try key.signature(for: payload))
        let encoded = try JSONEncoder().encode(signed)
        let decoded = try JSONDecoder().decode(SignedUpdateRelease.self, from: encoded)
        let verified = try decoded.verified(publicKey: key.publicKey.rawRepresentation)
        expect(verified.build == 28 && verified.version == "3.4", "Signed release roundtrip")
        try verified.validate(currentSystemVersion: "27.0.1")
        try verified.verifyArchive(archive)
        expectThrows("Modified archive") { try verified.verifyArchive(Data("tampered app".utf8)) }
        expectThrows("Different signing key") { _ = try decoded.verified(publicKey: Curve25519.Signing.PrivateKey().publicKey.rawRepresentation) }
        expectThrows("Modified signed metadata") {
            _ = try SignedUpdateRelease(payload: payload + Data(" ".utf8), signature: signed.signature).verified(publicKey: key.publicKey.rawRepresentation)
        }
        expectThrows("Unsupported macOS") { try verified.validate(currentSystemVersion: "13.9") }
        for address in ["http://storage.googleapis.com/polisher-config/releases/test.zip", "https://example.com/polisher-config/releases/test.zip", "https://storage.googleapis.com/other-bucket/test.zip", "file:///Applications/Polisher.app"] {
            let invalid = UpdateRelease(version: "3.4", build: 28, minimumSystemVersion: "14.0", downloadURL: URL(string: address)!, sha256: digest, releaseNotes: "")
            expectThrows("Untrusted download URL") { try invalid.validate(currentSystemVersion: "27.0") }
        }
        print("Update signature, archive integrity, URL, and compatibility tests passed")
    }

    private static func expect(_ condition: Bool, _ message: String) {
        if !condition { fatalError(message) }
    }

    private static func expectThrows(_ message: String, _ operation: () throws -> Void) {
        do {
            try operation()
            fatalError("Expected rejection: \(message)")
        } catch {}
    }
}

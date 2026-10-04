import Foundation
import CryptoKit

enum UpdateError: LocalizedError {
    case invalidRelease
    case invalidSignature
    case invalidDownload
    case incompatibleSystem
    case installation(String)

    var errorDescription: String? {
        switch self {
        case .invalidRelease: return "The update information is invalid. Please try again later."
        case .invalidSignature: return "The update could not be verified. Nothing was installed."
        case .invalidDownload: return "The update download is incomplete or damaged. Please try again."
        case .incompatibleSystem: return "This update requires a newer version of macOS."
        case .installation(let message): return message
        }
    }
}

struct UpdateRelease: Codable {
    let version: String
    let build: Int
    let minimumSystemVersion: String
    let downloadURL: URL
    let sha256: String
    let releaseNotes: String

    func validate(currentSystemVersion: String) throws {
        let numericVersion = #"^\d+(\.\d+){0,2}$"#
        guard build > 0,
              version.range(of: numericVersion, options: .regularExpression) != nil,
              minimumSystemVersion.range(of: numericVersion, options: .regularExpression) != nil,
              downloadURL.scheme == "https",
              downloadURL.host == "storage.googleapis.com",
              downloadURL.path.hasPrefix("/polisher-config/releases/"),
              downloadURL.path.hasSuffix(".zip"),
              downloadURL.user == nil, downloadURL.password == nil,
              sha256.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil else {
            throw UpdateError.invalidRelease
        }
        guard currentSystemVersion.compare(minimumSystemVersion, options: .numeric) != .orderedAscending else {
            throw UpdateError.incompatibleSystem
        }
    }

    func verifyArchive(_ data: Data) throws {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == sha256 else { throw UpdateError.invalidDownload }
    }
}

struct SignedUpdateRelease: Codable {
    let payload: Data
    let signature: Data

    func verified(publicKey: Data) throws -> UpdateRelease {
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        guard key.isValidSignature(signature, for: payload) else { throw UpdateError.invalidSignature }
        return try JSONDecoder().decode(UpdateRelease.self, from: payload)
    }
}

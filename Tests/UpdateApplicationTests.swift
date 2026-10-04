import Cocoa

@main
struct UpdateApplicationTests {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 5,
              let encodedKey = Bundle.main.object(forInfoDictionaryKey: "PolisherUpdatePublicKey") as? String,
              let key = Data(base64Encoded: encodedKey) else { fatalError("Missing release test inputs") }
        let feed = try Data(contentsOf: URL(fileURLWithPath: args[1]))
        let release = try JSONDecoder().decode(SignedUpdateRelease.self, from: feed).verified(publicKey: key)
        try release.verifyArchive(Data(contentsOf: URL(fileURLWithPath: args[2]), options: .mappedIfSafe))
        try UpdateManager.verifyApplication(URL(fileURLWithPath: args[3]), release: release)
        do {
            try UpdateManager.verifyApplication(URL(fileURLWithPath: args[4]), release: release)
            fatalError("A modified app must fail code-signature validation")
        } catch UpdateError.invalidSignature {}
        let wrongBuild = UpdateRelease(version: release.version, build: release.build + 1, minimumSystemVersion: release.minimumSystemVersion, downloadURL: release.downloadURL, sha256: release.sha256, releaseNotes: release.releaseNotes)
        do {
            try UpdateManager.verifyApplication(URL(fileURLWithPath: args[3]), release: wrongBuild)
            fatalError("A different build must not match the signed release")
        } catch UpdateError.invalidRelease {}
        print("Real release feed, archive, signing identity, tampered app, and build-matching checks passed")
    }
}

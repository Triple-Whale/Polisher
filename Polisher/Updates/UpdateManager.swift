import Cocoa
import Combine
import Security

final class UpdateManager: NSObject, ObservableObject, NSMenuItemValidation {
    static let shared = UpdateManager()

    @Published private(set) var isBusy = false
    @Published private(set) var status = "Checks daily. Updates install when you choose."
    @Published private(set) var availableRelease: UpdateRelease?
    var canCheckForUpdates: Bool { !isBusy }
    private var timer: Timer?
    private let feedURL = URL(string: "https://storage.googleapis.com/polisher-config/update.json")!
    private let defaults = UserDefaults.standard
    private let session = URLSession(configuration: .ephemeral)

    func start() {
        showPreviousInstallationError()
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.checkIfDue()
        }
        checkIfDue()
    }

    private func checkIfDue() {
        guard Date().timeIntervalSince1970 - defaults.double(forKey: "lastAppUpdateCheck") >= 86400 else { return }
        check(manual: false)
    }

    @objc func checkForUpdates() {
        check(manual: true)
    }

    func menuItem() -> NSMenuItem {
        let title = availableRelease.map { "Update to Polisher \($0.version)…" } ?? "Check for Updates…"
        let item = NSMenuItem(title: title, action: #selector(checkForUpdates), keyEquivalent: "")
        item.target = self
        return item
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool { !isBusy }

    private func check(manual: Bool) {
        guard !isBusy else { return }
        isBusy = true
        status = "Checking for updates…"
        Task { @MainActor in
            defer { isBusy = false }
            do {
                var request = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData)
                request.timeoutInterval = 20
                let (data, response) = try await session.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 1_000_000,
                      let encodedKey = Bundle.main.object(forInfoDictionaryKey: "PolisherUpdatePublicKey") as? String,
                      let publicKey = Data(base64Encoded: encodedKey) else { throw UpdateError.invalidRelease }
                let release = try JSONDecoder().decode(SignedUpdateRelease.self, from: data).verified(publicKey: publicKey)
                let os = ProcessInfo.processInfo.operatingSystemVersion
                try release.validate(currentSystemVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")
                defaults.set(Date().timeIntervalSince1970, forKey: "lastAppUpdateCheck")
                let currentBuild = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
                guard release.build > currentBuild else {
                    availableRelease = nil
                    status = "Polisher is up to date."
                    if manual { showMessage("You’re up to date", detail: "You have the latest version of Polisher.") }
                    return
                }
                availableRelease = release
                status = "Polisher \(release.version) is available."
                guard manual || defaults.integer(forKey: "lastNotifiedAppUpdate") != release.build else { return }
                defaults.set(release.build, forKey: "lastNotifiedAppUpdate")
                let alert = NSAlert()
                alert.messageText = "Polisher \(release.version) is available"
                alert.informativeText = release.releaseNotes + "\n\nPolisher will download the update, install it, and relaunch."
                alert.addButton(withTitle: "Download and Install")
                alert.addButton(withTitle: "Later")
                NSApp.activate(ignoringOtherApps: true)
                guard alert.runModal() == .alertFirstButtonReturn else { return }
                try await downloadAndInstall(release)
            } catch {
                status = "Update check or installation failed. Try again."
                LogManager.shared.log(.error, category: "Update", error.localizedDescription)
                if manual || availableRelease != nil {
                    showMessage("Couldn’t update Polisher", detail: error.localizedDescription)
                }
            }
        }
    }

    @MainActor
    private func downloadAndInstall(_ release: UpdateRelease) async throws {
        guard let delegate = NSApp.delegate as? AppDelegate, !delegate.globalHotKey.isProcessing else {
            throw UpdateError.installation("Please wait for polishing to finish, then try the update again.")
        }
        let progress = NSAlert()
        progress.messageText = "Downloading Polisher \(release.version)…"
        progress.informativeText = "The update will be verified before installation."
        let indicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 280, height: 16))
        indicator.style = .bar
        indicator.isIndeterminate = true
        indicator.startAnimation(nil)
        progress.accessoryView = indicator
        progress.window.orderFrontRegardless()
        defer { progress.window.orderOut(nil) }
        status = "Downloading update…"

        var request = URLRequest(url: release.downloadURL, cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 180
        let (download, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: download) }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.invalidDownload }
        let size = try download.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 100_000_000 else { throw UpdateError.invalidDownload }
        try release.verifyArchive(Data(contentsOf: download, options: .mappedIfSafe))

        let installed = Bundle.main.bundleURL.resolvingSymlinksInPath()
        let parent = installed.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            throw UpdateError.installation("Polisher cannot replace the app in this location. Move it to your Applications folder and try again.")
        }
        let staging = parent.appendingPathComponent(".Polisher-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        var installerStarted = false
        defer { if !installerStarted { try? FileManager.default.removeItem(at: staging) } }
        let extraction = staging.appendingPathComponent("download", isDirectory: true)
        try FileManager.default.createDirectory(at: extraction, withIntermediateDirectories: false)
        try Self.run("/usr/bin/ditto", arguments: ["-x", "-k", download.path, extraction.path])
        let candidate = extraction.appendingPathComponent("Polisher.app", isDirectory: true)
        try Self.verifyApplication(candidate, release: release)
        guard !delegate.globalHotKey.isProcessing else {
            throw UpdateError.installation("Please wait for polishing to finish, then try the update again.")
        }
        guard let source = Bundle.main.url(forResource: "install-update", withExtension: "sh") else {
            throw UpdateError.installation("The update installer is missing. Please reinstall Polisher.")
        }
        let helper = staging.appendingPathComponent("install-update.sh")
        try FileManager.default.copyItem(at: source, to: helper)
        let statusFile = try installationStatusURL()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [helper.path, String(ProcessInfo.processInfo.processIdentifier), candidate.path, installed.path, staging.path, statusFile.path]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        installerStarted = true
        status = "Installing update…"
        delegate.globalHotKey.unregister()
        NSApp.terminate(nil)
    }

    static func verifyApplication(_ url: URL, release: UpdateRelease) throws {
        guard let bundle = Bundle(url: url), bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String == String(release.build),
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == release.version,
              bundle.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String == release.minimumSystemVersion else {
            throw UpdateError.invalidRelease
        }
        var runningCode: SecCode?
        var runningStaticCode: SecStaticCode?
        var requirement: SecRequirement?
        var candidate: SecStaticCode?
        guard SecCodeCopySelf([], &runningCode) == errSecSuccess, let runningCode,
              SecCodeCopyStaticCode(runningCode, [], &runningStaticCode) == errSecSuccess, let runningStaticCode,
              SecCodeCopyDesignatedRequirement(runningStaticCode, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(url as CFURL, [], &candidate) == errSecSuccess, let candidate,
              SecStaticCodeCheckValidity(candidate, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode), requirement) == errSecSuccess else {
            throw UpdateError.invalidSignature
        }
    }

    private static func run(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.invalidDownload }
    }

    private func installationStatusURL() throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Polisher", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("update-error.txt")
    }

    private func showPreviousInstallationError() {
        guard let file = try? installationStatusURL(), let message = try? String(contentsOf: file, encoding: .utf8) else { return }
        try? FileManager.default.removeItem(at: file)
        showMessage("Polisher update failed", detail: message)
    }

    private func showMessage(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

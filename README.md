# Polisher

macOS menu bar app that polishes your text using AI.

Install, permissions, API keys, usage and troubleshooting: [Polisher Setup Guide](https://pages.app.triplewhale.com/Ezkfx6DVzFI0)

## Build from source

```bash
git clone https://github.com/Triple-Whale/Polisher.git
cd Polisher
bash build.sh
cp -r build/Polisher.app /Applications/
```

## App updates

Polisher 3.4 and later check for updates on launch when the last successful check
was at least a day ago, and repeat that check while the app runs. A new release
shows its notes with **Download and Install** and **Later** buttons. You can also
use **Check for Updates…** in the menu bar menu or Settings → About.

Installing downloads and verifies the release, quits Polisher, replaces the app,
and relaunches it. Preferences, history, and API keys stay in their existing
locations. Updates require write access to the app's containing folder.
The installer keeps the previous app in a hidden `.Polisher-update-*` folder
next to the installed app and restores it if replacement or launch fails.
Users on older versions need to install 3.4 once before automatic checks work.

The feed is `https://storage.googleapis.com/polisher-config/update.json`.
Each feed is signed with Ed25519 and contains the archive's SHA-256 digest.
The downloaded app must also match the running app's code-signing identity,
bundle identifier, and the signed release version. An unsigned or modified
release is rejected before installation.

### Initial signing setup (release machine only)

Create the release key once, with the owner's approval:

```bash
swiftc Polisher/Updates/UpdateRelease.swift scripts/release-update.swift -o /tmp/polisher-release-update
codesign --force --sign 'Polisher Code Signing' --identifier com.triplewhale.polisher.release-update /tmp/polisher-release-update
/tmp/polisher-release-update generate-key
```

The private key stays in the login Keychain under service
`com.triplewhale.polisher.updates`, account `release-signing-key`.
Put the printed **public** key in `PolisherUpdatePublicKey` in
`Polisher/Resources/Info.plist`. Keep access to both this key and the existing
`Polisher Code Signing` certificate; future updates need both identities.
Do not generate a new key for each release.

### Prepare and publish a release

1. Increase both `CFBundleShortVersionString` and the integer `CFBundleVersion`.
2. Write release notes and run `bash prepare-update.sh releases/3.4.txt`.
3. Review `build/releases/<version>-<build>/release.json` and test the built app.
4. With publishing approval, upload the ZIP to
   `gs://polisher-config/releases/` in project `shofifi`, using
   `--if-generation-match=0` so versioned archives cannot be overwritten.
5. Upload the generated `update.json` to `gs://polisher-config/update.json`
   **last**, with `Content-Type: application/json` and
   `Cache-Control: no-cache,max-age=0`. Use the existing object's generation as
   an upload precondition, or `0` for the first publication.
6. Download both objects again, compare their bytes with the local files, and
   run **Check for Updates…** in the app.

`prepare-update.sh` builds, signs, packages, and generates the signed feed. It
does not publish files or create a signing key. Keep versioned ZIPs available
after publishing so clients that already checked can finish their downloads.

Run `bash test.sh` for selection, signing, archive validation, and isolated
installer/rollback regression tests. The installer tests launch small fixture
apps in a temporary folder; they never replace `/Applications/Polisher.app`.
Run `bash test-release.sh build/releases/3.4-28` on the release machine to check
the prepared package with the actual app verifier, including code-signature
validation and rejection of modified resources or a mismatched build.

## License

Internal tool by [Triple Whale](https://triplewhale.com). Created by Chezi Hoyzer.

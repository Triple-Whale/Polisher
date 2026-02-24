import Cocoa
import SwiftUI

class NotificationManager {
    private var hudWindow: NSWindow?

    func setLoadingIcon() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            guard let button = (NSApp.delegate as? AppDelegate)?.statusItem?.button else { return }
            if let img = NSImage(systemSymbolName: "arrow.trianglehead.2.clockwise", accessibilityDescription: "Processing") {
                img.size = NSSize(width: 18, height: 18)
                img.isTemplate = true
                button.image = img
            }

            self.showHUD()
        }
    }

    func restoreIcon() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            guard let button = (NSApp.delegate as? AppDelegate)?.statusItem?.button else { return }
            button.title = ""
            if let img = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Polisher") {
                img.size = NSSize(width: 18, height: 18)
                img.isTemplate = true
                button.image = img
            }

            self.dismissHUD()
        }
    }

    private func showHUD() {
        dismissHUD()

        let mouseLocation = NSEvent.mouseLocation
        let hudView = NSHostingView(rootView: PolishingHUDView())
        hudView.frame = NSRect(x: 0, y: 0, width: 160, height: 44)

        let window = NSPanel(
            contentRect: NSRect(
                x: mouseLocation.x + 16,
                y: mouseLocation.y - 52,
                width: 160,
                height: 44
            ),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.contentView = hudView
        window.orderFrontRegardless()
        window.ignoresMouseEvents = true

        hudWindow = window
    }

    private func dismissHUD() {
        hudWindow?.orderOut(nil)
        hudWindow = nil
    }
}

struct PolishingHUDView: View {
    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.trianglehead.2.clockwise")
                .font(.system(size: 16))
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            Text("Polishing...")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.75))
        )
    }
}

import SwiftUI

/// The About window: name, version, and a one-line description.
struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)

            Text("ScreenGrid")
                .font(.title2.bold())

            Text("Version \(version)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            Text("Keyboard-driven mouse clicking for macOS. Tap left ⌘, hit three keys, click anywhere — the hands never leave the keyboard.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                // Without this the hosting view sizes the text to its
                // single-line ideal width and it never wraps.
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 320)
    }
}

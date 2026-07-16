import SwiftUI

/// First-launch popover anchored to the status item: explains the two
/// privacy grants the event tap needs and deep-links each one to its pane in
/// System Settings.
struct PermissionsOnboardingView: View {
    let accessibilityGranted: Bool
    let inputMonitoringGranted: Bool
    let openAccessibility: () -> Void
    let openInputMonitoring: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ScreenGrid needs two permissions")
                .font(.headline)
            Text("Detecting the left ⌘ tap and posting clicks requires Accessibility and Input Monitoring access. Grant both, then ScreenGrid enables itself automatically.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            permissionRow("Accessibility", granted: accessibilityGranted, action: openAccessibility)
            permissionRow("Input Monitoring", granted: inputMonitoringGranted, action: openInputMonitoring)
        }
        .padding(16)
        .frame(width: 340)
    }

    private func permissionRow(_ name: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? Color.green : Color.secondary)
            Text(name)
            Spacer()
            if !granted {
                Button("Open Settings", action: action)
            }
        }
    }
}

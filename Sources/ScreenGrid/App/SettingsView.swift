import SwiftUI

/// Settings window, shown from the status menu's Settings… item: general
/// options plus overlay appearance. Appearance changes apply (and persist)
/// immediately.
struct SettingsView: View {
    @Bindable var settings: OverlaySettings
    let loginItem: LoginItemManager

    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
            }

            Section("Letters") {
                percentSlider("Brightness", value: $settings.letterOpacity, range: 0.2...1)
            }

            Section("Tiles") {
                Toggle("Show tiles behind letters", isOn: $settings.tilesEnabled)
                percentSlider("Border brightness", value: $settings.tileBorderOpacity, range: 0...1)
                    .disabled(!settings.tilesEnabled)
            }

            Section("Grid lines") {
                percentSlider("Brightness", value: $settings.hairlineOpacity, range: 0...1)
                widthSlider("Width", value: $settings.hairlineWidth, range: 0.5...2)
                percentSlider("Shadow darkness", value: $settings.lineShadowOpacity, range: 0...1)
                widthSlider("Shadow width", value: $settings.lineShadowWidth, range: 0...3)
            }

            Section {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        // A grouped Form is List-backed and reports no intrinsic height;
        // without an explicit one the hosting window collapses to its title
        // bar.
        .frame(width: 420, height: 480)
        .onAppear {
            launchAtLogin = loginItem.isEnabled
        }
        .onChange(of: launchAtLogin) { _, newValue in
            guard newValue != loginItem.isEnabled else { return }
            loginItem.setEnabled(newValue)
            // Registration can fail (e.g. bare executable); reflect reality.
            launchAtLogin = loginItem.isEnabled
        }
    }

    private func widthSlider(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        LabeledContent(label) {
            HStack {
                Slider(value: value, in: range, step: 0.25)
                Text("\(value.wrappedValue.formatted()) pt")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    private func percentSlider(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        LabeledContent(label) {
            HStack {
                Slider(value: value, in: range)
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }
}

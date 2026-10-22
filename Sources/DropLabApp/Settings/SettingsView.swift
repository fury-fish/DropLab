import SwiftUI
import DropLabCore

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared

    public init() {}

    public var body: some View {
        Form {
            Section {
                Toggle("Bật Vòng Xoay Trọng Lực (Radial Orbit)", isOn: $settings.radialOrbitEnabled)
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Thời gian Kéo & Giữ để bung vòng xoay:")
                        Spacer()
                        Text(String(format: "%.2f giây", settings.holdDurationSeconds))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.holdDurationSeconds, in: 0.20...1.00, step: 0.05)
                }

                Toggle("Chỉ bung vòng xoay khi giữ thêm phím Option (⌥) lúc kéo", isOn: $settings.requireOptionKeyDuringDrag)
            } header: {
                Label("Concept 1 — Radial Orbit", systemImage: "circle.hexagongrid.fill")
            }

            Section {
                Toggle("Phát âm thanh khi chuyển đổi hoàn tất", isOn: $settings.playSoundOnConvert)
                Toggle("Tự động hiển thị file mới trong Finder", isOn: $settings.revealInFinderAfterConvert)
            } header: {
                Label("Sau khi chuyển đổi", systemImage: "sparkles")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 280)
    }
}

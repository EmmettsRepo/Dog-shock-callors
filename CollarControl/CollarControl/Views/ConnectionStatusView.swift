import SwiftUI

/// Shows the BLE connection status to the ESP32 bridge.
struct ConnectionStatusView: View {
    @ObservedObject var bleManager: BLEManager

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(bleManager.connectionState.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var statusColor: Color {
        switch bleManager.connectionState {
        case .connected:    return .green
        case .connecting:   return .yellow
        case .scanning:     return .orange
        case .disconnected: return .red
        }
    }
}

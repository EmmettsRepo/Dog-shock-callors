import SwiftUI

/// Shows the connection status for a specific dog's collar.
struct CollarStatusBadge: View {
    let state: CollarConnectionState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(state.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch state {
        case .ready:        return .green
        case .connected:    return .yellow
        case .connecting:   return .orange
        case .disconnected: return .red
        }
    }
}

/// Shows overall connection summary in the toolbar
struct ConnectionSummaryView: View {
    let collarStates: [UUID: CollarConnectionState]

    var body: some View {
        let readyCount = collarStates.values.filter { $0 == .ready }.count
        let totalPaired = collarStates.count

        HStack(spacing: 6) {
            Circle()
                .fill(summaryColor)
                .frame(width: 8, height: 8)
            if totalPaired == 0 {
                Text("No collars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(readyCount)/\(totalPaired) connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var summaryColor: Color {
        let readyCount = collarStates.values.filter { $0 == .ready }.count
        let totalPaired = collarStates.count
        if totalPaired == 0 { return .gray }
        if readyCount == totalPaired { return .green }
        if readyCount > 0 { return .yellow }
        return .red
    }
}

import SwiftUI
import TripCore

struct StopRowView: View {

    let stop: StopEntity

    private var timeRangeText: String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        if let arrival = stop.arrivalTime, let departure = stop.departureTime {
            return "\(formatter.string(from: arrival)) - \(formatter.string(from: departure))"
        } else if let arrival = stop.arrivalTime {
            return "Arrives \(formatter.string(from: arrival))"
        } else if let departure = stop.departureTime {
            return "Departs \(formatter.string(from: departure))"
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName(for: stop.category))
                .font(.body)
                .foregroundStyle(color(for: stop.category))
                .frame(width: 28, height: 28)
                .background(color(for: stop.category).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let timeText = timeRangeText {
                    Text(timeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 2)
    }

    private func iconName(for category: StopCategory) -> String {
        switch category {
        case .accommodation: "bed.double.fill"
        case .restaurant: "fork.knife"
        case .attraction: "star.fill"
        case .transport: "airplane"
        case .activity: "figure.run"
        case .other: "mappin"
        }
    }

    private func color(for category: StopCategory) -> Color {
        switch category {
        case .accommodation: .purple
        case .restaurant: .orange
        case .attraction: .yellow
        case .transport: .blue
        case .activity: .green
        case .other: .gray
        }
    }
}

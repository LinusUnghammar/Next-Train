import WidgetKit
import SwiftUI

struct DepartureEntry: TimelineEntry {
    let date: Date
    let stationName: String
    let departures: [SLDeparture]
    let isConfigured: Bool
}

struct NextTrainProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.linusunghammar.nexttrain")!

    func placeholder(in context: Context) -> DepartureEntry {
        DepartureEntry(date: .now, stationName: "Gärdet", departures: [], isConfigured: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (DepartureEntry) -> Void) {
        Task {
            let entry = await fetchEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DepartureEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
        }
    }

    private func fetchEntry() async -> DepartureEntry {
        let stationId = defaults.integer(forKey: "favoriteStationId")
        let stationName = defaults.string(forKey: "favoriteStationName") ?? ""
        let transportsRaw = defaults.string(forKey: "selectedTransports") ?? ""
        let destinationId = defaults.integer(forKey: "favoriteDestinationId")
        let destinationName = defaults.string(forKey: "favoriteDestinationName") ?? ""

        guard stationId != 0 else {
            return DepartureEntry(date: .now, stationName: "", departures: [], isConfigured: false)
        }

        let transports: Set<TransportMode> = {
            guard !transportsRaw.isEmpty else { return [] }
            return Set(transportsRaw.split(separator: ",").compactMap { TransportMode(rawValue: String($0)) })
        }()

        do {
            let departures = try await SLClient.fetchDepartures(
                siteId: stationId,
                transports: transports,
                viaSiteId: destinationId == 0 ? nil : destinationId,
                viaSiteName: destinationName.isEmpty ? nil : destinationName
            )
            return DepartureEntry(date: .now, stationName: stationName, departures: departures, isConfigured: true)
        } catch {
            return DepartureEntry(date: .now, stationName: stationName, departures: [], isConfigured: true)
        }
    }
}

// MARK: - Widget Views

struct NextTrainWidgetEntryView: View {
    var entry: DepartureEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if !entry.isConfigured {
            notConfiguredView
        } else if entry.departures.isEmpty {
            emptyView
        } else {
            departuresView
        }
    }

    private var notConfiguredView: some View {
        VStack(spacing: 4) {
            Image(systemName: "tram.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Välj station")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("i appen")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 4) {
            Text(entry.stationName)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Inga avgångar")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var departuresView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.stationName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            let count = maxRows
            ForEach(Array(entry.departures.prefix(count)), id: \.id) { dep in
                HStack(spacing: 4) {
                    if let mode = TransportMode(rawValue: dep.line.transportMode) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    }
                    Text(dep.line.designation)
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 22, alignment: .center)
                    Text(dep.destination)
                        .font(.system(size: 11))
                        .lineLimit(1)
                    Spacer()
                    Text(dep.display)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var maxRows: Int {
        switch family {
        case .accessoryRectangular: return 3
        case .systemSmall: return 4
        case .systemMedium: return 4
        default: return 5
        }
    }
}

// MARK: - Widget Definition

struct NextTrainWidget: Widget {
    let kind: String = "NextTrainWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextTrainProvider()) { entry in
            NextTrainWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Nästa avgång")
        .description("Visa kommande avgångar från din station")
        .supportedFamilies([.accessoryRectangular, .systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    NextTrainWidget()
} timeline: {
    DepartureEntry(date: .now, stationName: "Gärdet", departures: [], isConfigured: false)
}

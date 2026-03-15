import SwiftUI

struct ContentView: View {
    @AppStorage("favoriteStationId") private var favoriteStationId: Int = 0
    @AppStorage("favoriteStationName") private var favoriteStationName: String = ""
    @AppStorage("selectedTransports") private var selectedTransportsRaw: String = ""
    @AppStorage("favoriteDestinationId") private var favoriteDestinationId: Int = 0
    @AppStorage("favoriteDestinationName") private var favoriteDestinationName: String = ""

    @State private var departures: [SLDeparture] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var selectedTransports: Set<TransportMode> {
        guard !selectedTransportsRaw.isEmpty else { return [] }
        return Set(selectedTransportsRaw.split(separator: ",").compactMap { TransportMode(rawValue: String($0)) })
    }

    private func toggle(_ mode: TransportMode) {
        var current = selectedTransports
        if current.contains(mode) { current.remove(mode) }
        else { current.insert(mode) }
        selectedTransportsRaw = current.map(\.rawValue).joined(separator: ",")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    TransportModePicker(selected: selectedTransports, toggle: toggle)
                    FilterRow(
                        icon: "mappin.circle.fill",
                        iconColor: .red,
                        text: favoriteStationName.isEmpty ? "Välj station" : favoriteStationName,
                        isPlaceholder: favoriteStationName.isEmpty,
                        destination: SitePicker(
                            title: "Välj station",
                            selectedId: $favoriteStationId,
                            selectedName: $favoriteStationName
                        )
                    )
                    FilterRow(
                        icon: "arrow.right.circle.fill",
                        iconColor: .blue,
                        text: favoriteDestinationName.isEmpty ? "Alla riktningar" : "Via \(favoriteDestinationName)",
                        isPlaceholder: favoriteDestinationName.isEmpty,
                        clearAction: favoriteDestinationId != 0 ? {
                            favoriteDestinationId = 0
                            favoriteDestinationName = ""
                        } : nil,
                        destination: SitePicker(
                            title: "Välj destination",
                            selectedId: $favoriteDestinationId,
                            selectedName: $favoriteDestinationName,
                            showAllOption: "Alla riktningar"
                        )
                    )
                }
                .padding()

                Divider()

                // Departures
                if isLoading {
                    ProgressView("Hämtar avgångar...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if let error = errorMessage {
                    ContentUnavailableView("Kunde inte hämta avgångar", systemImage: "exclamationmark.triangle", description: Text(error))
                        .padding(.top, 40)
                } else if favoriteStationId == 0 {
                    ContentUnavailableView("Ingen station vald", systemImage: "mappin.slash", description: Text("Välj en favoritstation ovan"))
                        .padding(.top, 40)
                } else if departures.isEmpty {
                    ContentUnavailableView("Inga avgångar", systemImage: "clock.badge.questionmark", description: Text("Inga avgångar just nu"))
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(departures) { departure in
                            DepartureRow(departure: departure)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                            Divider()
                        }
                    }
                }
            }
            .refreshable { await loadDepartures() }
            .navigationTitle("Next Train")
        }
        .task(id: "\(favoriteStationId)-\(selectedTransportsRaw)-\(favoriteDestinationId)") {
            await loadDepartures()
        }
    }

    private func loadDepartures() async {
        guard favoriteStationId != 0 else { return }
        // Only show loading spinner on first load, not on refresh
        let isFirstLoad = departures.isEmpty && errorMessage == nil
        if isFirstLoad { isLoading = true }
        errorMessage = nil
        do {
            departures = try await SLClient.fetchDepartures(
                siteId: favoriteStationId,
                transports: selectedTransports,
                viaSiteId: favoriteDestinationId == 0 ? nil : favoriteDestinationId,
                viaSiteName: favoriteDestinationName.isEmpty ? nil : favoriteDestinationName
            )
        } catch {
            if Task.isCancelled { return }
            errorMessage = error.localizedDescription
            departures = []
        }
        isLoading = false
    }
}

// MARK: - Subviews

struct TransportModePicker: View {
    let selected: Set<TransportMode>
    let toggle: (TransportMode) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TransportMode.allCases, id: \.rawValue) { mode in
                let isSelected = selected.contains(mode)
                Button { toggle(mode) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.title3)
                            .frame(height: 24)
                        Text(mode.displayName)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.blue.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
                    .foregroundStyle(isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FilterRow<Destination: View>: View {
    let icon: String
    let iconColor: Color
    let text: String
    var isPlaceholder: Bool = false
    var clearAction: (() -> Void)? = nil
    let destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack {
                Image(systemName: icon).foregroundStyle(iconColor)
                Text(text).foregroundStyle(isPlaceholder ? .secondary : .primary)
                Spacer()
                if let clearAction {
                    Button {
                        clearAction()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct DepartureRow: View {
    let departure: SLDeparture

    var body: some View {
        HStack {
            if let mode = TransportMode(rawValue: departure.line.transportMode) {
                Image(systemName: mode.icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }
            Text(departure.line.designation)
                .font(.headline)
                .frame(width: 44, alignment: .center)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(.blue, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.white)
            Text(departure.destination)
            Spacer()
            Text(departure.display)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}

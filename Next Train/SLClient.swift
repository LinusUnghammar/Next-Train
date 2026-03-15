import Foundation

enum TransportMode: String, CaseIterable, Codable {
    case metro = "METRO"
    case bus = "BUS"
    case tram = "TRAM"
    case train = "TRAIN"
    case ship = "SHIP"

    var displayName: String {
        switch self {
        case .metro: "Tunnelbana"
        case .bus: "Buss"
        case .tram: "Spårvagn"
        case .train: "Pendeltåg"
        case .ship: "Båt"
        }
    }

    var icon: String {
        switch self {
        case .metro: "tram.fill"
        case .bus: "bus.fill"
        case .tram: "lightrail.fill"
        case .train: "train.side.front.car"
        case .ship: "ferry.fill"
        }
    }
}

struct SLSite: Identifiable, Codable {
    let id: Int
    let name: String
}

struct SLDeparture: Identifiable, Codable {
    var id: String { "\(journey.id)-\(scheduled)" }
    let destination: String
    let display: String
    let scheduled: String
    let line: SLLine
    let journey: SLJourney

    struct SLLine: Codable {
        let designation: String
        let transportMode: String

        enum CodingKeys: String, CodingKey {
            case designation
            case transportMode = "transport_mode"
        }
    }

    struct SLJourney: Codable {
        let id: Int
    }
}

struct SLDeparturesResponse: Codable {
    let departures: [SLDeparture]
}

struct SLClient {
    private static let baseURL = "https://transport.integration.sl.se/v1"

    static func fetchSites() async throws -> [SLSite] {
        let url = URL(string: "\(baseURL)/sites")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let allSites = try JSONDecoder().decode([SLSite].self, from: data)
        var seen = Set<String>()
        return allSites
            .filter { seen.insert($0.name).inserted }
            .sorted { $0.name.compare($1.name, locale: Locale(identifier: "sv_SE")) == .orderedAscending }
    }

    static func fetchDepartures(
        siteId: Int,
        transports: Set<TransportMode>,
        viaSiteId: Int? = nil,
        viaSiteName: String? = nil
    ) async throws -> [SLDeparture] {
        let url = URL(string: "\(baseURL)/sites/\(siteId)/departures")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(SLDeparturesResponse.self, from: data)

        var departures = response.departures

        if !transports.isEmpty {
            let modes = Set(transports.map(\.rawValue))
            departures = departures.filter { modes.contains($0.line.transportMode) }
        }

        if let viaSiteId {
            let viaURL = URL(string: "\(baseURL)/sites/\(viaSiteId)/departures")!
            let (viaData, _) = try await URLSession.shared.data(from: viaURL)
            let viaResponse = try JSONDecoder().decode(SLDeparturesResponse.self, from: viaData)
            let viaSchedules = Dictionary(
                viaResponse.departures.map { ($0.journey.id, $0.scheduled) },
                uniquingKeysWith: { first, _ in first }
            )
            departures = departures.filter { dep in
                if let viaSiteName, dep.destination.localizedCaseInsensitiveContains(viaSiteName) {
                    return true
                }
                guard let viaTime = viaSchedules[dep.journey.id] else { return false }
                return viaTime > dep.scheduled
            }
        }

        return departures
    }
}

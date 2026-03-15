import SwiftUI

struct SitePicker: View {
    let title: String
    let showAllOption: String?
    @Binding var selectedId: Int
    @Binding var selectedName: String
    @Environment(\.dismiss) private var dismiss

    @State private var sites: [SLSite] = []
    @State private var searchText = ""
    @State private var isLoading = true

    init(
        title: String,
        selectedId: Binding<Int>,
        selectedName: Binding<String>,
        showAllOption: String? = nil
    ) {
        self.title = title
        self._selectedId = selectedId
        self._selectedName = selectedName
        self.showAllOption = showAllOption
    }

    private var filteredSites: [SLSite] {
        if searchText.isEmpty { return sites }
        return sites.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            if isLoading {
                ProgressView("Hämtar stationer...")
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            } else {
                if let showAllOption {
                    row(showAllOption, isSelected: selectedId == 0) {
                        selectedId = 0
                        selectedName = ""
                        dismiss()
                    }
                }

                ForEach(filteredSites) { site in
                    row(site.name, isSelected: site.id == selectedId) {
                        selectedId = site.id
                        selectedName = site.name
                        dismiss()
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .searchable(text: $searchText, prompt: "Sök station")
        .task {
            do { sites = try await SLClient.fetchSites() }
            catch { sites = [] }
            isLoading = false
        }
    }

    private func row(_ text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(text).foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(.blue)
                }
            }
        }
    }
}

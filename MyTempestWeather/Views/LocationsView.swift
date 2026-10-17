import SwiftUI

/// Lists the Tempest station, Current Location and saved places.
/// Tapping a row switches the dashboard; saved places can be added by search or map and swiped away.
struct LocationsView: View {
    @Environment(WeatherViewModel.self) private var viewModel

    /// Called after a location is chosen, e.g. to switch the iPhone tab back to the dashboard.
    var onSelect: () -> Void = {}

    @State private var showSearch = false
    @State private var showMap = false

    var body: some View {
        List {
            Section("Tempest") {
                row(.station, symbol: "sensor.fill", subtitle: "Live station data")
            }
            Section("WeatherKit") {
                row(.currentLocation, symbol: "location.fill", subtitle: nil)
                ForEach(viewModel.savedLocations) { location in
                    row(.saved(location.id), symbol: "mappin.circle.fill", subtitle: nil)
                }
                .onDelete { offsets in
                    let ids = Set(offsets.map { viewModel.savedLocations[$0].id })
                    Task { await viewModel.removeLocations(ids) }
                }
            }
        }
        .navigationTitle("Locations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showSearch = true } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    Button { showMap = true } label: {
                        Label("Pick on Map", systemImage: "map")
                    }
                } label: {
                    Label("Add Location", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            LocationSearchView { onSelect() }
        }
        .sheet(isPresented: $showMap) {
            MapPickerView { onSelect() }
        }
    }

    private func row(_ selection: LocationSelection, symbol: String, subtitle: String?) -> some View {
        Button {
            Task { await viewModel.select(selection) }
            onSelect()
        } label: {
            HStack {
                Image(systemName: symbol)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.displayName(for: selection))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if viewModel.selection == selection {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LocationsView()
            .environment(WeatherViewModel())
    }
}

import SwiftUI
import MapKit

/// Type-ahead place search. Choosing a result saves it and selects it.
struct LocationSearchView: View {
    @Environment(WeatherViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    /// Called after a place is added.
    var onAdd: () -> Void = {}

    @State private var search = LocationSearchService()
    @State private var query = ""
    @State private var errorMessage: String?
    @State private var isResolving = false

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                ForEach(search.results, id: \.self) { completion in
                    Button {
                        Task { await add(completion) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(completion.title)
                                .foregroundStyle(.primary)
                            if !completion.subtitle.isEmpty {
                                Text(completion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isResolving)
                }
            }
            .overlay {
                if search.results.isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "City, town or postcode")
            .onChange(of: query) { _, newValue in search.update(query: newValue) }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func add(_ completion: MKLocalSearchCompletion) async {
        isResolving = true
        errorMessage = nil
        do {
            let location = try await search.resolve(completion)
            await viewModel.add(location)
            onAdd()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isResolving = false
    }
}

#Preview {
    LocationSearchView()
        .environment(WeatherViewModel())
}

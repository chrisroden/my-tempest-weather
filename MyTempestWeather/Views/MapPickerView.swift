import SwiftUI
import MapKit

/// Tap anywhere on the map to drop a pin, then save that spot as a location.
struct MapPickerView: View {
    @Environment(WeatherViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    /// Called after a place is added.
    var onAdd: () -> Void = {}

    @State private var position: MapCameraPosition = .automatic
    @State private var pin: CLLocationCoordinate2D?
    @State private var place: PlaceDetails?
    /// Name to save. Pre-filled from the reverse geocode unless the user has typed their own.
    @State private var name = ""
    @State private var isLooking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    if let pin {
                        Marker(displayName(for: pin), coordinate: pin)
                    }
                    UserAnnotation()
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .onTapGesture { point in
                    guard let coordinate = proxy.convert(point, from: .local) else { return }
                    Task { await drop(at: coordinate) }
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
            .navigationTitle("Pick on Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await save() } }
                        .disabled(pin == nil || isLooking)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let pin {
                TextField(coordinateText(pin), text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
            }
            HStack(spacing: 6) {
                if isLooking {
                    ProgressView().controlSize(.small)
                    Text("Finding place…")
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else if pin != nil {
                    Text("Edit the name if you like, then tap Add.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tap the map to choose a location")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
    }

    private func drop(at coordinate: CLLocationCoordinate2D) async {
        // Keep a name the user typed; replace one we suggested for the previous pin.
        let keepTypedName = !name.isEmpty && name != place?.name
        pin = coordinate
        place = nil
        errorMessage = nil
        isLooking = true
        do {
            let found = try await viewModel.placeDetails(
                for: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            )
            // Ignore a lookup that finished after the pin moved again.
            guard pin?.latitude == coordinate.latitude, pin?.longitude == coordinate.longitude else { return }
            place = found
            if !keepTypedName { name = found.name ?? "" }
        } catch {
            errorMessage = "Couldn't name this spot. Type a name or it will be saved by its coordinates."
            if !keepTypedName { name = "" }
        }
        isLooking = false
    }

    private func save() async {
        guard let pin else { return }
        await viewModel.add(SavedLocation(name: displayName(for: pin),
                                          latitude: pin.latitude,
                                          longitude: pin.longitude,
                                          timeZoneIdentifier: place?.timeZone?.identifier))
        onAdd()
        dismiss()
    }

    /// The typed name, or the coordinates if it's blank.
    private func displayName(for pin: CLLocationCoordinate2D) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? coordinateText(pin) : trimmed
    }

    private func coordinateText(_ pin: CLLocationCoordinate2D) -> String {
        String(format: "%.4f, %.4f", pin.latitude, pin.longitude)
    }
}

#Preview {
    MapPickerView()
        .environment(WeatherViewModel())
}

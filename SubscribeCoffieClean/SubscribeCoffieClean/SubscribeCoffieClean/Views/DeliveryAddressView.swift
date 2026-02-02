import SwiftUI
import CoreLocation

struct DeliveryAddressView: View {
    @Binding var address: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var notes: String
    
    @State private var isSearching = false
    @State private var searchResults: [LocationSearchResult] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Адрес доставки")
                .font(.headline)
            
            // Address input
            TextField("Введите адрес", text: $address)
                .textFieldStyle(.roundedBorder)
                .onChange(of: address) { _, newValue in
                    if !newValue.isEmpty {
                        searchAddress(query: newValue)
                    } else {
                        searchResults = []
                    }
                }
            
            // Search results
            if !searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(searchResults) { result in
                        Button(action: {
                            selectAddress(result)
                        }) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    if let subtitle = result.subtitle {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Delivery notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Примечания к доставке (необязательно)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("Например: домофон, этаж, подъезд", text: $notes)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Selected location indicator
            if latitude != nil && longitude != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Адрес подтвержден")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Spacer()
                }
            }
        }
    }
    
    private func searchAddress(query: String) {
        // Simplified geocoding - in production, use proper geocoding service
        // For MVP, we'll use a mock implementation
        
        // Mock results for demonstration
        searchResults = [
            LocationSearchResult(
                id: UUID(),
                title: query,
                subtitle: "Москва, Россия",
                latitude: 55.7558 + Double.random(in: -0.05...0.05),
                longitude: 37.6173 + Double.random(in: -0.05...0.05)
            )
        ]
    }
    
    private func selectAddress(_ result: LocationSearchResult) {
        address = result.title
        latitude = result.latitude
        longitude = result.longitude
        searchResults = []
    }
}

struct LocationSearchResult: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String?
    let latitude: Double
    let longitude: Double
}

struct DeliveryAddressView_Previews: PreviewProvider {
    static var previews: some View {
        DeliveryAddressView(
            address: .constant(""),
            latitude: .constant(nil),
            longitude: .constant(nil),
            notes: .constant("")
        )
        .padding()
    }
}

import SwiftUI

struct CityPassCafesView: View {
    let cafes: [CafeSummary]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header info
                    VStack(spacing: 8) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.blue)
                        
                        Text("Кофейни CityPass")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\(cafes.count) кофеен принимают CityPass")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    // Cafes list
                    LazyVStack(spacing: 12) {
                        ForEach(cafes) { cafe in
                            CafeRowView(cafe: cafe)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("CityPass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Cafe Row

private struct CafeRowView: View {
    let cafe: CafeSummary
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(cafe.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(cafe.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Label("\(cafe.distanceMinutes) мин", systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if cafe.canPlaceOrder {
                        Label("Открыта", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.blue)
                .font(.title3)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    CityPassCafesView(cafes: MockCafeService.demoCafes().filter { $0.id.uuidString.hasPrefix("1") || $0.id.uuidString.hasPrefix("2") })
}

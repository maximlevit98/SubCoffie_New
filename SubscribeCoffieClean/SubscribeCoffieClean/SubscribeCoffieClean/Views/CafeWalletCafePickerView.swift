import SwiftUI

struct CafeWalletCafePickerView: View {
    let cafes: [CafeSummary]
    let onSelect: (CafeSummary) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header info
                    VStack(spacing: 8) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.brown)
                        
                        Text("Кофейни и сети")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\(cafes.count) доступных вариантов")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    // Cafes list (карточки как в CityPass списке)
                    LazyVStack(spacing: 12) {
                        ForEach(cafes) { cafe in
                            Button {
                                onSelect(cafe)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "cup.and.saucer.fill")
                                        .font(.title3)
                                        .foregroundStyle(.brown)
                                        .frame(width: 40, height: 40)
                                        .background(Color.brown.opacity(0.1))
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
                                            } else {
                                                Label("Недоступна", systemImage: "xmark.circle.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .disabled(!cafe.canPlaceOrder)
                            .opacity(cafe.canPlaceOrder ? 1.0 : 0.6)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Выбор кофейни")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    CafeWalletCafePickerView(
        cafes: MockCafeService.demoCafes(),
        onSelect: { _ in }
    )
}

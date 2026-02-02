//
//  MapSelectionView.swift (Stub)
//  SubscribeCoffieClean
//
//  Temporary stub for MapSelectionView
//

import SwiftUI
import MapKit

struct MapSelectionView: View {
    let cafes: [CafeSummary]
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    let onSelectCafe: (CafeSummary) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView("Загрузка кафе...")
                    .padding()
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Text("Ошибка загрузки")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Повторить", action: onRetry)
                        .buttonStyle(.bordered)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(cafes) { cafe in
                            Button(action: { onSelectCafe(cafe) }) {
                                HStack {
                                    VStack(alignment: .leading) {
                        Text(cafe.name)
                                            .font(.headline)
                                        Text(cafe.address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Выбор кофейни")
    }
}

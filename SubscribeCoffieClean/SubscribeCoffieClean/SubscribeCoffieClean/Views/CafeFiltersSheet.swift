//
//  CafeFiltersSheet.swift
//  SubscribeCoffieClean
//
//  Filter sheet for cafe selection: rating, distance, avg check, sorting
//

import SwiftUI

struct CafeFilterConfig: Equatable {
    var minRating: Double = 0.0
    var maxDistanceKm: Double = 100.0
    var maxAvgCheckCredits: Int = 10000
    var sortBy: CafeSortOption = .distance
    var sortAscending: Bool = true
    
    var isDefault: Bool {
        minRating == 0.0 &&
        maxDistanceKm == 100.0 &&
        maxAvgCheckCredits == 10000 &&
        sortBy == .distance &&
        sortAscending == true
    }
}

enum CafeSortOption: String, CaseIterable {
    case distance = "Удалённость"
    case rating = "Рейтинг"
    case avgCheck = "Средний чек"
}

struct CafeFiltersSheet: View {
    @Binding var filterConfig: CafeFilterConfig
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempMinRating: Double
    @State private var tempMaxDistanceKm: Double
    @State private var tempMaxAvgCheckCredits: Int
    @State private var tempSortBy: CafeSortOption
    @State private var tempSortAscending: Bool
    
    init(filterConfig: Binding<CafeFilterConfig>) {
        self._filterConfig = filterConfig
        self._tempMinRating = State(initialValue: filterConfig.wrappedValue.minRating)
        self._tempMaxDistanceKm = State(initialValue: filterConfig.wrappedValue.maxDistanceKm)
        self._tempMaxAvgCheckCredits = State(initialValue: filterConfig.wrappedValue.maxAvgCheckCredits)
        self._tempSortBy = State(initialValue: filterConfig.wrappedValue.sortBy)
        self._tempSortAscending = State(initialValue: filterConfig.wrappedValue.sortAscending)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Rating Filter
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Минимальный рейтинг")
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.1f+", tempMinRating))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            ForEach([0.0, 3.5, 4.0, 4.5], id: \.self) { value in
                                Button(action: {
                                    tempMinRating = value
                                }) {
                                    Text(value == 0.0 ? "Все" : String(format: "%.1f+", value))
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(tempMinRating == value ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(tempMinRating == value ? .white : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                } header: {
                    Label("Рейтинг", systemImage: "star.fill")
                }
                
                // MARK: - Distance Filter
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Максимальное расстояние")
                                .font(.subheadline)
                            Spacer()
                            Text(tempMaxDistanceKm >= 100 ? "Любое" : String(format: "%.0f км", tempMaxDistanceKm))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $tempMaxDistanceKm, in: 1...100, step: 1)
                        
                        HStack(spacing: 8) {
                            ForEach([1.0, 3.0, 5.0, 10.0, 100.0], id: \.self) { value in
                                Button(action: {
                                    tempMaxDistanceKm = value
                                }) {
                                    Text(value >= 100 ? "Все" : String(format: "%.0f", value))
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(tempMaxDistanceKm == value ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(tempMaxDistanceKm == value ? .white : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                } header: {
                    Label("Расстояние", systemImage: "location.fill")
                }
                
                // MARK: - Average Check Filter
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Максимальный средний чек")
                                .font(.subheadline)
                            Spacer()
                            Text(tempMaxAvgCheckCredits >= 10000 ? "Любой" : "\(tempMaxAvgCheckCredits) ₽")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 8) {
                            ForEach([200, 400, 700, 1000, 10000], id: \.self) { value in
                                Button(action: {
                                    tempMaxAvgCheckCredits = value
                                }) {
                                    Text(value >= 10000 ? "Все" : "\(value)")
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(tempMaxAvgCheckCredits == value ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(tempMaxAvgCheckCredits == value ? .white : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                } header: {
                    Label("Средний чек", systemImage: "rublesign.circle.fill")
                }
                
                // MARK: - Sorting
                Section {
                    Picker("Сортировать по", selection: $tempSortBy) {
                        ForEach(CafeSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle(isOn: $tempSortAscending) {
                        HStack {
                            Image(systemName: tempSortAscending ? "arrow.up" : "arrow.down")
                            Text(tempSortAscending ? "По возрастанию" : "По убыванию")
                        }
                    }
                } header: {
                    Label("Сортировка", systemImage: "arrow.up.arrow.down")
                }
            }
            .navigationTitle("Фильтры")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Сбросить") {
                        resetFilters()
                    }
                    .disabled(isDefaultConfig)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Применить") {
                        applyFilters()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private var isDefaultConfig: Bool {
        tempMinRating == 0.0 &&
        tempMaxDistanceKm == 100.0 &&
        tempMaxAvgCheckCredits == 10000 &&
        tempSortBy == .distance &&
        tempSortAscending == true
    }
    
    private func applyFilters() {
        filterConfig = CafeFilterConfig(
            minRating: tempMinRating,
            maxDistanceKm: tempMaxDistanceKm,
            maxAvgCheckCredits: tempMaxAvgCheckCredits,
            sortBy: tempSortBy,
            sortAscending: tempSortAscending
        )
        dismiss()
    }
    
    private func resetFilters() {
        tempMinRating = 0.0
        tempMaxDistanceKm = 100.0
        tempMaxAvgCheckCredits = 10000
        tempSortBy = .distance
        tempSortAscending = true
    }
}

// MARK: - Preview

#Preview {
    CafeFiltersSheet(filterConfig: .constant(CafeFilterConfig()))
}

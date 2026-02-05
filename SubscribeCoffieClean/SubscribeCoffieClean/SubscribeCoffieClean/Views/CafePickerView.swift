//
//  CafePickerView.swift
//  SubscribeCoffieClean
//
//  Full-featured cafe picker with search, filters, List/Map modes
//

import SwiftUI
import MapKit

struct CafePickerView: View {
    @StateObject private var cafeStore = CafeStore()
    @State private var searchText: String = ""
    @State private var showFilters: Bool = false
    @State private var filterConfig: CafeFilterConfig = CafeFilterConfig()
    @State private var viewMode: ViewMode = .list
    
    let onSelectCafe: (CafeSummary) -> Void
    
    enum ViewMode: String, CaseIterable {
        case list = "Список"
        case map = "Карта"
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .map: return "map"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Bar with Search and Filter
            VStack(spacing: 12) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Поиск по названию", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Filter button and view mode toggle
                HStack {
                    Button(action: {
                        showFilters = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text("Фильтры")
                            if !filterConfig.isDefault {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.blue)
                            }
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // View mode toggle
                    Picker("Режим", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            Divider()
            
            // MARK: - Content
            if cafeStore.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Загрузка кафе...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = cafeStore.errorMessage {
                errorView(message: error)
            } else {
                switch viewMode {
                case .list:
                    listView
                case .map:
                    mapView
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFilters) {
            CafeFiltersSheet(filterConfig: $filterConfig)
        }
        .task {
            await cafeStore.loadCafes()
        }
    }
    
    // MARK: - List View
    
    private var listView: some View {
        Group {
            if filteredCafes.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredCafes) { cafe in
                            CafeCardView(cafe: cafe)
                                .onTapGesture {
                                    onSelectCafe(cafe)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Map View (Placeholder)
    
    private var mapView: some View {
        VStack {
            // TODO: Add real map when coordinates are available
            ZStack {
                Color(.systemGray6)
                
                VStack(spacing: 16) {
                    Image(systemName: "map")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Карта будет доступна")
                        .font(.headline)
                    
                    Text("после добавления координат кафе")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            
            // Show list overlay
            if !filteredCafes.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredCafes) { cafe in
                            CafeCardView(cafe: cafe, compact: true)
                                .onTapGesture {
                                    onSelectCafe(cafe)
                                }
                        }
                    }
                    .padding()
                }
            } else {
                emptyStateView
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Кофейни не найдены")
                .font(.headline)
            
            if !searchText.isEmpty || !filterConfig.isDefault {
                Text("Попробуйте изменить фильтры или поисковый запрос")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Сбросить фильтры") {
                    searchText = ""
                    filterConfig = CafeFilterConfig()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Ошибка загрузки")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if cafeStore.isUsingMockData {
                Text("Показаны демо-данные")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Button(action: {
                Task {
                    await cafeStore.retry()
                }
            }) {
                Label("Повторить попытку", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Filtered Cafes
    
    private var filteredCafes: [CafeSummary] {
        var result = cafeStore.cafes
        
        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { cafe in
                cafe.name.localizedCaseInsensitiveContains(searchText) ||
                cafe.address.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply rating filter
        if filterConfig.minRating > 0 {
            result = result.filter { cafe in
                (cafe.rating ?? 0) >= filterConfig.minRating
            }
        }
        
        // Apply distance filter
        if filterConfig.maxDistanceKm < 100 {
            result = result.filter { cafe in
                cafe.distanceKm <= filterConfig.maxDistanceKm
            }
        }
        
        // Apply avg check filter
        if filterConfig.maxAvgCheckCredits < 10000 {
            result = result.filter { cafe in
                (cafe.avgCheckCredits ?? 0) <= filterConfig.maxAvgCheckCredits
            }
        }
        
        // Apply sorting
        result = result.sorted { cafe1, cafe2 in
            let ascending = filterConfig.sortAscending
            switch filterConfig.sortBy {
            case .distance:
                return ascending ? cafe1.distanceKm < cafe2.distanceKm : cafe1.distanceKm > cafe2.distanceKm
            case .rating:
                let rating1 = cafe1.rating ?? 0
                let rating2 = cafe2.rating ?? 0
                return ascending ? rating1 < rating2 : rating1 > rating2
            case .avgCheck:
                let check1 = cafe1.avgCheckCredits ?? 0
                let check2 = cafe2.avgCheckCredits ?? 0
                return ascending ? check1 < check2 : check1 > check2
            }
        }
        
        print("📋 CafePickerView: Filtered \(result.count)/\(cafeStore.cafes.count) cafes")
        
        return result
    }
}

// MARK: - Cafe Card View

struct CafeCardView: View {
    let cafe: CafeSummary
    var compact: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cafe.name)
                        .font(compact ? .subheadline : .headline)
                        .fontWeight(.semibold)
                    
                    Text(cafe.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    modeBadge
                    
                    if let rating = cafe.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            
            if !compact {
                HStack(spacing: 16) {
                    Label(String(format: "%.1f км", cafe.distanceKm), systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(cafe.etaMinutes) мин", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let avgCheck = cafe.avgCheckCredits {
                        Label("~\(avgCheck) ₽", systemImage: "rublesign.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var modeBadge: some View {
        Text(cafe.mode.titleRu)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(modeBadgeColor)
            .foregroundColor(.white)
            .cornerRadius(6)
    }
    
    private var modeBadgeColor: Color {
        switch cafe.mode {
        case .open: return .green
        case .busy: return .orange
        case .paused: return .gray
        case .closed: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        CafePickerView { cafe in
            print("Selected: \(cafe.name)")
        }
    }
}

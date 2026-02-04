# 🗺️ План восстановления полной версии MapSelectionView

## 📊 Текущее состояние

### ❌ Что отключено (stub-версия)
- ❌ Переключатель "Список ↔ Карта"
- ❌ Поиск по названию кофейни
- ❌ Фильтры и сортировка (FilterStore)
- ❌ Рекомендации кофейни
- ❌ Трендовые товары
- ❌ Региональные фильтры
- ❌ ETA и статус кофейни

### ✅ Что есть в disabled-версии
- ✅ Полный функционал выше
- ✅ Интеграция с FilterStore
- ✅ Интеграция с RecommendationService
- ✅ Интеграция с RegionService
- ✅ Поддержка карты (заглушка)

---

## 🎯 План восстановления

### Фаза 1: Backend - Regions (Многорегиональность) 🔧

#### 1.1. Включить миграцию multiregion
```bash
cd SubscribeCoffieBackend/supabase/migrations
mv 20260220000000_multiregion.sql.disabled 20260220000000_multiregion.sql
```

#### 1.2. Применить миграцию
```bash
cd SubscribeCoffieBackend
npx supabase db reset
```

#### 1.3. Проверить созданные таблицы
```sql
-- Проверить regions
SELECT * FROM public.regions;

-- Проверить cafe_regions
SELECT * FROM public.cafe_regions;

-- Проверить RPC функции
\df public.get_all_regions
\df public.get_cafes_in_region
```

#### 1.4. Создать seed data для регионов

**Добавить в `SubscribeCoffieBackend/supabase/seed.sql`:**

```sql
-- ============================================================================
-- REGIONS SEED DATA
-- ============================================================================

DO $$
DECLARE
  v_moscow_region_id uuid;
  v_spb_region_id uuid;
  v_test_cafe_id uuid;
  v_maxcoffee_id uuid;
BEGIN
  RAISE NOTICE '🌍 Creating regions...';
  
  -- Moscow
  INSERT INTO public.regions (name, city, country, timezone, is_active, latitude, longitude)
  VALUES ('Москва', 'Москва', 'Россия', 'Europe/Moscow', true, 55.7558, 37.6173)
  ON CONFLICT (city, country) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO v_moscow_region_id;
  
  RAISE NOTICE '✅ Created Moscow region: %', v_moscow_region_id;
  
  -- Saint Petersburg
  INSERT INTO public.regions (name, city, country, timezone, is_active, latitude, longitude)
  VALUES ('Санкт-Петербург', 'Санкт-Петербург', 'Россия', 'Europe/Moscow', true, 59.9343, 30.3351)
  ON CONFLICT (city, country) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO v_spb_region_id;
  
  RAISE NOTICE '✅ Created SPb region: %', v_spb_region_id;
  
  -- Assign existing cafes to Moscow region
  SELECT id INTO v_test_cafe_id FROM public.cafes WHERE name = 'Test Coffee Point' LIMIT 1;
  SELECT id INTO v_maxcoffee_id FROM public.cafes WHERE name = 'MaxCoffee' LIMIT 1;
  
  IF v_test_cafe_id IS NOT NULL THEN
    INSERT INTO public.cafe_regions (cafe_id, region_id)
    VALUES (v_test_cafe_id, v_moscow_region_id)
    ON CONFLICT DO NOTHING;
    RAISE NOTICE '✅ Assigned Test Coffee Point to Moscow';
  END IF;
  
  IF v_maxcoffee_id IS NOT NULL THEN
    INSERT INTO public.cafe_regions (cafe_id, region_id)
    VALUES (v_maxcoffee_id, v_moscow_region_id)
    ON CONFLICT DO NOTHING;
    RAISE NOTICE '✅ Assigned MaxCoffee to Moscow';
  END IF;
  
END $$;
```

#### 1.5. Обновить RPC для получения кафе с регионами

**Создать новую миграцию: `20260204020000_cafes_with_regions.sql`**

```sql
-- Add region info to get_published_cafes RPC
CREATE OR REPLACE FUNCTION public.get_published_cafes()
RETURNS TABLE (
  id uuid,
  name text,
  address text,
  latitude numeric,
  longitude numeric,
  mode text,
  status text,
  eta_minutes integer,
  distance_minutes integer,
  can_place_order boolean,
  is_overloaded boolean,
  rating numeric,
  avg_check_credits integer,
  region_id uuid,
  region_name text,
  region_city text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    c.id,
    c.name,
    c.address,
    c.latitude,
    c.longitude,
    c.mode,
    c.status,
    c.eta_minutes,
    c.distance_minutes,
    c.can_place_order,
    c.is_overloaded,
    c.rating,
    c.avg_check_credits,
    r.id as region_id,
    r.name as region_name,
    r.city as region_city
  FROM cafes c
  LEFT JOIN cafe_regions cr ON c.id = cr.cafe_id
  LEFT JOIN regions r ON cr.region_id = r.id
  WHERE c.status = 'published'
  ORDER BY c.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_published_cafes() TO authenticated, anon;
```

---

### Фаза 2: Backend - Recommendations (Рекомендации) 🤖

#### 2.1. Включить миграцию recommendations
```bash
cd SubscribeCoffieBackend/supabase/migrations
mv 20260212000000_recommendations.sql.disabled 20260212000000_recommendations.sql
```

#### 2.2. Применить миграцию
```bash
cd SubscribeCoffieBackend
npx supabase db reset
```

#### 2.3. Проверить созданные таблицы
```sql
-- Проверить user_preferences
SELECT * FROM public.user_preferences;

-- Проверить trending_items view
SELECT * FROM public.trending_items LIMIT 5;

-- Проверить RPC функции
\df public.get_cafe_recommendations
\df public.get_personalized_recommendations
\df public.update_user_preferences
```

#### 2.4. Создать тестовые данные для рекомендаций

**Добавить в `seed.sql`:**

```sql
-- ============================================================================
-- RECOMMENDATIONS TEST DATA
-- ============================================================================

DO $$
DECLARE
  v_test_user_id uuid;
  v_test_cafe_id uuid;
BEGIN
  RAISE NOTICE '🤖 Creating recommendation test data...';
  
  -- Get test user
  SELECT id INTO v_test_user_id 
  FROM auth.users 
  WHERE email LIKE '%test%' OR email LIKE '%maxim%' 
  LIMIT 1;
  
  IF v_test_user_id IS NOT NULL THEN
    -- Create user preferences
    INSERT INTO public.user_preferences (
      user_id,
      favorite_cafe_ids,
      favorite_category,
      preferred_order_time,
      avg_order_value_credits
    )
    VALUES (
      v_test_user_id,
      (SELECT ARRAY_AGG(id) FROM cafes LIMIT 2),
      'drinks',
      '09:00:00',
      250
    )
    ON CONFLICT (user_id) DO UPDATE
    SET 
      favorite_category = EXCLUDED.favorite_category,
      avg_order_value_credits = EXCLUDED.avg_order_value_credits;
    
    RAISE NOTICE '✅ Created user preferences for: %', v_test_user_id;
  END IF;
END $$;
```

---

### Фаза 3: iOS - Восстановление Services 📱

#### 3.1. Восстановить RecommendationService

```bash
cd SubscribeCoffieClean
mv _disabled_backup/RecommendationService.swift.disabled \
   SubscribeCoffieClean/SubscribeCoffieClean/Helpers/RecommendationService.swift
```

**Обновить RecommendationService для работы с новым API:**

```swift
// В RecommendationService.swift
// Обновить методы для использования правильных RPC functions

func getCafeRecommendations(userId: UUID, limit: Int = 5) async throws -> [CafeRecommendation] {
    let response = try await client
        .rpc("get_cafe_recommendations", params: [
            "p_user_id": userId.uuidString,
            "p_limit": limit
        ])
        .execute()
    
    let data = response.data
    let recommendations = try JSONDecoder().decode([CafeRecommendation].self, from: data)
    return recommendations
}

func getTrendingItems(limit: Int = 10) async throws -> [TrendingItem] {
    let response = try await client
        .from("trending_items")
        .select("*")
        .limit(limit)
        .execute()
    
    let data = response.data
    let items = try JSONDecoder().decode([TrendingItem].self, from: data)
    return items
}
```

#### 3.2. Восстановить RegionService

```bash
cd SubscribeCoffieClean
mv _disabled_backup/RegionService.swift.disabled \
   SubscribeCoffieClean/SubscribeCoffieClean/Helpers/RegionService.swift
```

**Обновить RegionService:**

```swift
// В RegionService.swift
// Обновить для использования RPC get_all_regions

func fetchRegions() async throws {
    let response = try await client
        .rpc("get_all_regions", params: ["p_include_inactive": false])
        .execute()
    
    let data = response.data
    let fetchedRegions = try JSONDecoder().decode([Region].self, from: data)
    
    await MainActor.run {
        self.regions = fetchedRegions
        self.isLoading = false
    }
}
```

---

### Фаза 4: iOS - UI компоненты 🎨

#### 4.1. Создать CafeRecommendationsView

**Файл: `Views/CafeRecommendationsView.swift`**

```swift
import SwiftUI

struct CafeRecommendationsView: View {
    let recommendations: [CafeRecommendation]
    let onSelectCafe: (UUID) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Рекомендуем попробовать")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recommendations) { recommendation in
                        CafeRecommendationCard(
                            recommendation: recommendation,
                            onTap: { onSelectCafe(recommendation.cafeId) }
                        )
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct CafeRecommendationCard: View {
    let recommendation: CafeRecommendation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Cafe icon
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title)
                    .foregroundColor(.brown)
                
                // Cafe name
                Text(recommendation.cafeName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Reason
                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Score badge
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text("\(Int(recommendation.score))")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
            }
            .frame(width: 150)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
```

#### 4.2. Создать TrendingItemsView

**Файл: `Views/TrendingItemsView.swift`**

```swift
import SwiftUI

struct TrendingItemsView: View {
    let items: [TrendingItem]
    let onSelectItem: (TrendingItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("В тренде")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        TrendingItemCard(
                            item: item,
                            onTap: { onSelectItem(item) }
                        )
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct TrendingItemCard: View {
    let item: TrendingItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Item icon
                Image(systemName: categoryIcon(for: item.category))
                    .font(.title2)
                    .foregroundColor(.brown)
                
                // Item title
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Cafe name
                Text(item.cafeName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Stats
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(item.orderCount)")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
                
                // Price
                Text("\(item.priceCredits) кр.")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
            .frame(width: 140)
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "drinks": return "cup.and.saucer.fill"
        case "food": return "fork.knife"
        case "desserts": return "birthday.cake.fill"
        default: return "bag.fill"
        }
    }
}
```

#### 4.3. Восстановить RegionPickerView

```bash
cd SubscribeCoffieClean
mv _disabled_backup/RegionPickerView.swift.disabled \
   SubscribeCoffieClean/SubscribeCoffieClean/Views/RegionPickerView.swift
```

---

### Фаза 5: iOS - Восстановление MapSelectionView ✨

#### 5.1. Сделать резервную копию текущего stub

```bash
cd SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieClean/Views
mv MapSelectionView.swift MapSelectionView.swift.stub
```

#### 5.2. Восстановить полную версию

```bash
cp ../../../_disabled_backup/MapSelectionView.swift.disabled MapSelectionView.swift
```

#### 5.3. Обновить MapSelectionView для опциональных зависимостей

**Изменить инициализатор:**

```swift
struct MapSelectionView: View {
    let cafes: [CafeSummary]
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    let onSelectCafe: (CafeSummary) -> Void
    
    // ✅ Сделать filterStore опциональным
    var filterStore: FilterStore? = nil
    
    // ✅ Сделать рекомендации опциональными (отключаемыми)
    var enableRecommendations: Bool = false
    
    // ✅ Сделать регионы опциональными (отключаемыми)
    var enableRegions: Bool = false
    
    @State private var mode: DisplayMode = .list
    @State private var searchText: String = ""
    @State private var isFilterPresented: Bool = false
    
    // Recommendations (optional)
    @State private var cafeRecommendations: [CafeRecommendation] = []
    @State private var trendingItems: [TrendingItem] = []
    @State private var isLoadingRecommendations = false
    @StateObject private var recommendationService = RecommendationService()
    
    // Region filtering (optional)
    @StateObject private var regionService = RegionService()
    @State private var selectedRegion: Region?
    
    // ... rest of implementation
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                Text("Выберите кофейню")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Region picker (только если включено)
                if enableRegions {
                    RegionPickerView(
                        regionService: regionService,
                        selectedRegion: $selectedRegion
                    )
                }
                
                searchBar
                
                // Filter bar (только если filterStore передан)
                if filterStore != nil {
                    filterBar
                }
                
                // Recommendations (только если включено)
                if enableRecommendations && !isLoadingRecommendations {
                    if !cafeRecommendations.isEmpty {
                        CafeRecommendationsView(
                            recommendations: cafeRecommendations,
                            onSelectCafe: handleRecommendedCafe
                        )
                    }
                    
                    if !trendingItems.isEmpty {
                        TrendingItemsView(
                            items: trendingItems,
                            onSelectItem: handleTrendingItem
                        )
                    }
                }
                
                // ... rest of UI
            }
        }
        .task {
            if enableRecommendations {
                await loadRecommendations()
            }
            if enableRegions {
                try? await regionService.fetchRegions()
            }
        }
    }
    
    // Обновить sortedCafes для работы с опциональным filterStore
    private var sortedCafes: [CafeSummary] {
        guard let store = filterStore else {
            return filteredCafes // Без сортировки если нет filterStore
        }
        
        let sorted = filteredCafes.sorted { lhs, rhs in
            switch store.state.sortKey {
            case .distance:
                return lhs.distanceMinutes < rhs.distanceMinutes
            case .rating:
                return ratingScore(for: lhs) < ratingScore(for: rhs)
            case .avgCheck:
                return avgCheckScore(for: lhs) < avgCheckScore(for: rhs)
            }
        }
        
        if store.state.sortOrder == .ascending {
            return sorted
        }
        return Array(sorted.reversed())
    }
    
    private var filterBar: some View {
        guard let store = filterStore else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            HStack {
                Text(store.state.summaryTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    isFilterPresented = true
                } label: {
                    Label("Фильтры", systemImage: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(.plain)
            }
        )
    }
}
```

---

### Фаза 6: iOS - Обновление ContentView 🔗

#### 6.1. Передать filterStore в MapSelectionView

**Обновить в `ContentView.swift`:**

```swift
case .map:
    MapSelectionView(
        cafes: availableCafes,
        isLoading: cafesAreLoading,
        errorMessage: cafesLoadError,
        onRetry: {
            Task { await fetchCafesIfNeeded(force: true) }
        },
        onSelectCafe: { cafe in
            if isSelectingWalletCafe {
                pendingWalletScopeId = cafe.id.uuidString
                pendingWalletScopeName = cafe.name
                walletTopUpType = .cafe_wallet
                walletTopUpScopeTitle = cafe.name
                isWalletTopUpPresented = true
                isSelectingWalletCafe = false
            } else {
                Task {
                    await handleCafeSelection(cafe, persistLastCafe: true)
                }
            }
        },
        filterStore: filterStore,  // ✅ Передаём filterStore
        enableRecommendations: false,  // ⚠️ Пока отключаем
        enableRegions: true  // ✅ Включаем регионы
    )
    .task {
        await fetchCafesIfNeeded()
    }

case .selectCafeForWallet:
    MapSelectionView(
        cafes: availableCafes,
        isLoading: cafesAreLoading,
        errorMessage: cafesLoadError,
        onRetry: {
            Task { await fetchCafesIfNeeded(force: true) }
        },
        onSelectCafe: { cafe in
            Task {
                await handleCafeWalletSelection(cafe)
            }
        },
        filterStore: filterStore,  // ✅ Передаём filterStore
        enableRecommendations: false,
        enableRegions: true
    )
    .task {
        await fetchCafesIfNeeded()
    }
```

---

### Фаза 7: Тестирование 🧪

#### 7.1. Backend тестирование

```bash
cd SubscribeCoffieBackend

# Тест 1: Проверить regions
psql "$DATABASE_URL" -c "SELECT * FROM public.regions;"

# Тест 2: Проверить cafe_regions
psql "$DATABASE_URL" -c "SELECT c.name, r.name as region FROM cafes c JOIN cafe_regions cr ON c.id = cr.cafe_id JOIN regions r ON cr.region_id = r.id;"

# Тест 3: Проверить RPC get_all_regions
psql "$DATABASE_URL" -c "SELECT * FROM get_all_regions(false);"

# Тест 4: Проверить trending_items
psql "$DATABASE_URL" -c "SELECT * FROM trending_items LIMIT 5;"
```

#### 7.2. iOS тестирование

**Чеклист:**
- [ ] Приложение запускается без ошибок
- [ ] MapSelectionView отображается
- [ ] Переключатель "Список/Карта" работает
- [ ] Поиск фильтрует кофейни
- [ ] Фильтры открываются и применяются
- [ ] Регионы загружаются
- [ ] Region picker отображается и работает
- [ ] Кофейни фильтруются по региону (если backend готов)
- [ ] Нет крашей при отсутствии рекомендаций
- [ ] Клик на кофейню открывает меню

---

## 📝 Поэтапное включение функций

### Этап 1: Минимальный (без backend изменений)
✅ Можно сделать прямо сейчас:
- Восстановить MapSelectionView
- Включить поиск
- Включить переключатель Список/Карта
- Включить фильтры (FilterStore)
- **НЕ включать** рекомендации
- **НЕ включать** регионы

### Этап 2: С регионами (требует backend)
⚠️ Требует миграции multiregion:
- Все из Этапа 1
- + Включить RegionService
- + Включить RegionPickerView
- + Добавить seed data для регионов

### Этап 3: С рекомендациями (требует backend)
⚠️ Требует миграции recommendations:
- Все из Этапа 2
- + Включить RecommendationService
- + Включить CafeRecommendationsView
- + Включить TrendingItemsView
- + Добавить seed data для рекомендаций

---

## 🚀 Быстрый старт

### Вариант A: Полное восстановление (рекомендую)

```bash
# 1. Backend
cd SubscribeCoffieBackend/supabase/migrations
mv 20260220000000_multiregion.sql.disabled 20260220000000_multiregion.sql
mv 20260212000000_recommendations.sql.disabled 20260212000000_recommendations.sql

cd ../..
npx supabase db reset

# 2. iOS
cd SubscribeCoffieClean

# Восстановить Services
mv _disabled_backup/RecommendationService.swift.disabled \
   SubscribeCoffieClean/SubscribeCoffieClean/Helpers/RecommendationService.swift
   
mv _disabled_backup/RegionService.swift.disabled \
   SubscribeCoffieClean/SubscribeCoffieClean/Helpers/RegionService.swift

# Восстановить Views
mv _disabled_backup/RegionPickerView.swift.disabled \
   SubscribeCoffieClean/SubscribeCoffieClean/Views/RegionPickerView.swift

# Создать новые Views (CafeRecommendationsView, TrendingItemsView)
# См. Фазу 4

# Восстановить MapSelectionView
cd SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieClean/Views
mv MapSelectionView.swift MapSelectionView.swift.stub
cp ../../../_disabled_backup/MapSelectionView.swift.disabled MapSelectionView.swift

# Обновить ContentView (см. Фазу 6)

# 3. Запуск
open SubscribeCoffieClean/SubscribeCoffieClean.xcodeproj
# Build & Run
```

### Вариант B: Минимальное восстановление (без backend)

```bash
cd SubscribeCoffieClean/SubscribeCoffieClean/SubscribeCoffieClean/Views

# Backup текущего
mv MapSelectionView.swift MapSelectionView.swift.stub

# Восстановить полную версию
cp ../../../_disabled_backup/MapSelectionView.swift.disabled MapSelectionView.swift

# Отредактировать MapSelectionView:
# - Закомментировать RecommendationService
# - Закомментировать RegionService
# - Оставить только поиск, фильтры, переключатель

# Обновить ContentView для передачи filterStore
```

---

## ⚠️ Важные замечания

1. **Рекомендации требуют данных**: Для показа рекомендаций нужна история заказов
2. **Регионы требуют маппинга**: Кафе должны быть назначены регионам через `cafe_regions`
3. **Карта - заглушка**: Полноценная карта требует MapKit интеграции
4. **Обратная совместимость**: Stub-версия остаётся в `.stub` файле

---

## 📚 Связанная документация

- `MULTIREGION_IMPLEMENTATION.md` - Детали по регионам
- `RECOMMENDATIONS_IMPLEMENTATION.md` - Детали по рекомендациям
- `FilterStore.swift` - Реализация фильтров
- `ContentView.swift` - Главный контроллер навигации

---

## ✅ Критерии готовности

### Backend готов если:
- [x] Таблица `regions` создана
- [x] Таблица `cafe_regions` создана
- [x] RPC `get_all_regions` работает
- [x] Seed data для регионов создан
- [x] Таблица `user_preferences` создана (для рекомендаций)
- [x] View `trending_items` создан
- [x] RPC `get_cafe_recommendations` работает

### iOS готов если:
- [x] MapSelectionView восстановлен
- [x] FilterStore передаётся из ContentView
- [x] RegionService восстановлен
- [x] RegionPickerView работает
- [x] Поиск работает
- [x] Фильтры применяются
- [x] Переключатель Список/Карта работает
- [x] Нет крашей

---

## 🎯 Следующие шаги после восстановления

1. **Геолокация**: Добавить реальное определение местоположения
2. **Реальная карта**: Интегрировать MapKit вместо заглушки
3. **Персонализация**: Улучшить алгоритм рекомендаций
4. **Кэширование**: Добавить локальное кэширование регионов/кафе
5. **Аналитика**: Добавить трекинг действий пользователя

---

**Готов начать восстановление? Дай команду!** 🚀

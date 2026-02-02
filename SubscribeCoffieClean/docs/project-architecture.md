# Архитектура проекта SubscribeCoffieClean

## Обзор

Приложение использует MVVM-подобную архитектуру с ObservableObject stores для управления состоянием.

## Структура проекта

```
SubscribeCoffieClean/
├── Models/              # Модели данных и бизнес-логика
│   ├── Stores/         # ObservableObject для состояния
│   └── Data Models/    # Структуры данных
├── Views/              # Основные экраны приложения
├── Components/         # Переиспользуемые UI компоненты
└── Helpers/            # Утилиты и сервисы
```

## Data Flow

```
User Action → View → Store → Published Property → View Update
```

### Пример: Добавление товара в корзину

1. **View**: `ProductDetailView` - пользователь нажимает "Добавить"
2. **Action**: Вызывается `cart.add(product:configuration:)`
3. **Store**: `CartStore` обновляет `@Published var items`
4. **Update**: Все View с `@ObservedObject var cart` автоматически обновляются

## Stores (ViewModels)

### CartStore
- **Назначение**: Управление корзиной покупок
- **Состояние**: `@Published var items: [CartItem]`
- **Методы**: `add()`, `remove()`, `increment()`, `decrement()`, `reset()`
- **Использование**: Передается в `CafeView`, `CartView`, `CheckoutView`

### OrderStore
- **Назначение**: Управление заказами
- **Состояние**: `@Published var activeOrder: Order?`
- **Методы**: `placeOrder()`, `cancelOrder()`, `reset()`
- **Использование**: Используется в `CheckoutView`, `OrderStatusView`

### WalletStore
- **Назначение**: Управление балансом и бонусами
- **Состояние**: `@Published var credits`, `@Published var bonuses`
- **Методы**: `refund()`, `deduct()`, `addBonus()`
- **Использование**: Используется в `CheckoutView`, `ProfileView`

## Navigation Flow

```
LoginView
  ↓ (авторизация)
ProfileSetupView (если новый пользователь)
  ↓
OnboardingView
  ↓
MapSelectionView
  ↓ (выбор кофейни)
CafeView
  ↓ (добавление товаров)
CartView
  ↓ (оформление)
CheckoutView
  ↓ (подтверждение)
OrderStatusView
  ↓ (возврат)
CafeView
```

## State Management

### Локальное состояние (@State)
- Используется для UI состояния внутри одного View
- Примеры: `isLoading`, `selectedCategory`, `isPresented`

### Глобальное состояние (@StateObject/@ObservedObject)
- Stores создаются через `@StateObject` в родительском View
- Передаются дочерним View через `@ObservedObject`
- Пример: `CartStore` создается в `ContentView`, передается в `CafeView`

### Персистентное состояние (@AppStorage)
- Используется для простых значений, которые нужно сохранять
- Префикс ключей: `sc_` (SubscribeCoffie)
- Примеры: `sc_isLoggedIn`, `sc_phone`, `sc_fullName`

## Компоненты

### Переиспользуемые компоненты
- `TopBarView` - верхняя панель навигации
- `CafeMenuItemView` - элемент меню кофейни
- `QRCodeView` - отображение QR кода
- `SubscriptionOptionView` - опция подписки

### Приватные компоненты
- Создаются в том же файле что и основной View
- Используют `private struct`
- Разделяются `MARK:` комментариями

## Моки и тестовые данные

### MockCafeService
- Предоставляет тестовые данные для разработки
- Методы: `demoCafes()`, `menu(for:)`, `sampleMenu()`
- Используется вместо реального API

## Best Practices в проекте

### 1. MARK комментарии
```swift
// MARK: - Properties
// MARK: - Computed Properties
// MARK: - Body
// MARK: - Private Methods
```

### 2. Именование
- Views: `CafeView`, `CartView`
- Stores: `CartStore`, `OrderStore`
- Models: `CartItem`, `Product`

### 3. Структура файла
```swift
struct MyView: View {
    // MARK: - Properties
    // MARK: - Computed Properties
    // MARK: - Body
    // MARK: - Private Methods
    // MARK: - Private Views
}
```

### 4. Разделение ответственности
- Views отвечают только за UI
- Stores содержат бизнес-логику
- Models описывают данные

## Расширение архитектуры

### Добавление нового Store
1. Создай файл в `Models/`
2. Наследуйся от `ObservableObject`
3. Используй `@Published` для состояния
4. Создай через `@StateObject` в родительском View

### Добавление нового экрана
1. Создай View в `Views/`
2. Добавь case в `AppScreen` enum в `ContentView`
3. Добавь навигацию в `handleBack()` и `body`
4. Следуй существующей структуре MARK комментариев

### Добавление нового компонента
1. Если переиспользуемый - в `Components/`
2. Если приватный - в том же файле с `private struct`
3. Используй существующие стили и паттерны

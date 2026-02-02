# SwiftUI Patterns & Anti-Patterns

## Рекомендуемые паттерны

### 1. View Composition
```swift
// ✅ Хорошо: разбивай на маленькие компоненты
struct CafeView: View {
    var body: some View {
        VStack {
            CafeHeader()
            CafeMenu()
            CafeFooter()
        }
    }
}

private struct CafeHeader: View { ... }
private struct CafeMenu: View { ... }
```

### 2. State Lifting
```swift
// ✅ Поднимай состояние наверх когда нужно
struct ParentView: View {
    @State private var selectedItem: Item?
    
    var body: some View {
        ChildView(selectedItem: $selectedItem)
    }
}
```

### 3. Environment Objects
```swift
// ✅ Используй для глобального состояния
@main
struct App: SwiftUI.App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
```

### 4. View Modifiers
```swift
// ✅ Создавай кастомные модификаторы для переиспользования
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
```

### 5. ViewBuilder
```swift
// ✅ Используй @ViewBuilder для гибких компонентов
struct ContainerView<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack {
            content
        }
    }
}
```

## Анти-паттерны (чего избегать)

### 1. ❌ Слишком большие View
```swift
// ❌ Плохо: один огромный body
struct BadView: View {
    var body: some View {
        // 500+ строк кода
    }
}

// ✅ Хорошо: разбивай на компоненты
```

### 2. ❌ Неправильное использование @StateObject
```swift
// ❌ Плохо: создание в body
var body: some View {
    let store = CartStore() // Создается каждый раз!
}

// ✅ Хорошо: создание на уровне View
@StateObject private var store = CartStore()
```

### 3. ❌ Тяжелые вычисления в body
```swift
// ❌ Плохо
var body: some View {
    let expensive = computeExpensiveValue() // Вычисляется каждый раз!
    Text("\(expensive)")
}

// ✅ Хорошо: используй computed property или @State
private var expensive: Int {
    _cached ?? computeValue()
}
```

### 4. ❌ Избыточные пересоздания
```swift
// ❌ Плохо: создание массива в body
var body: some View {
    ForEach(Array(0..<100)) { ... } // Создается каждый раз!
}

// ✅ Хорошо: вынеси в computed property
private var items: [Int] { Array(0..<100) }
```

### 5. ❌ Неправильная работа с опционалами
```swift
// ❌ Плохо: force unwrap
Text(optionalString!)

// ✅ Хорошо: безопасная обработка
if let text = optionalString {
    Text(text)
}
```

## Navigation Patterns

### 1. Enum-based Navigation
```swift
enum AppScreen {
    case login
    case home
    case profile
}

struct ContentView: View {
    @State private var currentScreen: AppScreen = .login
    
    var body: some View {
        switch currentScreen {
        case .login: LoginView()
        case .home: HomeView()
        case .profile: ProfileView()
        }
    }
}
```

### 2. NavigationStack (iOS 16+)
```swift
struct ContentView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    route.view
                }
        }
    }
}
```

## Data Flow Patterns

### 1. Unidirectional Data Flow
```swift
// ✅ Данные текут в одном направлении
struct ProductView: View {
    @ObservedObject var store: ProductStore
    
    var body: some View {
        Button("Add") {
            store.addProduct() // Action -> Store -> View обновляется
        }
    }
}
```

### 2. Binding Pattern
```swift
// ✅ Используй Binding для двусторонней связи
struct TextFieldView: View {
    @Binding var text: String
    
    var body: some View {
        TextField("Enter text", text: $text)
    }
}
```

## Performance Patterns

### 1. Lazy Loading
```swift
// ✅ Используй LazyVStack для длинных списков
LazyVStack {
    ForEach(items) { item in
        ItemView(item: item)
    }
}
```

### 2. Equatable для оптимизации
```swift
// ✅ Реализуй Equatable для предотвращения лишних обновлений
struct Product: Identifiable, Equatable {
    let id: UUID
    let name: String
    
    static func == (lhs: Product, rhs: Product) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}
```

### 3. Identifiable для списков
```swift
// ✅ Всегда используй Identifiable для ForEach
struct Item: Identifiable {
    let id: UUID
    let name: String
}

ForEach(items) { item in
    ItemView(item: item)
}
```

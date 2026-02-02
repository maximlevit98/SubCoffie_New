# Swift & SwiftUI Best Practices

## Swift Language Best Practices

### 1. Optionals
```swift
// ✅ Хорошо: используй guard let для раннего выхода
guard let value = optionalValue else { return }
print(value)

// ❌ Плохо: force unwrap
print(optionalValue!)
```

### 2. Error Handling
```swift
// ✅ Хорошо: используй Result или throws
func fetchData() throws -> Data { ... }
do {
    let data = try fetchData()
} catch {
    print("Error: \(error)")
}

// ✅ Или Result
func fetchData() -> Result<Data, Error> { ... }
```

### 3. Memory Management
```swift
// ✅ Используй weak/unowned для избежания retain cycles
class ViewController {
    weak var delegate: SomeDelegate?
    
    lazy var closure: () -> Void = { [weak self] in
        self?.doSomething()
    }
}
```

### 4. Type Safety
```swift
// ✅ Используй конкретные типы вместо Any
let items: [String] = []
// ❌ let items: [Any] = []
```

## SwiftUI Best Practices

### 1. View Composition
```swift
// ✅ Разбивай большие View на компоненты
struct ProfileView: View {
    var body: some View {
        VStack {
            ProfileHeader()
            ProfileContent()
            ProfileFooter()
        }
    }
}

// ✅ Используй приватные View в том же файле
private struct ProfileHeader: View { ... }
```

### 2. State Management
```swift
// ✅ Правильное использование property wrappers
@StateObject private var store = CartStore()  // Создание
@ObservedObject var store: CartStore          // Передача
@State private var isPresented = false        // Локальное состояние
@AppStorage("key") private var value = ""     // Персистентность
```

### 3. Performance Optimization
```swift
// ✅ Lazy загрузка для списков
LazyVStack {
    ForEach(items) { item in
        ItemView(item: item)
    }
}

// ✅ Избегай лишних вычислений
private var expensiveValue: Int {
    // Кэшируй если нужно
    _expensiveValue ?? computeValue()
}
```

### 4. Animations
```swift
// ✅ Используй withAnimation для плавных переходов
withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
    state = newState
}

// ✅ Анимируй только необходимые свойства
.animation(.easeInOut, value: isVisible)
```

### 5. Modifiers Order
```swift
// ✅ Порядок модификаторов важен
Text("Hello")
    .font(.title)           // Сначала стиль
    .foregroundColor(.blue) // Потом цвет
    .padding()              // Потом layout
    .background(.ultraThinMaterial) // Потом фон
```

## Architecture Patterns

### MVVM в SwiftUI
```swift
// Model
struct Product: Identifiable {
    let id: UUID
    let name: String
}

// ViewModel (Store)
class ProductStore: ObservableObject {
    @Published var products: [Product] = []
    
    func loadProducts() { ... }
}

// View
struct ProductView: View {
    @StateObject private var store = ProductStore()
    
    var body: some View { ... }
}
```

### Dependency Injection
```swift
// ✅ Передавай зависимости через инициализатор
struct ProductView: View {
    let store: ProductStore
    
    init(store: ProductStore = ProductStore()) {
        self.store = store
    }
}
```

## Code Organization

### File Structure
```
Models/
  ├── Product.swift
  ├── CartItem.swift
  └── Stores/
      ├── CartStore.swift
      └── OrderStore.swift

Views/
  ├── ProductView.swift
  └── CartView.swift

Components/
  ├── ProductCard.swift
  └── TopBar.swift
```

### MARK Comments
```swift
struct MyView: View {
    // MARK: - Properties
    let data: Data
    
    // MARK: - Computed Properties
    private var computed: Int { ... }
    
    // MARK: - Body
    var body: some View { ... }
    
    // MARK: - Private Methods
    private func helper() { ... }
}
```

## Testing

### Preview
```swift
#Preview {
    ProductView(store: MockProductStore())
        .previewDisplayName("Product View")
}
```

### Unit Tests
```swift
func testCartAddItem() {
    let cart = CartStore()
    let product = Product(id: UUID(), name: "Coffee")
    cart.add(product: product)
    XCTAssertEqual(cart.items.count, 1)
}
```

## Common Pitfalls

1. **Retain Cycles**: Всегда используй `[weak self]` в closures
2. **Force Unwrapping**: Избегай `!`, используй `guard let` или `if let`
3. **Heavy Computations**: Не делай тяжелые вычисления в `body`
4. **Too Many Views**: Разбивай большие View на компоненты
5. **State Management**: Не создавай `@StateObject` в цикле или условии

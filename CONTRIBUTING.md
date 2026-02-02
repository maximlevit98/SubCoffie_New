# 🤝 Contributing to Subscribe Coffee

Спасибо за интерес к улучшению Subscribe Coffee! Мы приветствуем вклад от всех.

## 📋 Содержание

- [Code of Conduct](#code-of-conduct)
- [Как начать](#как-начать)
- [Процесс разработки](#процесс-разработки)
- [Стандарты кода](#стандарты-кода)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)

## 🤝 Code of Conduct

Участвуя в этом проекте, вы соглашаетесь соблюдать уважительное и профессиональное поведение.

## 🚀 Как начать

### 1. Fork и Clone репозитория

```bash
# Fork репозитория на GitHub
# Затем клонируйте свой fork
git clone https://github.com/YOUR_USERNAME/subscribe-coffee.git
cd subscribe-coffee
```

### 2. Настройка upstream remote

```bash
git remote add upstream https://github.com/ORIGINAL_OWNER/subscribe-coffee.git
git fetch upstream
```

### 3. Установка зависимостей

#### Backend
```bash
cd SubscribeCoffieBackend
npm install
```

#### iOS App
```bash
cd SubscribeCoffieClean
# Откройте .xcodeproj в Xcode
```

#### Admin Panel
```bash
cd subscribecoffie-admin
npm install
```

## 💻 Процесс разработки

### 1. Создайте feature branch

```bash
git checkout -b feature/your-feature-name
# или
git checkout -b fix/your-bug-fix
```

### 2. Внесите изменения

- Пишите чистый, понятный код
- Следуйте существующим стандартам кодирования
- Добавляйте комментарии где необходимо
- Обновляйте документацию при необходимости

### 3. Тестируйте изменения

#### Backend
```bash
cd SubscribeCoffieBackend
npm test
```

#### iOS
```bash
cd SubscribeCoffieClean
# Run tests in Xcode (Cmd+U)
```

#### Admin
```bash
cd subscribecoffie-admin
npm run lint
npm run build
```

### 4. Коммитьте изменения

```bash
git add .
git commit -m "type: brief description"
```

## 📝 Стандарты кода

### Swift (iOS)

- Следуйте [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Используйте SwiftLint для проверки кода
- Именуйте переменные и функции в camelCase
- Именуйте типы в PascalCase
- Избегайте force unwrapping (!)

```swift
// ✅ Good
func fetchUserData() async throws -> User {
    guard let url = URL(string: endpoint) else {
        throw NetworkError.invalidURL
    }
    // ...
}

// ❌ Bad
func FetchUserData() -> User! {
    let url = URL(string: endpoint)!
    // ...
}
```

### TypeScript/JavaScript (Backend & Admin)

- Используйте TypeScript для типобезопасности
- Следуйте ESLint правилам
- Используйте async/await вместо callbacks
- Именуйте переменные и функции в camelCase
- Именуйте классы и типы в PascalCase

```typescript
// ✅ Good
async function fetchUserData(): Promise<User> {
  try {
    const response = await fetch(endpoint);
    return await response.json();
  } catch (error) {
    console.error('Failed to fetch user:', error);
    throw error;
  }
}

// ❌ Bad
function FetchUserData(callback) {
  fetch(endpoint).then(response => {
    callback(response.json());
  }).catch(err => {});
}
```

### SQL/Database

- Используйте snake_case для таблиц и колонок
- Добавляйте индексы для часто используемых полей
- Документируйте сложные запросы
- Используйте transactions где необходимо

```sql
-- ✅ Good
CREATE TABLE user_subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id),
  subscription_type TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_user_subscriptions_user_id ON user_subscriptions(user_id);
```

## 📦 Commit Guidelines

Используйте [Conventional Commits](https://www.conventionalcommits.org/):

### Формат

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: Новая функция
- `fix`: Исправление бага
- `docs`: Изменения в документации
- `style`: Форматирование, пробелы (не влияет на код)
- `refactor`: Рефакторинг кода
- `test`: Добавление или изменение тестов
- `chore`: Обслуживание (зависимости, конфиг и т.д.)
- `perf`: Улучшение производительности

### Scope (опционально)

- `backend`: Backend изменения
- `ios`: iOS app изменения
- `admin`: Admin panel изменения
- `db`: Database изменения
- `auth`: Authentication изменения

### Примеры

```bash
feat(ios): Add coffee subscription view
fix(backend): Fix order creation validation
docs: Update README with setup instructions
refactor(admin): Simplify cafe management logic
test(backend): Add tests for payment processing
chore: Update dependencies
```

## 🔄 Pull Request Process

### 1. Обновите свой branch

```bash
git fetch upstream
git rebase upstream/main
```

### 2. Push в ваш fork

```bash
git push origin feature/your-feature-name
```

### 3. Создайте Pull Request

- Откройте GitHub и перейдите к вашему fork
- Нажмите "New Pull Request"
- Выберите ваш branch
- Заполните PR template

### 4. PR Template

```markdown
## Описание
Краткое описание изменений

## Тип изменений
- [ ] Bug fix (non-breaking change)
- [ ] New feature (non-breaking change)
- [ ] Breaking change (fix or feature)
- [ ] Documentation update

## Затронутые компоненты
- [ ] Backend
- [ ] iOS App
- [ ] Admin Panel
- [ ] Database

## Как протестировано?
Опишите тесты, которые вы провели

## Checklist
- [ ] Код следует стилю проекта
- [ ] Добавлены/обновлены тесты
- [ ] Все тесты проходят
- [ ] Документация обновлена
- [ ] Нет merge конфликтов
```

### 5. Code Review

- Ваш PR будет рассмотрен мейнтейнерами
- Отвечайте на комментарии и вносите изменения при необходимости
- После одобрения PR будет слит в main

## 🐛 Reporting Bugs

### Перед созданием issue

1. Проверьте существующие issues
2. Убедитесь, что баг воспроизводится
3. Соберите информацию об окружении

### Bug Report Template

```markdown
**Описание бага**
Четкое описание проблемы

**Шаги для воспроизведения**
1. Перейти к '...'
2. Нажать на '....'
3. Увидеть ошибку

**Ожидаемое поведение**
Что должно было произойти

**Скриншоты**
Если применимо

**Окружение:**
 - Компонент: [Backend/iOS/Admin]
 - Версия: [e.g. 1.0.0]
 - OS: [e.g. iOS 17.0, macOS 14.0]
 - Device: [e.g. iPhone 15 Pro]
```

## 💡 Feature Requests

Мы приветствуем предложения новых функций!

### Feature Request Template

```markdown
**Описание функции**
Четкое описание желаемой функции

**Проблема, которую это решает**
Объясните проблему

**Предлагаемое решение**
Как вы видите реализацию

**Альтернативы**
Какие альтернативы вы рассматривали

**Дополнительный контекст**
Любая дополнительная информация
```

## 📚 Дополнительные ресурсы

### Документация проекта

- [Backend API Documentation](./SubscribeCoffieBackend/SUPABASE_API_CONTRACT.md)
- [iOS Architecture](./SubscribeCoffieClean/docs/project-architecture.md)
- [Deployment Guide](./GITHUB_SETUP.md)

### Полезные ссылки

- [Swift Style Guide](https://google.github.io/swift/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Supabase Documentation](https://supabase.com/docs)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)

## 🎯 Приоритетные области для вклада

Мы особенно приветствуем вклад в следующих областях:

### Backend
- [ ] Улучшение API performance
- [ ] Добавление новых аналитических метрик
- [ ] Оптимизация database queries
- [ ] Улучшение error handling

### iOS
- [ ] Улучшение UI/UX
- [ ] Добавление unit tests
- [ ] Оптимизация performance
- [ ] Accessibility improvements

### Admin Panel
- [ ] Новые аналитические дашборды
- [ ] Улучшение UX
- [ ] Mobile responsiveness
- [ ] Dark mode support

## ❓ Вопросы?

Если у вас есть вопросы:

- 📧 Email: [email]
- 💬 Telegram: [telegram]
- 🐛 GitHub Issues: [создайте issue с меткой "question"]

---

**Спасибо за ваш вклад! ☕❤️**

Каждый PR, каждый issue, каждая идея делает Subscribe Coffee лучше!

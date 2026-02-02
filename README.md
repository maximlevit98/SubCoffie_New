# ☕ Subscribe Coffee

Полноценная платформа подписки на кофе с мобильным приложением (iOS), backend API и административной панелью.

## 📁 Структура проекта

```
SubscribeCoffie/
├── SubscribeCoffieBackend/     # Backend API (Node.js/Supabase)
├── SubscribeCoffieClean/        # iOS приложение (Swift/SwiftUI)
└── subscribecoffie-admin/       # Административная панель (Next.js/React)
```

## 🚀 Быстрый старт

### Backend Setup

```bash
cd SubscribeCoffieBackend
# Следуйте инструкциям в SubscribeCoffieBackend/README.md
```

📖 Документация:
- [Полная документация Backend](./SubscribeCoffieBackend/README.md)
- [Быстрый старт](./SubscribeCoffieBackend/BACKEND_FOUNDATION_COMPLETE.md)
- [Настройка Supabase](./SubscribeCoffieBackend/SUPABASE_SETUP.md)

### iOS приложение

```bash
cd SubscribeCoffieClean
# Следуйте инструкциям в SubscribeCoffieClean/README.md
```

📖 Документация:
- [Полная документация iOS](./SubscribeCoffieClean/README.md)
- [Тестирование](./SubscribeCoffieClean/README_TESTING.md)

### Административная панель

```bash
cd subscribecoffie-admin
npm install
npm run dev
```

## 🎯 Основные функции

### Для пользователей (iOS приложение)
- 🛒 Заказ кофе и напитков
- 📦 Управление подписками
- 🚚 Отслеживание доставки
- ⭐ Система лояльности
- 💳 Интеграция платежей
- 📍 Выбор кофеен по местоположению

### Для владельцев кофеен (Backend + Admin)
- 📊 Аналитика и статистика
- 📦 Управление заказами
- 👥 Управление клиентами
- 💼 Бизнес-отчеты
- 🔔 Уведомления в реальном времени

### Для администраторов (Admin панель)
- 🏢 Управление кофейнями
- 👤 Управление пользователями
- 📈 Глобальная аналитика
- ⚙️ Системные настройки

## 🛠 Технологический стек

### Backend
- **Runtime**: Node.js
- **Database**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth
- **Storage**: Supabase Storage
- **Real-time**: Supabase Realtime

### Frontend (iOS)
- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **Min iOS**: 16.0
- **Architecture**: MVVM + Clean Architecture

### Admin Panel
- **Framework**: Next.js 14+
- **UI**: React + Tailwind CSS
- **State Management**: React Query
- **Authentication**: Supabase Auth

## 📋 Требования

### Backend
- Node.js 18+
- Supabase account
- PostgreSQL 14+

### iOS
- Xcode 15+
- macOS 13+
- iOS 16+ device/simulator

### Admin Panel
- Node.js 18+
- npm/yarn/pnpm

## 🔐 Настройка окружения

Каждый компонент требует свои переменные окружения:

1. **Backend**: Копируйте `SubscribeCoffieBackend/env.production.template`
2. **iOS**: Настройте в Xcode project settings
3. **Admin**: Создайте `.env.local` в `subscribecoffie-admin/`

## 📚 Документация

### Backend
- [API Contract](./SubscribeCoffieBackend/SUPABASE_API_CONTRACT.md)
- [Authentication](./SubscribeCoffieBackend/AUTH_QUICKSTART.md)
- [Payments](./SubscribeCoffieBackend/PAYMENT_INTEGRATION.md)
- [Delivery System](./SubscribeCoffieBackend/DELIVERY_QUICKSTART.md)
- [Analytics](./SubscribeCoffieBackend/ANALYTICS_QUICKSTART.md)

### iOS
- [Architecture](./SubscribeCoffieClean/docs/project-architecture.md)
- [SwiftUI Patterns](./SubscribeCoffieClean/docs/swiftui-patterns.md)
- [Best Practices](./SubscribeCoffieClean/docs/swift-best-practices.md)

## 🧪 Тестирование

### Backend
```bash
cd SubscribeCoffieBackend
npm test
```

### iOS
```bash
cd SubscribeCoffieClean
./quick-run.sh test
```

## 🚀 Deployment

### Backend
```bash
# Следуйте инструкциям в:
# - CLOUD_DEPLOYMENT.md
# - PRODUCTION_CHECKLIST.md
```

### iOS
```bash
cd SubscribeCoffieClean
fastlane beta  # TestFlight
fastlane release  # App Store
```

### Admin Panel
```bash
cd subscribecoffie-admin
npm run build
# Deploy to Vercel/Netlify
```

## 🤝 Разработка

### Git workflow
```bash
# Создайте feature branch
git checkout -b feature/название-фичи

# Коммитьте изменения
git add .
git commit -m "feat: описание изменений"

# Push и создайте Pull Request
git push origin feature/название-фичи
```

### Commit conventions
- `feat:` - новая функция
- `fix:` - исправление бага
- `docs:` - изменения в документации
- `style:` - форматирование кода
- `refactor:` - рефакторинг
- `test:` - добавление тестов
- `chore:` - обслуживание проекта

## 📞 Контакты и поддержка

Для вопросов и поддержки:
- Backend issues: создайте issue с меткой `backend`
- iOS issues: создайте issue с меткой `ios`
- Admin issues: создайте issue с меткой `admin`

## 📄 Лицензия

[Добавьте информацию о лицензии]

## 🙏 Благодарности

Спасибо всем контрибьюторам проекта!

---

Made with ☕ and ❤️

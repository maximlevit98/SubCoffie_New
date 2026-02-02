#!/bin/bash

# Скрипт для запуска приложения в симуляторе из Cursor
# Использование: ./run-simulator.sh [имя_симулятора]

PROJECT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="SubscribeCoffieClean"
SCHEME="SubscribeCoffieClean"
SIMULATOR_NAME="${1:-iPhone 17 Pro}"

echo "🚀 Запуск $PROJECT_NAME в симуляторе $SIMULATOR_NAME..."

# Переходим в директорию проекта
cd "$PROJECT_PATH"

# Получаем UDID симулятора
SIMULATOR_UDID=$(xcrun simctl list devices available | grep "$SIMULATOR_NAME" | head -1 | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}')

if [ -z "$SIMULATOR_UDID" ]; then
    echo "❌ Симулятор '$SIMULATOR_NAME' не найден!"
    echo "Доступные симуляторы:"
    xcrun simctl list devices available | grep -i "iphone"
    exit 1
fi

echo "📱 Найден симулятор: $SIMULATOR_NAME ($SIMULATOR_UDID)"

# Запускаем симулятор
echo "🔧 Запуск симулятора..."
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || echo "Симулятор уже запущен"

# Открываем Simulator.app
open -a Simulator

# Ждем немного, чтобы симулятор успел запуститься
sleep 2

# Собираем и запускаем приложение
echo "🔨 Сборка проекта..."
xcodebuild \
    -project "$PROJECT_PATH/SubscribeCoffieClean/SubscribeCoffieClean.xcodeproj" \
    -scheme "$SCHEME" \
    -sdk iphonesimulator \
    -destination "id=$SIMULATOR_UDID" \
    clean build

if [ $? -eq 0 ]; then
    echo "✅ Сборка успешна!"
    echo "📲 Установка приложения в симулятор..."
    
    # Устанавливаем приложение
    xcodebuild \
        -project "$PROJECT_PATH/SubscribeCoffieClean/SubscribeCoffieClean.xcodeproj" \
        -scheme "$SCHEME" \
        -sdk iphonesimulator \
        -destination "id=$SIMULATOR_UDID" \
        install
    
    echo "✅ Готово! Приложение должно запуститься в симуляторе."
else
    echo "❌ Ошибка сборки!"
    exit 1
fi

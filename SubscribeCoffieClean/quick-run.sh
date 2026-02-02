#!/bin/bash

# Быстрый запуск приложения в симуляторе
# Использование: ./quick-run.sh

PROJECT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEME="SubscribeCoffieClean"
SIMULATOR_NAME="iPhone 17 Pro"

echo "🚀 Быстрый запуск приложения..."

cd "$PROJECT_PATH/SubscribeCoffieClean"

# Получаем UDID симулятора
SIMULATOR_UDID=$(xcrun simctl list devices available | grep "$SIMULATOR_NAME" | head -1 | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}')

if [ -z "$SIMULATOR_UDID" ]; then
    echo "❌ Симулятор '$SIMULATOR_NAME' не найден!"
    echo "Доступные симуляторы:"
    xcrun simctl list devices available | grep -i "iphone"
    exit 1
fi

echo "📱 Используем симулятор: $SIMULATOR_NAME"

# Запускаем симулятор
echo "🔧 Запуск симулятора..."
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || echo "Симулятор уже запущен"
open -a Simulator

# Ждем немного
sleep 2

# Собираем и запускаем приложение
echo "🔨 Сборка и запуск приложения..."
xcodebuild \
    -project SubscribeCoffieClean.xcodeproj \
    -scheme "$SCHEME" \
    -sdk iphonesimulator \
    -destination "id=$SIMULATOR_UDID" \
    build

if [ $? -eq 0 ]; then
    echo "✅ Сборка успешна!"
    echo "📲 Установка и запуск приложения..."
    
    # Находим путь к .app файлу в DerivedData (исключаем Index.noindex)
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "SubscribeCoffieClean.app" -type d -path "*/Build/Products/Debug-iphonesimulator/*" ! -path "*/Index.noindex/*" | head -1)
    
    # Получаем bundle identifier (дефолтный)
    BUNDLE_ID="SubscribeCoffieClean.SubscribeCoffieClean"
    
    if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
        echo "📦 Найден .app: $APP_PATH"
        
        # Пытаемся получить bundle ID из Info.plist
        if [ -f "$APP_PATH/Info.plist" ]; then
            BUNDLE_ID_FROM_PLIST=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null)
            if [ -n "$BUNDLE_ID_FROM_PLIST" ]; then
                BUNDLE_ID="$BUNDLE_ID_FROM_PLIST"
            fi
        fi
        
        # Пытаемся установить приложение (игнорируем ошибки, если уже установлено)
        echo "📥 Установка приложения..."
        xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH" 2>&1 | grep -v "already contains" || true
    else
        echo "⚠️  Не удалось найти .app файл, но попробуем запустить существующую установку..."
    fi
    
    echo "🆔 Bundle ID: $BUNDLE_ID"
    
    # Запускаем приложение (даже если установка не удалась, приложение может быть уже установлено)
    echo "🚀 Запуск приложения..."
    LAUNCH_OUTPUT=$(xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" 2>&1)
    
    if echo "$LAUNCH_OUTPUT" | grep -q ":"; then
        PID=$(echo "$LAUNCH_OUTPUT" | cut -d: -f2 | tr -d ' ')
        echo "✅ Приложение запущено! (PID: $PID)"
    else
        echo "✅ Приложение должно быть запущено в симуляторе!"
    fi
else
    echo "❌ Ошибка сборки!"
    exit 1
fi

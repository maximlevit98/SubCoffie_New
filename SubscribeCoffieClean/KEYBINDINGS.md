# Горячие клавиши для работы с проектом

## Настройка горячих клавиш в Cursor

Cursor позволяет настроить горячие клавиши для запуска команд. Вот как это сделать:

### Способ 1: Через Command Palette

1. Нажми `Cmd+Shift+P` (или `Ctrl+Shift+P` на Windows/Linux)
2. Введите "Preferences: Open Keyboard Shortcuts"
3. Нажмите на иконку карандаша рядом с нужной командой
4. Нажмите нужную комбинацию клавиш

### Способ 2: Через settings.json

1. Открой Command Palette (`Cmd+Shift+P`)
2. Введите "Preferences: Open User Settings (JSON)"
3. Добавьте настройки:

```json
{
  "key": "cmd+shift+r",
  "command": "workbench.action.terminal.sendSequence",
  "args": {
    "text": "./quick-run.sh\n"
  },
  "when": "terminalFocus"
}
```

## Рекомендуемые горячие клавиши

### Запуск приложения

| Действие | Горячая клавиша | Команда |
|----------|----------------|---------|
| Быстрый запуск | `Cmd+Shift+R` | `./quick-run.sh` |
| Запуск с выбором симулятора | `Cmd+Shift+S` | `./run-simulator.sh` |

### Полезные команды

| Действие | Горячая клавиша | Команда |
|----------|----------------|---------|
| Открыть терминал | `` Ctrl+` `` | - |
| Запустить сборку | `Cmd+Shift+B` | `xcodebuild build` |
| Показать симуляторы | `Cmd+Shift+L` | `xcrun simctl list devices` |

## Настройка через tasks.json

Создай файл `.vscode/tasks.json` (Cursor использует формат VS Code):

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Run Simulator",
      "type": "shell",
      "command": "./quick-run.sh",
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    },
    {
      "label": "List Simulators",
      "type": "shell",
      "command": "xcrun simctl list devices available",
      "problemMatcher": []
    }
  ]
}
```

Затем настрой горячую клавишу для задачи:
1. `Cmd+Shift+P` → "Tasks: Run Task"
2. Или настрой горячую клавишу для `workbench.action.tasks.runTask`

## Альтернатива: Использование терминала

Если не хочешь настраивать горячие клавиши, просто используй терминал:

```bash
# Быстрый запуск
./quick-run.sh

# Запуск с выбором симулятора
./run-simulator.sh "iPhone 17 Pro Max"

# Список доступных симуляторов
xcrun simctl list devices available
```

## Полезные команды Xcode

Если Xcode открыт, используй стандартные горячие клавиши:

| Действие | Горячая клавиша |
|----------|----------------|
| Запустить | `Cmd+R` |
| Остановить | `Cmd+.` |
| Собрать | `Cmd+B` |
| Очистить сборку | `Cmd+Shift+K` |
| Показать симуляторы | `Cmd+Shift+2` |

## Автоматизация через скрипты

Можешь создать дополнительные скрипты для частых задач:

```bash
# build.sh - только сборка
xcodebuild -project SubscribeCoffieClean/SubscribeCoffieClean.xcodeproj \
  -scheme SubscribeCoffieClean \
  -sdk iphonesimulator \
  build

# clean.sh - очистка
xcodebuild clean -project SubscribeCoffieClean/SubscribeCoffieClean.xcodeproj \
  -scheme SubscribeCoffieClean
```

Затем добавь их в `tasks.json` и настрой горячие клавиши.

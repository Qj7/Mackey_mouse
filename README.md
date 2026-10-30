# Mackey

Утилита в строке меню macOS. Колесо мыши и тачпад прокручиваются отдельно.

Системную «Естественную прокрутку» можно оставить включённой: тачпад и Magic Mouse не меняются. Mackey переворачивает только щелчки колеса и может сгладить их в непрерывное движение.

## Сборка

Нужен Xcode 16 или новее (macOS 14+).

```bash
./scripts/build-app.sh
open build/Mackey.app
```

`build-app.sh` собирает `build/Mackey.app` и копирует его в `/Applications`. Для сборки без установки: `./scripts/build-app.sh --no-install`.

При первом запуске система попросит доступ к управлению компьютером. Включите Mackey в «Универсальный доступ» и оставьте пункт «Включён» в меню иконки мыши.

После пересборки macOS может снова спросить доступ: подпись приложения меняется.

## Установочный .dmg

Для дистрибутива (перетаскивание в Applications):

```bash
./scripts/build-dmg.sh
```

Готовый файл: `build/Mackey-<версия>.dmg` (версия из `CFBundleShortVersionString` в `Info.plist`) и рядом `.sha256`.

Перед новым релизом обновите версию в `Info.plist`, затем снова запустите `./scripts/build-dmg.sh`. Если `.app` уже собран: `./scripts/build-dmg.sh --skip-build`.

## Preferences

Окно настроек: вкладки General и About. About содержит бесплатную лицензию. Правообладатели этого продукта — его автор и Auto.

- Smooth Scrolling включает плавную прокрутку колеса.
- Scroll Reverse переворачивает направление колеса. Тачпад не меняется.
- Dash (⌥ Option) увеличивает расстояние щелчка в четыре раза.
- Toggle (⇧ Shift) превращает вертикальный щелчок в горизонтальный.
- Block (⌘ Command) на время отключает сглаживание.
- Step задаёт расстояние одного щелчка, Speed — ускорение, Duration — длительность анимации.

## Лендинг

Сайт в `landing/` (Next.js). Локально: `cd landing && npm install && npm run dev`.

### Git + Vercel

Репозиторий содержит и macOS-приложение, и лендинг. На Vercel публикуется только `landing`:

1. Создайте remote и запушьте ветку `main`.
2. В [Vercel](https://vercel.com/new) импортируйте репозиторий.
3. Укажите **Root Directory = `landing`**.
4. Deploy — `npm install` / `npm run build` подставятся сами.

DMG для кнопки «Скачать» версионируется в `landing/public/` (не в `build/`).

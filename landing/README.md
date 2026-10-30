# Mackey landing

Лендинг приложения Mackey (Next.js). На Vercel деплоится из папки `landing`.

## Локально

```bash
cd landing
npm install
npm run dev
```

Откройте [http://localhost:3010](http://localhost:3010).

Продакшен-сборка:

```bash
npm run build && npm start
```

## Деплой на Vercel

1. Запушьте репозиторий на GitHub / GitLab / Bitbucket.
2. [Import Project](https://vercel.com/new) → выберите репозиторий.
3. **Root Directory:** `landing` (обязательно).
4. Framework: Next.js (подхватится сам). Build / Install / Output — по умолчанию.
5. Deploy.

CLI (из корня репо, после `npm i -g vercel`):

```bash
cd landing && vercel
```

## Фон

- `src/components/NetBackground.tsx`
- `src/components/net-scene.ts`

DMG для кнопки «Скачать» лежит в `public/Mackey-1.0.0.dmg` — обновите после нового релиза:

```bash
cp ../build/Mackey-*.dmg public/
```

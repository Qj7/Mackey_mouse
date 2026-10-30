export function Download() {
  return (
    <section className="relative border-t border-line py-24 md:py-32">
      <div className="mx-auto max-w-6xl px-6">
        <h2 className="font-display text-3xl font-semibold tracking-[-0.03em] md:text-4xl">
          Скачать Mackey Mouse
        </h2>
        <p className="mt-4 max-w-2xl text-lg text-muted">
          macOS&nbsp;14+. При первом запуске включите Mackey Mouse в «Универсальный доступ».
        </p>

        <div className="mt-10 flex flex-wrap items-center gap-4">
          <a
            href="/Mackey-1.0.0.dmg"
            download
            className="inline-flex items-center gap-2 rounded-full bg-accent px-7 py-4 font-semibold text-black transition-transform hover:scale-[1.03] active:scale-95"
          >
            Mackey-1.0.0.dmg
          </a>
          <p className="text-sm text-muted">Установщик: перетащите в Applications</p>
        </div>
      </div>
    </section>
  );
}

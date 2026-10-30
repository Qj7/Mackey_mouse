/** Замените на свой username на buymeacoffee.com */
const BUY_ME_A_COFFEE_URL = "https://www.buymeacoffee.com/mackeymouse";

export function Donate() {
  return (
    <section id="donate" className="relative border-t border-line py-24 md:py-32">
      <div className="mx-auto max-w-6xl px-6">
        <h2 className="font-display text-3xl font-semibold tracking-[-0.03em] md:text-4xl">
          Поддержать проект
        </h2>
        <p className="mt-4 max-w-2xl text-lg text-muted">
          Mackey Mouse бесплатный. Если утилита пригодилась — киньте доллар на кофе.
        </p>

        <div className="mt-12 flex flex-wrap items-center gap-5">
          <p className="font-display text-5xl font-semibold tracking-[-0.04em] text-accent md:text-6xl">
            $1
          </p>
          <a
            href={BUY_ME_A_COFFEE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2.5 rounded-full bg-[#FFDD00] px-7 py-4 font-semibold text-black transition-transform hover:scale-[1.03] active:scale-95"
          >
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden>
              <path
                d="M4 8h13v6a4 4 0 0 1-4 4H8a4 4 0 0 1-4-4V8Z"
                stroke="currentColor"
                strokeWidth="1.8"
              />
              <path
                d="M17 9h1.5a2.5 2.5 0 0 1 0 5H17"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
              />
              <path
                d="M8 4c.4 1 .4 2 0 3M11 4c.4 1 .4 2 0 3M14 4c.4 1 .4 2 0 3"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
              />
            </svg>
            Buy me a coffee
          </a>
        </div>
      </div>
    </section>
  );
}

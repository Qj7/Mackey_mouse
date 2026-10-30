import Image from "next/image";
import { NetBackground } from "./NetBackground";

const DMG = "/Mackey-1.0.0.dmg";

export function Hero() {
  return (
    <section className="noise relative isolate flex min-h-dvh flex-col justify-end overflow-hidden pb-16 pt-28 md:justify-center md:pb-24 md:pt-32">
      <div aria-hidden className="absolute inset-0 -z-10">
        <div className="absolute top-[-20%] left-[8%] size-[42rem] animate-aurora rounded-full bg-violet/35 blur-[120px]" />
        <div className="absolute top-[8%] right-[-12%] size-[34rem] animate-aurora rounded-full bg-brand/30 blur-[120px] [animation-delay:-6s]" />
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,transparent_0%,#08080b_78%)]" />
        <NetBackground />
      </div>

      <div className="mx-auto flex w-full max-w-6xl flex-col gap-10 px-6 md:gap-12">
        <div className="animate-rise flex items-center gap-4 [animation-delay:60ms]">
          <Image
            src="/app-icon.png"
            alt=""
            width={72}
            height={72}
            priority
            className="size-[4.5rem] rounded-[1.35rem] shadow-[0_18px_50px_rgb(124_92_255_/_0.45)]"
          />
          <p className="font-display text-4xl font-semibold tracking-[-0.04em] md:text-5xl">Mackey Mouse</p>
        </div>

        <div className="max-w-3xl">
          <h1 className="animate-rise font-display text-[clamp(2.1rem,6.2vw,4.4rem)] leading-[1.05] font-semibold tracking-[-0.03em] text-balance [animation-delay:140ms]">
            Исправления для&nbsp;колеса мыши на&nbsp;Mac
          </h1>
          <p className="animate-rise mt-6 max-w-xl text-lg leading-relaxed text-muted md:text-xl [animation-delay:240ms]">
            Утилита в строке меню macOS. Переворачивает и сглаживает только колесо мыши, не трогая
            естественную прокрутку тачпада.
          </p>

          <div className="animate-rise mt-10 flex flex-wrap gap-3 [animation-delay:340ms]">
            <a
              href={DMG}
              download
              className="group inline-flex items-center gap-2 rounded-full bg-accent px-7 py-4 font-semibold text-black transition-transform hover:scale-[1.03] active:scale-95"
            >
              Скачать 1.0.0
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2.2"
                aria-hidden
                className="transition-transform group-hover:translate-y-0.5"
              >
                <path d="M12 4v12M7 12l5 5 5-5M5 20h14" />
              </svg>
            </a>
            <a
              href="#how"
              className="inline-flex items-center rounded-full border border-line bg-white/[0.03] px-7 py-4 font-semibold backdrop-blur transition-colors hover:bg-white/[0.08]"
            >
              Как это работает
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}

import Image from "next/image";

export function HowItWorks() {
  return (
    <section id="how" className="relative border-t border-line py-24 md:py-32">
      <div className="mx-auto max-w-6xl px-6">
        <h2 className="font-display text-3xl font-semibold tracking-[-0.03em] md:text-4xl">
          Как это работает
        </h2>
        <p className="mt-4 max-w-2xl text-lg text-muted">
          Откройте Preferences из строки меню — reverse, сглаживание и модификаторы настраиваются здесь.
        </p>

        <div className="mt-14 flex justify-center md:mt-16">
          <Image
            src="/preferences.jpg"
            alt="Окно Preferences Mackey Mouse: Smooth Scrolling, Scroll Reverse, Dash, Toggle, Block, Step, Speed и Duration"
            width={986}
            height={1024}
            className="w-full max-w-md rounded-2xl shadow-[0_40px_100px_rgb(0_0_0_/_0.55)] ring-1 ring-white/10"
            sizes="(max-width: 768px) 100vw, 28rem"
            priority={false}
          />
        </div>
      </div>
    </section>
  );
}

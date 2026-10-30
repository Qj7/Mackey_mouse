"use client";

import { useEffect, useRef } from "react";

export function NetBackground() {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    let cancelled = false;
    let unmount: (() => void) | undefined;

    import("./net-scene")
      .then(({ mountNetScene }) => {
        if (cancelled) return;
        unmount = mountNetScene(el);
        el.dataset.ready = "";
      })
      .catch(() => {});

    return () => {
      cancelled = true;
      unmount?.();
    };
  }, []);

  return (
    <div
      ref={ref}
      aria-hidden
      className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-1000 data-ready:opacity-100"
    />
  );
}

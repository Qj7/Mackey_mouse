import type { Metadata } from "next";
import { fontVariables } from "./fonts";
import "./globals.css";

export const metadata: Metadata = {
  title: "Mackey Mouse — исправления для колеса мыши на Mac",
  description:
    "Утилита в строке меню macOS. Переворачивает и сглаживает только колесо мыши, не трогая естественную прокрутку тачпада.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ru" className={`${fontVariables} antialiased`}>
      <body>{children}</body>
    </html>
  );
}

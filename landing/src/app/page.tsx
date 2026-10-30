import { Donate } from "@/components/Donate";
import { Download } from "@/components/Download";
import { Hero } from "@/components/Hero";
import { HowItWorks } from "@/components/HowItWorks";
import { SiteFooter } from "@/components/SiteFooter";

export default function Home() {
  return (
    <main>
      <Hero />
      <HowItWorks />
      <Donate />
      <Download />
      <SiteFooter />
    </main>
  );
}

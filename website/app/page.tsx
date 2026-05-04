import { Header } from "@/components/Header";
import { Hero } from "@/components/Hero";
import { Showcase } from "@/components/Showcase";
import { States } from "@/components/States";
import { Popover } from "@/components/Popover";
import { Why } from "@/components/Why";
import { FinalCTA } from "@/components/FinalCTA";

export default function Home() {
  return (
    <main className="relative min-h-screen">
      <Header />
      <Hero />
      <Showcase />
      <States />
      <Popover />
      <Why />
      <FinalCTA />
    </main>
  );
}

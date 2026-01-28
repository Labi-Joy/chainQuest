import { HeroSection } from '@/components/sections/HeroSection';
import { FeaturesSection } from '@/components/sections/FeaturesSection';
import { StatsSection } from '@/components/sections/StatsSection';
import { QuestsSection } from '@/components/sections/QuestsSection';
import { CTASection } from '@/components/sections/CTASection';

export default function HomePage() {
  return (
    <main className="min-h-screen bg-background">
      <HeroSection />
      <FeaturesSection />
      <StatsSection />
      <QuestsSection />
      <CTASection />
    </main>
  );
}

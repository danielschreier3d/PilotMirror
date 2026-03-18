"use client";

import { useEffect } from "react";
import { useRouter, usePathname } from "next/navigation";
import Link from "next/link";
import { useAuth } from "@/lib/auth-context";

function BarChartSVG({ color }: { color: string }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill={color}>
      <rect x="2" y="12" width="5" height="10" rx="1.5"/>
      <rect x="9.5" y="6" width="5" height="16" rx="1.5"/>
      <rect x="17" y="2" width="5" height="20" rx="1.5"/>
    </svg>
  );
}

function LightbulbSVG({ color }: { color: string }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill={color}>
      <path d="M9 21c0 .55.45 1 1 1h4c.55 0 1-.45 1-1v-1H9v1zm3-19c-3.87 0-7 3.13-7 7 0 2.38 1.19 4.47 3 5.74V17c0 .55.45 1 1 1h6c.55 0 1-.45 1-1v-2.26c1.81-1.27 3-3.36 3-5.74 0-3.87-3.13-7-7-7z"/>
    </svg>
  );
}

const TABS = [
  { href: "/dashboard", Icon: BarChartSVG, labelDE: "Dashboard", labelEN: "Dashboard" },
  { href: "/tips",      Icon: LightbulbSVG, labelDE: "Tipps",    labelEN: "Tips"      },
];

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isRestoring } = useAuth();
  const router   = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (isRestoring) return;
    if (!isAuthenticated) router.replace("/login");
  }, [isAuthenticated, isRestoring, router]);

  if (isRestoring) {
    return (
      <div className="flex items-center justify-center min-h-svh" style={{ background: "var(--app-bg)" }}>
        <div className="spinner" />
      </div>
    );
  }
  if (!isAuthenticated) return null;

  return (
    <div className="flex flex-col min-h-svh" style={{ background: "var(--app-bg)" }}>
      {/* Page content */}
      <main className="flex-1 pb-safe">{children}</main>

      {/* Tab bar */}
      <nav className="tab-bar">
        {TABS.map(({ href, Icon, labelDE, labelEN }) => {
          const active = pathname === href || (href === "/dashboard" && pathname.startsWith("/dashboard"));
          const color = active ? "#4A9EF8" : "var(--app-tertiary)";
          return (
            <Link key={href} href={href}
              className="flex-1 flex flex-col items-center justify-center py-2 gap-1 transition-opacity"
              style={{ color }}>
              <Icon color={color} />
              <span className="text-[10px] font-semibold">{labelEN}</span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}

"use client";

import { useEffect } from "react";
import { useRouter, usePathname } from "next/navigation";
import Link from "next/link";
import { useAuth } from "@/lib/auth-context";

const TABS = [
  { href: "/dashboard", icon: "📊", labelDE: "Dashboard", labelEN: "Dashboard" },
  { href: "/tips",      icon: "💡", labelDE: "Tipps",     labelEN: "Tips"      },
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
        {TABS.map(({ href, icon, labelDE, labelEN }) => {
          const active = pathname === href || (href === "/dashboard" && pathname.startsWith("/dashboard"));
          return (
            <Link key={href} href={href}
              className="flex-1 flex flex-col items-center justify-center py-2 gap-1 transition-opacity"
              style={{ color: active ? "#4A9EF8" : "var(--app-tertiary)" }}>
              <span className="text-xl">{icon}</span>
              <span className="text-[10px] font-semibold">{labelEN}</span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}

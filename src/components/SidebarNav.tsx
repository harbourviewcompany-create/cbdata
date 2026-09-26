"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const NAV = [
  {
    group: "Operations",
    items: [
      { href: "/dashboard", label: "Command" },
      { href: "/properties", label: "Properties" },
      { href: "/work-orders", label: "Work orders" },
      { href: "/dispatch", label: "Dispatch" },
      { href: "/issues", label: "Issues" },
    ],
  },
  {
    group: "Growth",
    items: [
      { href: "/targets", label: "Targets" },
      { href: "/sales", label: "Sales" },
      { href: "/contracts", label: "Contracts" },
    ],
  },
] as const;

export function SidebarNav() {
  const pathname = usePathname() || "/dashboard";

  return (
    <nav aria-label="Main">
      {NAV.map((section) => (
        <div key={section.group}>
          <p className="nav-group">{section.group}</p>
          {section.items.map((item) => {
            const active =
              pathname === item.href ||
              (item.href !== "/dashboard" && pathname.startsWith(item.href));
            return (
              <Link
                key={item.href}
                href={item.href}
                className={active ? "active" : undefined}
              >
                {item.label}
              </Link>
            );
          })}
        </div>
      ))}
    </nav>
  );
}

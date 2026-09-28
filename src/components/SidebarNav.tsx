"use client";

import Link from "next/link";
import type { Route } from "next";
import { usePathname } from "next/navigation";

const NAV = [
  {
    group: "Operations",
    roles: ["owner","administrator","operations_manager","operations_supervisor","field_supervisor","field_worker","finance","read_only"],
    items: [
      { href: "/dashboard", label: "Command", roles: null as string[] | null },
      { href: "/today", label: "Today", roles: ["owner","administrator","operations_manager","operations_supervisor","field_supervisor","field_worker"] },
      { href: "/properties", label: "Properties", roles: null },
      { href: "/work-orders", label: "Work orders", roles: ["owner","administrator","operations_manager","operations_supervisor","field_supervisor","field_worker"] },
      { href: "/dispatch", label: "Dispatch", roles: ["owner","administrator","operations_manager","operations_supervisor","field_supervisor"] },
      { href: "/crew", label: "Crew", roles: ["owner","administrator","operations_manager","operations_supervisor","field_supervisor"] },
      { href: "/issues", label: "Issues", roles: null },
    ],
  },
  {
    group: "Growth",
    roles: ["owner","administrator","sales_manager","sales_rep","operations_manager"],
    items: [
      { href: "/targets", label: "Targets", roles: ["owner","administrator","sales_manager","sales_rep"] },
      { href: "/outreach", label: "Outreach", roles: ["owner","administrator","sales_manager","sales_rep"] },
      { href: "/procurement", label: "Tender Intelligence", roles: ["owner","administrator","sales_manager","sales_rep","operations_manager"] },
      { href: "/sales", label: "Sales", roles: ["owner","administrator","sales_manager","sales_rep"] },
      { href: "/estimates", label: "Estimates", roles: ["owner","administrator","sales_manager","sales_rep","operations_manager"] },
      { href: "/contracts", label: "Contracts", roles: ["owner","administrator","operations_manager","sales_manager"] },
    ],
  },
  {
    group: "Money",
    roles: ["owner","administrator","finance","operations_manager"],
    items: [{ href: "/invoices", label: "Invoices", roles: ["owner","administrator","finance","operations_manager"] }],
  },
  {
    group: "Admin",
    roles: ["owner","administrator"],
    items: [{ href: "/settings", label: "Team", roles: ["owner","administrator"] }],
  },
] as const;

export function SidebarNav({ role }: { role?: string | null }) {
  const pathname = usePathname() || "/dashboard";
  const r = role ?? "read_only";
  return (
    <nav aria-label="Main">
      {NAV.map((section) => {
        if (section.roles.length && !section.roles.includes(r as never)) return null;
        const items = section.items.filter((item) => !item.roles || item.roles.includes(r as never));
        if (!items.length) return null;
        return (
          <div key={section.group}>
            <p className="nav-group">{section.group}</p>
            {items.map((item) => {
              const active = pathname === item.href || (item.href !== "/dashboard" && pathname.startsWith(item.href));
              return <Link key={item.href} href={item.href as Route} className={active ? "active" : undefined}>{item.label}</Link>;
            })}
          </div>
        );
      })}
    </nav>
  );
}

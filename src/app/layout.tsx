import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "CBData | Contracting Operations",
  description: "Operational control system for CB Contracting.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
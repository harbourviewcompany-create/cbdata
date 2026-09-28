"use client";

export function PrintQuoteButton() {
  return <button type="button" className="primary" onClick={() => window.print()}>Print / save PDF</button>;
}

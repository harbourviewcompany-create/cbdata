export const DECK_LINES = [
  { key: "foundations", label: "Footings and posts", price: 1500, material: 700, labor: 550 },
  { key: "framing", label: "Framing and structural hardware", price: 2100, material: 900, labor: 900 },
  { key: "decking", label: "Pressure-treated decking and fascia", price: 2200, material: 1000, labor: 850 },
  { key: "stairs", label: "Left-side stairway and handrail", price: 1600, material: 500, labor: 950 },
  { key: "logistics", label: "Delivery, site setup and cleanup", price: 600, material: 200, labor: 350 },
  { key: "overhead", label: "Project coordination and allowance", price: 1800, material: 0, labor: 0 },
] as const;

export const GUARD_LINE = {
  key: "guards", label: "Pressure-treated deck guards (up to 30 linear feet)",
  price: 3200, material: 900, labor: 1300,
} as const;

export const HST_RATE = 0.13;

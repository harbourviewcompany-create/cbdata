export type DeckSpec = {
  width_ft: number;
  depth_ft: number;
  stair_width_ft: number;
  steps: number;
  footings: number;
  height_in: number | null;
  include_guards: boolean;
  site_reference?: string | null;
  landing?: string | null;
  site_notes?: string | null;
  joist_spacing_in?: number | null;
};

export type DeckTakeoffLine = {
  sourceKey: string;
  canonicalKey: string;
  quantity: number;
  note: string;
};

const BOARD_WIDTH_FT = 5.5 / 12;
const STANDARD_LENGTHS = [8, 10, 12, 16] as const;

function standardLength(spanFt: number) {
  return STANDARD_LENGTHS.find((length) => spanFt <= length) ?? 16;
}

function piecesForLinearFeet(totalLinearFt: number, stockLength: number) {
  return Math.max(1, Math.ceil(totalLinearFt / stockLength));
}

export function buildDeckTakeoff(spec: DeckSpec): DeckTakeoffLine[] {
  const width = Number(spec.width_ft);
  const depth = Number(spec.depth_ft);
  const spacingFt = Number(spec.joist_spacing_in || 16) / 12;
  const footings = Math.max(1, Math.round(Number(spec.footings || 0)));
  const lines: DeckTakeoffLine[] = [];

  // Deck boards run across the depth. For spans >16 ft this becomes a linear-foot
  // allowance and assumes field staggering/splices; the estimator must verify layout.
  const deckingLength = standardLength(depth);
  const boardRows = Math.ceil(width / BOARD_WIDTH_FT);
  const deckingQty = depth <= 16
    ? boardRows
    : piecesForLinearFeet(boardRows * depth, deckingLength);
  lines.push({
    sourceKey: "decking",
    canonicalKey: `pt-5-4x6x${deckingLength}`,
    quantity: deckingQty,
    note: `${width}×${depth} ft surface; 5/4×6 boards at 5.5 in actual width; boards assumed to run across the ${depth} ft depth.`,
  });

  // Joists at the saved O.C. spacing, plus outside joists. Stock is converted from
  // required linear feet when the span exceeds available 16 ft lengths.
  const joistLength = standardLength(depth);
  const joistCount = Math.ceil(width / spacingFt) + 1;
  const joistQty = depth <= 16
    ? joistCount
    : piecesForLinearFeet(joistCount * depth, joistLength);
  lines.push({
    sourceKey: "joists",
    canonicalKey: `pt-2x8x${joistLength}`,
    quantity: joistQty,
    note: `${joistCount} joist lines at approximately ${Number(spec.joist_spacing_in || 16)} in O.C.; verify span tables and beam layout before purchase.`,
  });

  // Front/back rim boards.
  const rimQty = piecesForLinearFeet(width * 2, 16);
  lines.push({
    sourceKey: "rim",
    canonicalKey: "pt-2x8x16",
    quantity: rimQty,
    note: `Two rim runs across ${width} ft width; converted to 16 ft stock.`,
  });

  // Preliminary two-ply beam allowance. Deeper decks get a second beam line.
  const beamRuns = depth > 12 ? 2 : 1;
  const beamQty = piecesForLinearFeet(width * 2 * beamRuns, 16);
  lines.push({
    sourceKey: "beams",
    canonicalKey: "pt-2x8x16",
    quantity: beamQty,
    note: `${beamRuns} preliminary beam run(s), two-ply 2×8 across ${width} ft. Structural design must be verified before ordering.`,
  });

  lines.push({
    sourceKey: "posts",
    canonicalKey: "pt-4x4x8",
    quantity: footings,
    note: `${footings} posts based on the estimate footing count; confirm actual post height and footing design on site.`,
  });

  // Tread decking allowance only. Structural stair stringers/hardware remain a manual line
  // because the current priced catalog is intentionally limited to verified mapped SKUs.
  if (Number(spec.steps) > 0) {
    const treadRows = Math.ceil(Number(spec.stair_width_ft) / BOARD_WIDTH_FT);
    const treadLinearFt = treadRows * Number(spec.steps);
    lines.push({
      sourceKey: "stair-treads",
      canonicalKey: "pt-5-4x6x8",
      quantity: piecesForLinearFeet(treadLinearFt, 8),
      note: `${spec.steps} stair tread(s) at ${spec.stair_width_ft} ft width. Stringers, risers, hardware and code requirements must be added/verified separately.`,
    });
  }

  return lines;
}

export function parseLegacyDeckSpec(description: string): DeckSpec | null {
  const size = description.match(/(\d+(?:\.\d+)?)\s*[×x]\s*(\d+(?:\.\d+)?)\s*ft/i);
  const stair = description.match(/stairs\s+(\d+(?:\.\d+)?)\s*ft\s+wide,\s*(\d+)\s+estimated steps/i);
  const footings = description.match(/(\d+)\s+assumed footings/i);
  const height = description.match(/deck height:\s*(?:(\d+(?:\.\d+)?)\s*in|not measured)/i);
  if (!size || !stair || !footings) return null;

  return {
    width_ft: Number(size[1]),
    depth_ft: Number(size[2]),
    stair_width_ft: Number(stair[1]),
    steps: Number(stair[2]),
    footings: Number(footings[1]),
    height_in: height?.[1] ? Number(height[1]) : null,
    include_guards: false,
    joist_spacing_in: 16,
  };
}

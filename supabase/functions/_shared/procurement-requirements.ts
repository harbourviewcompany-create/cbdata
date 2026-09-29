export type DetectedRequirement = {
  title: string;
  requirementType: string;
  description: string;
  evidenceRequired: boolean;
};

type Rule = {
  title: string;
  requirementType: string;
  evidenceRequired?: boolean;
  pattern: RegExp;
  description: string;
};

const RULES: Rule[] = [
  {
    title: "Supplier registration / prequalification",
    requirementType: "registration",
    evidenceRequired: true,
    pattern: /\bpre[- ]qualification\b|(?:must|shall|required|required to|only (?:vendors|suppliers|contractors)|eligible (?:vendors|suppliers|contractors))[^.\n]{0,180}(?:register(?:ed|ation)?|prequalif(?:y|ied|ication)|supply arrangement|standing offer|vendor of record)|(?:supply arrangement|standing offer|prequalified)[^.\n]{0,140}(?:holder|required|only|eligible)/i,
    description: "Published notice appears to require an existing supplier registration, prequalification, standing offer, supply arrangement, or equivalent eligibility."
  },
  {
    title: "Bid bond / tender security",
    requirementType: "bonding",
    evidenceRequired: true,
    pattern: /(?:must|shall|required|mandatory)[^.\n]{0,180}(?:bid bond|tender security|surety|bid security)|(?:bid bond|tender security|bid security)[^.\n]{0,120}(?:must|shall|required|mandatory|minimum|percent|%)/i,
    description: "Published notice appears to require bid security or a surety instrument."
  },
  {
    title: "Performance / labour and material bond",
    requirementType: "bonding",
    evidenceRequired: true,
    pattern: /(?:must|shall|required|mandatory)[^.\n]{0,180}(?:performance bond|labou?r and material payment bond|payment bond)|(?:performance bond|labou?r and material payment bond|payment bond)[^.\n]{0,120}(?:must|shall|required|mandatory|percent|%)/i,
    description: "Published notice appears to require performance and/or labour and material payment bonding."
  },
  {
    title: "Commercial liability insurance",
    requirementType: "insurance",
    evidenceRequired: true,
    pattern: /(?:must|shall|required|mandatory)[^.\n]{0,200}(?:certificate of insurance|commercial general liability|general liability insurance|liability coverage)|(?:certificate of insurance|commercial general liability)[^.\n]{0,140}(?:must|shall|required|mandatory|minimum|coverage)/i,
    description: "Published notice appears to require proof of commercial liability insurance."
  },
  {
    title: "WSIB / workers compensation clearance",
    requirementType: "workers_comp",
    evidenceRequired: true,
    pattern: /(?:must|shall|required|mandatory)[^.\n]{0,180}(?:wsib|workers.? compensation|workplace safety and insurance|clearance certificate)|(?:wsib|workers.? compensation)[^.\n]{0,120}(?:clearance|must|shall|required|mandatory)/i,
    description: "Published notice appears to require workers compensation / WSIB evidence."
  },
  {
    title: "Security clearance",
    requirementType: "security",
    evidenceRequired: true,
    pattern: /(?:must|shall|required|mandatory)[^.\n]{0,220}(?:reliability status|security clearance|personnel security screening|facility security clearance|secret clearance)|(?:reliability status|security clearance)[^.\n]{0,140}(?:must|shall|required|mandatory|before)/i,
    description: "Published notice appears to require personnel or organization security screening."
  },
  {
    title: "Minimum corporate experience",
    requirementType: "experience",
    evidenceRequired: true,
    pattern: /(?:minimum|at least|no less than)\s+\d+\s+(?:years?|ans)[^.\n]{0,120}(?:experience|expérience)|(?:must|shall|required)[^.\n]{0,160}\d+\s+(?:years?|ans)[^.\n]{0,80}(?:experience|expérience)/i,
    description: "Published notice appears to set a minimum number of years of relevant experience."
  },
  {
    title: "Comparable project experience",
    requirementType: "experience",
    evidenceRequired: true,
    pattern: /(?:must|shall|required|mandatory|provide|demonstrate)[^.\n]{0,160}(?:(?:two|three|four|2|3|4)\s+(?:similar|comparable|qualifying|relevant)?\s*projects?|project examples?|similar projects?|comparable projects?)/i,
    description: "Published notice appears to require examples of comparable completed projects."
  },
  {
    title: "Client references",
    requirementType: "references",
    evidenceRequired: true,
    pattern: /(?:must|shall|required|mandatory|provide)[^.\n]{0,160}(?:client references?|project references?|reference contact|references including)/i,
    description: "Published notice appears to require client or project references."
  },
  {
    title: "Mandatory site visit / job showing",
    requirementType: "site_visit",
    evidenceRequired: true,
    pattern: /(?:mandatory|required)[^.\n]{0,80}(?:site visit|job showing|site meeting)|(?:site visit|job showing|site meeting)[^.\n]{0,80}(?:mandatory|required)/i,
    description: "Published notice appears to require attendance at a mandatory site visit or job showing."
  },
  {
    title: "Bilingual project representative",
    requirementType: "bilingual",
    evidenceRequired: true,
    pattern: /(?:must|shall|required|mandatory)[^.\n]{0,180}(?:bilingual|english and french|french and english|anglais et français|français et anglais)/i,
    description: "Published notice appears to require a bilingual English/French representative or supervisor."
  },
  {
    title: "Required licences / operator certifications",
    requirementType: "certification",
    evidenceRequired: true,
    pattern: /(?:must|shall|required|mandatory)[^.\n]{0,200}(?:licensed|licenced|certified operator|operator certification|trade certificate|red seal|certificate of qualification)/i,
    description: "Published notice appears to require trade, operator, or professional certification evidence."
  },
  {
    title: "Equipment availability / commitment evidence",
    requirementType: "equipment",
    evidenceRequired: true,
    pattern: /(?:proof|evidence|letter of commitment|rental agreement|subcontract)[^.\n]{0,160}(?:equipment|machinery|crane|truck|trailer)|(?:must|shall|required)[^.\n]{0,180}(?:own|rent|secure|provide)[^.\n]{0,100}(?:equipment|crane|heavy haul|truck|trailer)/i,
    description: "Published notice appears to require evidence that specified equipment is owned, rented, subcontracted, or otherwise secured."
  },
  {
    title: "Indigenous procurement eligibility",
    requirementType: "indigenous_eligibility",
    evidenceRequired: true,
    pattern: /(?:set[- ]aside|procurement strategy for indigenous business|psib)[^.\n]{0,180}(?:eligible|eligibility|required|business|supplier|bidder)/i,
    description: "Published notice appears to include Indigenous procurement eligibility or set-aside requirements."
  },
  {
    title: "Mandatory pricing / financial form",
    requirementType: "pricing_form",
    evidenceRequired: false,
    pattern: /(?:must|shall|required|mandatory|complete|submit)[^.\n]{0,160}(?:pricing form|price schedule|financial bid|basis of payment form)|(?:pricing form|price schedule)[^.\n]{0,100}(?:must|shall|required|mandatory|complete|submit)/i,
    description: "Published notice appears to require a prescribed pricing or financial form."
  }
];

function normalizedText(value: string) {
  return value.replace(/\s+/g, " ").trim();
}

export function detectMandatoryRequirements(text: string): DetectedRequirement[] {
  const source = normalizedText(text || "");
  if (!source) return [];
  return RULES.filter((rule) => rule.pattern.test(source)).map((rule) => ({
    title: rule.title,
    requirementType: rule.requirementType,
    description: rule.description,
    evidenceRequired: rule.evidenceRequired ?? false
  }));
}

export async function syncDetectedRequirements(
  admin: any,
  workspaceId: string,
  tenderRecordId: string,
  sourceText: string,
  sourceUrl: string | null,
  knownTitles?: Set<string>
) {
  const detected = detectMandatoryRequirements(sourceText);
  if (!detected.length) return { detected: 0, inserted: 0 };

  let existing: Set<string>;
  if (knownTitles) {
    existing = knownTitles;
  } else {
    const { data: existingRows, error: existingError } = await admin
      .from("tender_requirements")
      .select("title")
      .eq("workspace_id", workspaceId)
      .eq("tender_record_id", tenderRecordId);
    if (existingError) throw existingError;
    existing = new Set((existingRows || []).map((row: any) => row.title));
  }
  const missing = detected.filter((item) => !existing.has(item.title));
  if (!missing.length) return { detected: detected.length, inserted: 0 };

  const { error } = await admin.from("tender_requirements").insert(
    missing.map((item) => ({
      workspace_id: workspaceId,
      tender_record_id: tenderRecordId,
      requirement_type: item.requirementType,
      title: item.title,
      description: item.description + " Verify against the official solicitation and amendments before relying on this detection.",
      mandatory: true,
      evidence_required: item.evidenceRequired,
      source_reference: sourceUrl,
      status: "pending",
      notes: "Auto-detected from published procurement text; human verification required."
    }))
  );
  if (error) throw error;
  return { detected: detected.length, inserted: missing.length };
}

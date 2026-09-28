import { createClient } from "https://esm.sh/@supabase/supabase-js@2.117.1";

type AnyRow = Record<string, any>;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });

const round2 = (n: number) => Math.round((n + Number.EPSILON) * 100) / 100;
const norm = (v: string | null | undefined) =>
  (v || "")
    .toLowerCase()
    .replaceAll("×", "x")
    .replace(/&times;|&#215;/g, "x")
    .replace(/\b(inches|inch|in|feet|foot|ft)\b/g, " ")
    .replace(/[′’']/g, " ")
    .replace(/[^a-z0-9/.$]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

function decodeHtml(input: string) {
  return input
    .replace(/<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi, "$1 ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;|&#160;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&quot;|&#34;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&times;|&#215;/g, "×")
    .replace(/\s+/g, " ");
}

function parseJsonLdPrice(html: string, productName: string): number | null {
  const blocks = Array.from(
    html.matchAll(/<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi),
  );
  const wanted = norm(productName);
  const candidates: { score: number; price: number }[] = [];

  const walk = (value: any) => {
    if (!value) return;
    if (Array.isArray(value)) return value.forEach(walk);
    if (typeof value !== "object") return;
    const name = norm(String(value.name || value.headline || ""));
    const offers = value.offers;
    const offerList = Array.isArray(offers) ? offers : offers ? [offers] : [];
    for (const offer of offerList) {
      const raw = offer?.price ?? offer?.lowPrice ?? offer?.highPrice;
      const price = Number(String(raw ?? "").replace(/[^0-9.]/g, ""));
      if (Number.isFinite(price) && price > 0 && price < 100000) {
        const score = name && wanted
          ? wanted.split(" ").filter((t) => t.length > 1 && name.includes(t)).length
          : 0;
        candidates.push({ score, price });
      }
    }
    for (const child of Object.values(value)) {
      if (child && typeof child === "object") walk(child);
    }
  };

  for (const block of blocks) {
    try { walk(JSON.parse(block[1])); } catch { /* retailer markup is often not strict JSON */ }
  }
  candidates.sort((a, b) => b.score - a.score || a.price - b.price);
  return candidates[0]?.price ?? null;
}

function findProductWindow(text: string, item: AnyRow, productName: string) {
  const cleaned = norm(text);
  const nominal = norm(item.nominal_size).replace(/\s*x\s*/g, " x ");
  const length = String(Number(item.length_ft || 0));
  const patterns = [
    norm(productName),
    norm(`${nominal} x ${length}`),
    norm(`${item.nominal_size || ""} ${length}`),
    norm(item.description),
  ].filter((x) => x.length >= 5);

  let index = -1;
  for (const p of patterns) {
    index = cleaned.indexOf(p);
    if (index >= 0) break;
  }
  if (index < 0 && nominal) {
    const parts = nominal.split(" ").filter(Boolean);
    index = cleaned.indexOf(parts.join(" "));
  }
  if (index < 0) return cleaned.slice(0, 2500);
  return cleaned.slice(Math.max(0, index - 250), Math.min(cleaned.length, index + 1800));
}

function parseVisiblePrice(html: string, item: AnyRow, productName: string): number | null {
  const text = decodeHtml(html);
  const window = findProductWindow(text, item, productName);

  const patterns = [
    /\$\s*([0-9]{1,5}(?:[.,][0-9]{2})?)/gi,
    /\b([0-9]{1,4})\s+and\s+([0-9]{2})\s+cents?\b/gi,
    /\b([0-9]{1,4})\s*[.]\s*([0-9]{2})\s+each\b/gi,
    /\b([0-9]{1,4})\s+([0-9]{2})\s+each\b/gi,
  ];

  const prices: number[] = [];
  for (const re of patterns) {
    for (const match of window.matchAll(re)) {
      const price = match[2]
        ? Number(match[1]) + Number(match[2]) / 100
        : Number(String(match[1]).replace(",", "."));
      if (Number.isFinite(price) && price > 0.25 && price < 10000) prices.push(price);
    }
    if (prices.length) break;
  }
  return prices.length ? prices[0] : null;
}

async function fetchPrice(product: AnyRow, item: AnyRow) {
  if (!product.product_url) throw new Error("No product URL configured");
  const response = await fetch(product.product_url, {
    headers: {
      "user-agent": "Mozilla/5.0 (compatible; CBDataPriceScout/1.0; +https://cbcontracting.ca)",
      accept: "text/html,application/xhtml+xml",
      "accept-language": "en-CA,en;q=0.9",
    },
    redirect: "follow",
  });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  const html = await response.text();
  const exact = parseJsonLdPrice(html, product.product_name);
  const visible = exact ?? parseVisiblePrice(html, item, product.product_name);
  if (visible == null) throw new Error("Price not found in source page");
  return {
    price: visible / Number(product.pack_qty || 1),
    excerpt: decodeHtml(html).slice(0, 4000),
    evidenceUrl: response.url || product.product_url,
  };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST required" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) return json({ error: "Supabase environment is incomplete" }, 500);

  const authHeader = req.headers.get("authorization") || "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "Authentication required" }, 401);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return json({ error: "Invalid session" }, 401);

  const body = await req.json().catch(() => ({}));
  const workspaceId = String(body.workspace_id || "");
  const requestId = String(body.request_id || "");
  const refresh = body.refresh !== false;
  if (!workspaceId || !requestId) return json({ error: "workspace_id and request_id are required" }, 400);

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
  const { data: membership } = await admin
    .from("workspace_memberships")
    .select("workspace_id,role")
    .eq("workspace_id", workspaceId)
    .eq("user_id", userData.user.id)
    .eq("status", "active")
    .maybeSingle();
  const allowedRoles = new Set(["owner", "administrator", "operations_manager", "sales_manager", "sales_rep"]);
  if (!membership || !allowedRoles.has(String(membership.role || ""))) {
    return json({ error: "Material pricing access denied" }, 403);
  }

  const { data: requestRow, error: requestError } = await admin
    .from("material_requests")
    .select("id,workspace_id,name,region,waste_pct,delivery_mode,status")
    .eq("workspace_id", workspaceId)
    .eq("id", requestId)
    .maybeSingle();
  if (requestError || !requestRow) return json({ error: requestError?.message || "Material request not found" }, 404);

  const { data: requestItems, error: itemsError } = await admin
    .from("material_request_items")
    .select("id,material_item_id,quantity,sort_order")
    .eq("workspace_id", workspaceId)
    .eq("request_id", requestId)
    .order("sort_order");
  if (itemsError) return json({ error: itemsError.message }, 500);
  if (!requestItems?.length) return json({ error: "Add at least one material item before pricing" }, 400);

  const materialIds = [...new Set(requestItems.map((x) => x.material_item_id))];
  const [{ data: catalog }, { data: products }, { data: suppliers }] = await Promise.all([
    admin.from("material_catalog_items").select("*").eq("workspace_id", workspaceId).in("id", materialIds),
    admin.from("material_supplier_products").select("*").eq("workspace_id", workspaceId).eq("active", true).in("material_item_id", materialIds),
    admin.from("material_suppliers").select("*").eq("workspace_id", workspaceId).eq("active", true),
  ]);

  const itemById = new Map((catalog || []).map((x) => [x.id, x]));
  const supplierById = new Map((suppliers || []).map((x) => [x.id, x]));

  const { data: run, error: runError } = await admin
    .from("material_price_runs")
    .insert({
      workspace_id: workspaceId,
      request_id: requestId,
      status: "running",
      created_by: userData.user.id,
    })
    .select("id")
    .single();
  if (runError || !run) return json({ error: runError?.message || "Could not start price run" }, 500);

  const errors: AnyRow[] = [];
  let productsChecked = 0;
  let freshQuotes = 0;

  if (refresh) {
    for (const product of products || []) {
      if (product.pricing_mode !== "live_page" || !product.product_url) continue;
      productsChecked += 1;
      const item = itemById.get(product.material_item_id);
      if (!item) continue;
      try {
        const found = await fetchPrice(product, item);
        const supplier = supplierById.get(product.supplier_id);
        const { error: observationError } = await admin.from("material_price_observations").insert({
          workspace_id: workspaceId,
          material_item_id: product.material_item_id,
          supplier_id: product.supplier_id,
          supplier_product_id: product.id,
          price_each: round2(found.price),
          currency: "CAD",
          stock_status: "verify_store",
          store_label: "Web price — verify Ottawa store",
          bulk_min_qty: product.bulk_min_qty,
          bulk_discount_pct: product.bulk_discount_pct,
          evidence_url: found.evidenceUrl,
          source_type: "live_page",
          confidence: "medium",
          raw_excerpt: found.excerpt,
          observed_at: new Date().toISOString(),
          created_by: userData.user.id,
        });
        if (observationError) throw observationError;
        freshQuotes += 1;
        await admin.from("material_supplier_products")
          .update({ last_checked_at: new Date().toISOString(), last_error: null, updated_at: new Date().toISOString() })
          .eq("id", product.id);
        if (!supplier) errors.push({ product_id: product.id, error: "Supplier missing after quote insert" });
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        errors.push({ product_id: product.id, product_name: product.product_name, error: message });
        await admin.from("material_supplier_products")
          .update({ last_checked_at: new Date().toISOString(), last_error: message, updated_at: new Date().toISOString() })
          .eq("id", product.id);
      }
    }
  }

  const cutoff = new Date(Date.now() - 45 * 86_400_000).toISOString();
  const { data: observations, error: observationsError } = await admin
    .from("material_price_observations")
    .select("*")
    .eq("workspace_id", workspaceId)
    .in("material_item_id", materialIds)
    .gte("observed_at", cutoff)
    .order("observed_at", { ascending: false });
  if (observationsError) return json({ error: observationsError.message }, 500);

  const latest = new Map<string, AnyRow>();
  const observationPriority = (observation: AnyRow) => {
    const ageDays = (Date.now() - new Date(observation.observed_at).getTime()) / 86_400_000;
    if (observation.source_type === "manual_quote" && ageDays <= 30) return 4;
    if (observation.source_type === "live_page" && ageDays <= 7) return 3;
    if (observation.source_type === "manual_quote") return 2;
    return 1;
  };
  for (const observation of observations || []) {
    const key = `${observation.material_item_id}:${observation.supplier_id}`;
    const current = latest.get(key);
    if (
      !current
      || observationPriority(observation) > observationPriority(current)
      || (
        observationPriority(observation) === observationPriority(current)
        && new Date(observation.observed_at).getTime() > new Date(current.observed_at).getTime()
      )
    ) latest.set(key, observation);
  }

  const productByPair = new Map<string, AnyRow>();
  for (const p of products || []) productByPair.set(`${p.material_item_id}:${p.supplier_id}`, p);

  const resultRows: AnyRow[] = [];
  let reusedQuotes = 0;

  for (const requestItem of requestItems) {
    const item = itemById.get(requestItem.material_item_id);
    if (!item) continue;
    const qtyWithWaste = Math.ceil(Number(requestItem.quantity) * (1 + Number(requestRow.waste_pct || item.default_waste_pct || 0) / 100));
    const candidates: AnyRow[] = [];

    for (const supplier of suppliers || []) {
      const key = `${requestItem.material_item_id}:${supplier.id}`;
      const observation = latest.get(key);
      if (!observation) continue;
      const ageDays = (Date.now() - new Date(observation.observed_at).getTime()) / 86_400_000;
      const staleAfter = observation.source_type === "manual_quote" ? 30 : 7;
      const stale = ageDays > staleAfter;
      const product = productByPair.get(key);
      const min = Number(observation.bulk_min_qty ?? product?.bulk_min_qty ?? 0);
      const discount = Number(observation.bulk_discount_pct ?? product?.bulk_discount_pct ?? 0);
      const unitPrice = Number(observation.price_each);
      const effective = min > 0 && qtyWithWaste >= min && discount > 0
        ? unitPrice * (1 - discount / 100)
        : unitPrice;
      candidates.push({
        workspace_id: workspaceId,
        run_id: run.id,
        request_item_id: requestItem.id,
        supplier_id: supplier.id,
        supplier_product_id: observation.supplier_product_id ?? product?.id ?? null,
        observation_id: observation.id,
        unit_price: round2(unitPrice),
        effective_unit_price: round2(effective),
        quantity_with_waste: qtyWithWaste,
        extended_price: round2(effective * qtyWithWaste),
        stock_status: observation.stock_status,
        evidence_url: observation.evidence_url,
        observed_at: observation.observed_at,
        stale,
        confidence: observation.confidence,
      });
      if (observation.source_type !== "live_page" || ageDays > 0.01) reusedQuotes += 1;
    }

    candidates.sort((a, b) => a.extended_price - b.extended_price);
    candidates.forEach((c, index) => { c.rank = index + 1; resultRows.push(c); });
  }

  await admin.from("material_price_run_results").delete().eq("run_id", run.id);
  if (resultRows.length) {
    const { error: resultError } = await admin.from("material_price_run_results").insert(resultRows);
    if (resultError) return json({ error: resultError.message }, 500);
  }

  const byRequestItem = new Map<string, AnyRow[]>();
  for (const row of resultRows) {
    const list = byRequestItem.get(row.request_item_id) || [];
    list.push(row);
    byRequestItem.set(row.request_item_id, list);
  }

  const plans: AnyRow[] = [];
  const splitLines = requestItems.map((ri) => (byRequestItem.get(ri.id) || [])[0]).filter(Boolean);
  if (splitLines.length === requestItems.length) {
    const used = [...new Set(splitLines.map((x) => x.supplier_id))];
    const materialSubtotal = round2(splitLines.reduce((sum, x) => sum + Number(x.extended_price), 0));
    const deliveryTotal = requestRow.delivery_mode === "delivery"
      ? round2(used.reduce((sum, supplierId) => sum + Number(supplierById.get(supplierId)?.default_delivery_fee || 0), 0))
      : 0;
    plans.push({
      workspace_id: workspaceId,
      request_id: requestId,
      run_id: run.id,
      plan_type: "split_cheapest",
      supplier_id: null,
      material_subtotal: materialSubtotal,
      delivery_total: deliveryTotal,
      total: round2(materialSubtotal + deliveryTotal),
      lines: splitLines,
      suppliers: used.map((id) => ({ id, name: supplierById.get(id)?.name || id })),
    });
  }

  for (const supplier of suppliers || []) {
    const lines = requestItems
      .map((ri) => (byRequestItem.get(ri.id) || []).find((x) => x.supplier_id === supplier.id))
      .filter(Boolean);
    if (lines.length !== requestItems.length) continue;
    const materialSubtotal = round2(lines.reduce((sum, x) => sum + Number(x.extended_price), 0));
    const deliveryTotal = requestRow.delivery_mode === "delivery" ? Number(supplier.default_delivery_fee || 0) : 0;
    plans.push({
      workspace_id: workspaceId,
      request_id: requestId,
      run_id: run.id,
      plan_type: "single_supplier",
      supplier_id: supplier.id,
      material_subtotal: materialSubtotal,
      delivery_total: round2(deliveryTotal),
      total: round2(materialSubtotal + deliveryTotal),
      lines,
      suppliers: [{ id: supplier.id, name: supplier.name }],
    });
  }

  plans.sort((a, b) => a.total - b.total);
  const baseline = plans.length ? Math.max(...plans.map((x) => Number(x.total))) : 0;
  for (const plan of plans) plan.savings_vs_baseline = round2(baseline - Number(plan.total));

  await admin.from("material_price_plans").delete().eq("run_id", run.id);
  if (plans.length) {
    const { error: planError } = await admin.from("material_price_plans").insert(plans);
    if (planError) return json({ error: planError.message }, 500);
  }

  const coveredItems = requestItems.filter((ri) => (byRequestItem.get(ri.id) || []).length > 0).length;
  const status = coveredItems === requestItems.length ? "completed" : coveredItems > 0 ? "partial" : "error";
  await admin.from("material_price_runs").update({
    status,
    finished_at: new Date().toISOString(),
    products_checked: productsChecked,
    fresh_quotes: freshQuotes,
    reused_quotes: reusedQuotes,
    errors,
  }).eq("id", run.id);

  if (plans.length) {
    await admin.from("material_requests")
      .update({ status: "priced", updated_at: new Date().toISOString() })
      .eq("workspace_id", workspaceId)
      .eq("id", requestId);
  }

  return json({
    run_id: run.id,
    status,
    request_items: requestItems.length,
    covered_items: coveredItems,
    products_checked: productsChecked,
    fresh_quotes: freshQuotes,
    reused_quotes: reusedQuotes,
    errors,
    best_plan: plans[0] || null,
  });
});

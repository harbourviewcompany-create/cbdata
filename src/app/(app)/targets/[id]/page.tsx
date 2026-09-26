import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getWorkspaceContext } from "@/lib/workspace";
import { convertTarget, logTouch } from "../actions";
import { addTargetContact, saveTargetAccount, setPrimaryTargetContact } from "../account-actions";

function fmt(v: string | null | undefined) {
  if (!v) return "—";
  try {
    return new Date(v).toLocaleString();
  } catch {
    return v;
  }
}

export default async function TargetDetail({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const ctx = await getWorkspaceContext();
  if (!ctx) redirect("/login");
  const s = await createClient();

  const { data: row } = await s
    .from("outreach_targets")
    .select(
      "id,status,score,score_reason,next_action,next_action_due_at,last_touch_at,organization_name,contact_name,phone,email,notes,region,organization_id,contact_id,property_address",
    )
    .eq("id", id)
    .eq("workspace_id", ctx.workspaceId)
    .maybeSingle();
  if (!row) notFound();

  const [{ data: org }, { data: links }, { data: touches }] = await Promise.all([
    row.organization_id
      ? s
          .from("organizations")
          .select(
            "id,legal_name,operating_name,organization_type,website,phone,email,notes,doors_managed,buildings_managed,primary_region,status",
          )
          .eq("id", row.organization_id)
          .maybeSingle()
      : Promise.resolve({ data: null }),
    row.organization_id
      ? s
          .from("organization_contacts")
          .select("id,contact_id,relationship_type,is_primary,contacts(id,first_name,last_name,job_title,email,phone,mobile)")
          .eq("organization_id", row.organization_id)
          .eq("workspace_id", ctx.workspaceId)
      : Promise.resolve({ data: [] }),
    s
      .from("outreach_touches")
      .select("id,channel,outcome,notes,occurred_at")
      .eq("outreach_target_id", id)
      .order("occurred_at", { ascending: false })
      .limit(20),
  ]);

  const companyName = org?.operating_name || org?.legal_name || row.organization_name || "Target";

  return (
    <>
      <header className="page-intro">
        <div>
          <span className="eyebrow">PM TARGET</span>
          <h1>{companyName}</h1>
          <p className="muted">
            {row.next_action ?? "No next action"} · score {row.score ?? "—"} · {row.status}
          </p>
        </div>
        <Link className="button" href="/targets">
          Back to queue
        </Link>
      </header>

      <section className="grid-two">
        <article className="panel">
          <div className="panel-head">
            <h3>Company</h3>
          </div>
          <form action={saveTargetAccount} className="form-grid">
            <input type="hidden" name="target_id" value={row.id} />
            <label>
              Operating name
              <input name="company_name" defaultValue={org?.operating_name || row.organization_name || ""} required />
            </label>
            <label>
              Legal name
              <input name="legal_name" defaultValue={org?.legal_name || ""} />
            </label>
            <label>
              Website
              <input name="website" defaultValue={org?.website || ""} placeholder="https://" />
            </label>
            <label>
              Company phone
              <input name="company_phone" defaultValue={org?.phone || ""} />
            </label>
            <label>
              Company email
              <input name="company_email" type="email" defaultValue={org?.email || ""} />
            </label>
            <label>
              Region
              <input name="region" defaultValue={org?.primary_region || row.region || ""} />
            </label>
            <label>
              Doors managed
              <input name="doors_managed" type="number" min="0" defaultValue={org?.doors_managed ?? ""} />
            </label>
            <label>
              Buildings
              <input name="buildings_managed" type="number" min="0" defaultValue={org?.buildings_managed ?? ""} />
            </label>
            <label>
              Snapshot contact name
              <input name="contact_name" defaultValue={row.contact_name || ""} />
            </label>
            <label>
              Snapshot phone
              <input name="phone" defaultValue={row.phone || ""} />
            </label>
            <label>
              Snapshot email
              <input name="email" type="email" defaultValue={row.email || ""} />
            </label>
            <label>
              Notes
              <textarea name="notes" defaultValue={row.notes || org?.notes || ""} rows={3} />
            </label>
            <button className="primary">Save company</button>
          </form>
          <p className="muted" style={{ marginTop: 8 }}>
            Saving creates or updates the linked organization. Snapshot phone/email stay on the target for list imports.
          </p>
        </article>

        <article className="panel">
          <div className="panel-head">
            <h3>Key contacts</h3>
          </div>
          <ul className="queue-list">
            {(links ?? []).length === 0 ? (
              <li className="muted">No roster yet. Add the facilities / property manager first.</li>
            ) : (
              (links ?? []).map((link) => {
                const c = (Array.isArray(link.contacts) ? link.contacts[0] : link.contacts) as {
                  id?: string;
                  first_name?: string;
                  last_name?: string;
                  job_title?: string | null;
                  email?: string | null;
                  phone?: string | null;
                  mobile?: string | null;
                } | null;
                if (!c) return null;
                return (
                  <li key={link.id}>
                    <strong>
                      {c.first_name} {c.last_name}
                      {link.is_primary ? " · primary" : ""}
                    </strong>
                    <span className="muted">
                      {link.relationship_type}
                      {c.job_title ? ` · ${c.job_title}` : ""}
                    </span>
                    <span className="muted">
                      {c.phone || c.mobile || "no phone"} · {c.email || "no email"}
                    </span>
                    {!link.is_primary ? (
                      <form action={setPrimaryTargetContact}>
                        <input type="hidden" name="target_id" value={row.id} />
                        <input type="hidden" name="contact_id" value={c.id} />
                        <button type="submit">Make primary</button>
                      </form>
                    ) : null}
                  </li>
                );
              })
            )}
          </ul>
          <form action={addTargetContact} className="form-grid" style={{ marginTop: 16 }}>
            <input type="hidden" name="target_id" value={row.id} />
            <input name="full_name" required placeholder="Full name" />
            <input name="job_title" placeholder="Job title" />
            <select name="relationship_type" defaultValue="property_manager">
              <option value="property_manager">property_manager</option>
              <option value="facilities">facilities</option>
              <option value="board">board</option>
              <option value="owner">owner</option>
              <option value="accounts_payable">accounts_payable</option>
              <option value="key_contact">key_contact</option>
            </select>
            <input name="phone" placeholder="Desk phone" />
            <input name="mobile" placeholder="Mobile" />
            <input name="email" type="email" placeholder="Email" />
            <label style={{ display: "flex", gap: 8, alignItems: "center" }}>
              <input type="checkbox" name="is_primary" />
              Primary contact for outreach
            </label>
            <button>Add contact</button>
          </form>
        </article>
      </section>

      <section className="grid-two" style={{ marginTop: 14 }}>
        <article className="panel">
          <div className="panel-head">
            <h3>Log a touch</h3>
          </div>
          <form action={logTouch} className="form-grid">
            <input type="hidden" name="target_id" value={row.id} />
            <select name="channel" defaultValue="call">
              <option value="call">call</option>
              <option value="email">email</option>
              <option value="sms">sms</option>
              <option value="door_knock">door_knock</option>
              <option value="mail">mail</option>
              <option value="other">other</option>
            </select>
            <input name="outcome" placeholder="Reached / voicemail / booked" />
            <input name="notes" placeholder="What was said" />
            <input name="next_action" placeholder="Next action" defaultValue={row.next_action ?? ""} />
            <input name="next_action_due_at" type="datetime-local" />
            <select name="new_status" defaultValue="">
              <option value="">Keep status ({row.status})</option>
              <option value="contacted">contacted</option>
              <option value="responded">responded</option>
              <option value="rejected">rejected</option>
              <option value="do_not_contact">do_not_contact</option>
            </select>
            <button className="primary">Save touch</button>
          </form>
          <form action={convertTarget} style={{ marginTop: 12 }}>
            <input type="hidden" name="target_id" value={row.id} />
            <button>Convert to lead</button>
          </form>
        </article>
        <article className="panel">
          <div className="panel-head">
            <h3>History</h3>
          </div>
          <p className="muted" style={{ fontSize: 12 }}>
            {row.score_reason ?? "Score not computed yet"}
          </p>
          <ul className="queue-list">
            {(touches ?? []).length === 0 ? (
              <li className="muted">No touches logged.</li>
            ) : (
              (touches ?? []).map((t) => (
                <li key={t.id}>
                  <strong>
                    {t.channel} · {fmt(t.occurred_at)}
                  </strong>
                  <span className="muted">{t.outcome ?? t.notes ?? ""}</span>
                </li>
              ))
            )}
          </ul>
        </article>
      </section>
    </>
  );
}

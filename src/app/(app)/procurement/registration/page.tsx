/* eslint-disable @typescript-eslint/no-explicit-any */
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { requireWorkspace } from "@/lib/workspace";
import { updateSupplierRegistration, updateSupplierRegistrationStep } from "../actions";
import "../procurement.css";

function label(v:string){return v.replaceAll("_"," ");}
function phaseLabel(v:string){return v==="bid"?"Bid readiness":v==="award"?"Award readiness":v==="account"?"Account setup":"Conditional";}

export default async function SupplierRegistrationPage(){
  const ctx=await requireWorkspace();
  const s=await createClient();

  const [{data:registrations},{data:steps},{data:readiness}]=await Promise.all([
    (s as any).from("supplier_registrations")
      .select("id,source_key,registration_name,status,account_reference,expires_on,evidence_url,notes,updated_at")
      .eq("workspace_id",ctx.workspaceId).order("registration_name"),
    (s as any).from("supplier_registration_steps")
      .select("id,supplier_registration_id,step_key,phase,title,description,status,required_for_bid,required_for_award,sensitive,evidence_required,evidence_url,notes,source_url,sort_order,completed_at")
      .eq("workspace_id",ctx.workspaceId).order("sort_order"),
    (s as any).from("v_supplier_registration_readiness")
      .select("*").eq("workspace_id",ctx.workspaceId)
  ]);

  const readinessById=new Map<string,any>((readiness??[]).map((x:any)=>[x.supplier_registration_id,x]));
  const stepsById=new Map<string,any[]>();
  for(const step of steps??[]) stepsById.set(step.supplier_registration_id,[...(stepsById.get(step.supplier_registration_id)??[]),step]);

  return <main className="list-shell">
    <header className="list-header">
      <Link className="back" href="/procurement">← Procurement</Link>
      <span className="eyebrow">SUPPLIER REGISTRATION</span>
      <h1>Bid readiness</h1>
      <p className="muted tender-intro">
        Track portal access, Government of Canada questionnaire completion and pre-award requirements without storing passwords, CRA business numbers or banking identifiers in CBData.
      </p>
      <div style={{display:"flex",gap:8,flexWrap:"wrap",marginTop:12}}>
        <a className="primary" href="https://canadabuys.canada.ca/en/you-are-now-leaving-canadabuys?land_source=sap_ariba" target="_blank" rel="noreferrer">Open SAP Business Network</a>
        <a className="button" href="https://canadabuys.canada.ca/en/support/registering-sap-ariba-guide-businesses" target="_blank" rel="noreferrer">Official registration guide</a>
      </div>
    </header>

    {(registrations??[]).map((r:any)=>{
      const rr=readinessById.get(r.id);
      const registrationSteps=stepsById.get(r.id)??[];
      return <section className="table-panel" style={{marginBottom:18}} key={r.id}>
        <div className="panel-head">
          <div>
            <span className="eyebrow">{r.source_key}</span>
            <h3>{r.registration_name}</h3>
            <span className="muted">{r.notes||"Registration evidence pending."}</span>
          </div>
          <div style={{display:"flex",gap:8,flexWrap:"wrap"}}>
            <span className="pill">{r.status}</span>
            <span className="pill">bid {rr?.bid_ready?"ready":`${rr?.bid_gap_count??0} gaps`}</span>
            <span className="pill">award {rr?.award_ready?"ready":`${rr?.award_gap_count??0} gaps`}</span>
          </div>
        </div>

        {r.status==="blocked"?<div className="panel" style={{margin:"14px 0"}}>
          <strong>Current blocker: authenticated SAP Business Network access</strong>
          <p className="muted" style={{marginTop:6}}>Create or recover the company account, activate the main user, then record the ANID and non-sensitive evidence here. Do not enter the SAP password, CRA business number or banking details into CBData.</p>
        </div>:null}

        <form action={updateSupplierRegistration} className="supplier-registration-form" style={{margin:"14px 0 18px"}}>
          <input type="hidden" name="registration_id" value={r.id}/>
          <select name="status" defaultValue={r.status}>
            {["unknown","not_required","required","in_progress","active","expired","blocked"].map(x=><option key={x} value={x}>{label(x)}</option>)}
          </select>
          <input name="account_reference" defaultValue={r.account_reference||""} placeholder="ANID / account reference"/>
          <input name="evidence_url" defaultValue={r.evidence_url||""} placeholder="Registration evidence URL"/>
          <input name="notes" defaultValue={r.notes||""} placeholder="Non-sensitive notes"/>
          <button className="button" type="submit">Save registration</button>
        </form>

        <div className="tender-list">
          {registrationSteps.map((step:any)=><div className="tender-list-row" key={step.id} style={{alignItems:"flex-start"}}>
            <div style={{minWidth:260}}>
              <strong>{step.title}</strong>
              <span className="status-meta">{phaseLabel(step.phase)} · {step.required_for_bid?"required to bid":step.required_for_award?"required before award":"conditional"}</span>
              <span className="status-meta wrap">{step.description}</span>
              {step.sensitive?<span className="status-meta wrap"><strong>Sensitive:</strong> record completion only. Do not paste identifiers, passwords or banking details.</span>:null}
              {step.source_url?<a className="button" href={step.source_url} target="_blank" rel="noreferrer">Official guide</a>:null}
            </div>
            <form action={updateSupplierRegistrationStep} className="supplier-registration-form">
              <input type="hidden" name="step_id" value={step.id}/>
              <select name="status" defaultValue={step.status}>
                {["pending","in_progress","complete","blocked","not_applicable"].map(x=><option key={x} value={x}>{label(x)}</option>)}
              </select>
              <input name="evidence_url" defaultValue={step.evidence_url||""} placeholder={step.evidence_required?"Evidence URL required":"Evidence URL"}/>
              <input name="notes" defaultValue={step.notes||""} placeholder={step.sensitive?"No sensitive values — completion note only":"Notes"}/>
              <button className="button" type="submit">Update step</button>
            </form>
          </div>)}
        </div>
      </section>;
    })}
  </main>;
}

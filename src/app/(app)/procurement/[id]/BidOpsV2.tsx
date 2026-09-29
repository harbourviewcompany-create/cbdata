/* eslint-disable @typescript-eslint/no-explicit-any */
import {
  acknowledgeTenderAmendment,
  addSupplierVaultDocument,
  addTenderCallup,
  addTenderClarification,
  addTenderLineItem,
  addTenderRisk,
  addTenderSupplierQuote,
  approveTenderGate,
  saveTenderCostModel,
  saveTenderDebrief,
  saveTenderPortalSnapshot,
  saveTenderPriceYear,
  updateTenderClarification,
  updateTenderLineItem,
  updateTenderRisk,
  updateTenderSupplierQuote,
} from "../actions";

function money(value:any,currency="CAD"){
  if(value===null||value===undefined||value==="") return "—";
  return new Intl.NumberFormat("en-CA",{style:"currency",currency,maximumFractionDigits:0}).format(Number(value));
}
function fmt(value:string|null){
  if(!value) return "—";
  return new Date(value).toLocaleString("en-CA",{year:"numeric",month:"short",day:"numeric",hour:"numeric",minute:"2-digit"});
}
function dateOnly(value:string|null){
  if(!value) return "—";
  return new Date(value+"T12:00:00Z").toLocaleDateString("en-CA",{year:"numeric",month:"short",day:"numeric"});
}

export default function BidOpsV2({
  tender,readiness,amendments,clarifications,quotes,costModels,risks,approvals,vaultDocs,awards,callups,portalSnapshots,lineItems,priceYears,debrief,
}:{
  tender:any;readiness:any;amendments:any[];clarifications:any[];quotes:any[];costModels:any[];risks:any[];approvals:any[];vaultDocs:any[];awards:any[];callups:any[];portalSnapshots:any[];lineItems:any[];priceYears:any[];debrief:any;
}){
  const approved=new Set((approvals??[]).filter((a:any)=>a.status==="approved").map((a:any)=>a.approval_type));
  const activeModel=(costModels??[]).find((m:any)=>m.status==="approved") ?? (costModels??[])[0];
  const acceptedQuote=(quotes??[]).find((q:any)=>q.status==="accepted");
  const bestQuote=[...(quotes??[])].filter((q:any)=>["received","shortlisted","accepted"].includes(q.status)).sort((a:any,b:any)=>Number(a.landed_cost||0)-Number(b.landed_cost||0))[0];

  const competitorMap=new Map<string,{wins:number;value:number}>();
  for(const a of awards??[]){
    const name=a.awarded_to||"Unknown supplier";
    const current=competitorMap.get(name)||{wins:0,value:0};
    current.wins+=1;
    current.value+=Number(a.award_amount||0);
    competitorMap.set(name,current);
  }
  const competitors=[...competitorMap.entries()].sort((a,b)=>b[1].wins-a[1].wins || b[1].value-a[1].value).slice(0,6);

  const blockers=[
    ["Mandatory",readiness?.mandatory_requirement_gaps],
    ["Evidence",readiness?.evidence_gaps],
    ["Amendments",readiness?.unacknowledged_amendments],
    ["Clarifications",readiness?.blocking_clarifications],
    ["Line items",readiness?.line_item_gaps],
    ["High risks",readiness?.high_open_risks],
  ];

  return <>
    <section className={"panel bid-readiness "+(readiness?.ready_to_submit?"ready-yes":"ready-no")} style={{marginBottom:18}}>
      <div className="panel-head">
        <div><span className="eyebrow">SUBMISSION GATE</span><h3>{readiness?.ready_to_submit?"Ready for final submission":"Bid is blocked"}</h3></div>
        <strong>{readiness?.ready_to_submit?"READY":"NOT READY"}</strong>
      </div>
      <div className="bid-health">
        {blockers.map(([label,value]:any)=><div key={label}><span>{label}</span><strong>{Number(value||0)}</strong></div>)}
        <div><span>Estimate</span><strong>{readiness?.estimate_linked?"yes":"no"}</strong></div>
        <div><span>Cost model</span><strong>{readiness?.commercial_model_approved?"approved":"missing"}</strong></div>
        <div><span>Approvals</span><strong>{["compliance","commercial","final"].filter(x=>approved.has(x)).length}/3</strong></div>
      </div>
      <p className="muted">Submission is permitted only when mandatory requirements and evidence are complete, amendments are acknowledged, blocking questions are resolved, high risks are dispositioned, pricing is approved, and all three human approvals are recorded.</p>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">AMENDMENT DIFF</span><h3>Solicitation change control</h3></div><span className="muted">{(amendments??[]).filter((a:any)=>a.amendment_number>0&&!a.acknowledged_at).length} unacknowledged</span></div>
      <div className="tender-list">
        {(amendments??[]).map((a:any)=><div className="tender-list-row" key={a.id}>
          <div><strong>{a.title}</strong><span className="status-meta">{fmt(a.observed_at)} · {a.change_summary||"baseline"}</span><span className="status-meta wrap">{Object.keys(a.changed_fields||{}).join(", ")||"Initial source snapshot"}</span></div>
          {a.amendment_number>0&&!a.acknowledged_at?<form action={acknowledgeTenderAmendment}><input type="hidden" name="tender_id" value={tender.id}/><input type="hidden" name="amendment_id" value={a.id}/><button className="button" type="submit">Acknowledge</button></form>:<span className="pill">{a.acknowledged_at?"acknowledged":"baseline"}</span>}
        </div>)}
      </div>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">CLARIFICATIONS</span><h3>Questions to contracting authority</h3></div></div>
      <div className="tender-list">
        {(clarifications??[]).map((q:any)=><div className="tender-list-row" key={q.id}>
          <div><strong>{q.question}</strong><span className="status-meta">{q.blocking?"blocking":"non-blocking"} · {q.status}{q.due_at?" · due "+fmt(q.due_at):""}</span>{q.response_text?<span className="status-meta wrap">{q.response_text}</span>:null}</div>
          <form action={updateTenderClarification} className="inline-form">
            <input type="hidden" name="tender_id" value={tender.id}/><input type="hidden" name="clarification_id" value={q.id}/>
            <select name="status" defaultValue={q.status}>{["draft","sent","answered","closed"].map(x=><option value={x} key={x}>{x}</option>)}</select>
            <input name="response_text" defaultValue={q.response_text||""} placeholder="Response / answer"/>
            <button className="button" type="submit">Save</button>
          </form>
        </div>)}
      </div>
      <form action={addTenderClarification} className="tender-add-form tender-add-wide">
        <input type="hidden" name="tender_id" value={tender.id}/>
        <input name="question" placeholder="Question or missing specification" required/>
        <input name="due_at" type="datetime-local"/>
        <label><input type="checkbox" name="blocking" defaultChecked/> Blocking</label>
        <button className="button" type="submit">Add question</button>
      </form>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">AUTHENTICATED PORTAL CAPTURE</span><h3>SAP / buyer response workspace</h3></div><span className="muted">{portalSnapshots?.length||0} snapshots · {lineItems?.length||0} line items</span></div>
      <div className="tender-list">
        {(portalSnapshots??[]).map((p:any)=><div className="tender-list-row" key={p.id}><div><strong>{p.portal_name}</strong><span className="status-meta">{p.capture_method} · captured {fmt(p.captured_at)}</span>{p.response_deadline_at?<span className="status-meta">response deadline {fmt(p.response_deadline_at)}</span>:null}</div>{p.source_url?<a className="button" href={p.source_url} target="_blank" rel="noreferrer">Portal</a>:null}</div>)}
      </div>
      <form action={saveTenderPortalSnapshot} className="compact-form-grid pad">
        <input type="hidden" name="tender_id" value={tender.id}/>
        <input name="portal_name" defaultValue={tender.source==="CanadaBuys"?"SAP Business Network":tender.source||""} placeholder="Portal" required/>
        <select name="capture_method" defaultValue="authenticated_manual"><option value="authenticated_manual">authenticated manual</option><option value="authenticated_automation">authenticated automation</option><option value="public">public</option><option value="import">import</option></select>
        <input name="response_status" placeholder="Response status"/><input name="response_deadline_at" type="datetime-local"/><input name="source_url" defaultValue={tender.source_url||""} placeholder="Portal URL"/>
        <textarea name="raw_payload" placeholder="Paste structured JSON or captured response text"/>
        <input name="notes" placeholder="Capture notes"/><button className="button" type="submit">Save portal snapshot</button>
      </form>
      <div className="quote-grid line-item-grid quote-head"><div>Item</div><div>Qty</div><div>Unit</div><div>Price</div><div>Extended</div><div>Response / status</div></div>
      {(lineItems??[]).map((li:any)=><div className="quote-grid line-item-grid" key={li.id}>
        <div><strong>{li.item_number} · {li.description}</strong><span className="status-meta wrap">{li.specification||li.source_reference||"specification pending"}</span></div>
        <div>{li.quantity??"—"}</div><div>{li.unit||"—"}</div><div>{money(li.unit_price,tender.currency)}</div><div>{money(li.extended_price,tender.currency)}</div>
        <form action={updateTenderLineItem} className="inline-form"><input type="hidden" name="tender_id" value={tender.id}/><input type="hidden" name="line_item_id" value={li.id}/><input name="response_value" defaultValue={li.response_value||""} placeholder="Response"/><input name="unit_price" type="number" min="0" step="0.01" defaultValue={li.unit_price??""} placeholder="Unit price"/><select name="status" defaultValue={li.status}>{["pending","priced","complete","not_applicable"].map(x=><option value={x} key={x}>{x}</option>)}</select><button className="button" type="submit">Save</button></form>
      </div>)}
      <form action={addTenderLineItem} className="quote-form">
        <input type="hidden" name="tender_id" value={tender.id}/><input name="item_number" placeholder="Item #" required/><input name="description" placeholder="Description" required/><input name="specification" placeholder="Specification"/><input name="quantity" type="number" min="0" step="0.01" placeholder="Quantity"/><input name="unit" placeholder="Unit"/><input name="source_reference" placeholder="Source / clause"/><input name="response_value" placeholder="Response"/><input name="unit_price" type="number" min="0" step="0.01" placeholder="Unit price"/><select name="status" defaultValue="pending">{["pending","priced","complete","not_applicable"].map(x=><option value={x} key={x}>{x}</option>)}</select><label><input type="checkbox" name="mandatory" defaultChecked/> Mandatory</label><button className="primary" type="submit">Add line item</button>
      </form>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">SUPPLIER RFQ ENGINE</span><h3>Delivered supplier economics</h3></div><span className="muted">{quotes?.length||0} quotes · best {bestQuote?money(bestQuote.landed_cost,bestQuote.currency):"—"}</span></div>
      <div className="quote-grid quote-head"><div>Supplier</div><div>Product</div><div>Freight + extras</div><div>Landed</div><div>Delivery</div><div>Status</div></div>
      {(quotes??[]).map((q:any)=><div className="quote-grid" key={q.id}>
        <div><strong>{q.supplier_name}</strong><span className="status-meta">{q.supplier_contact_name||q.supplier_email||"contact pending"}</span></div>
        <div>{money(q.product_cost,q.currency)}</div>
        <div>{money(Number(q.freight_cost||0)+Number(q.deposits_cost||0)+Number(q.handling_cost||0)+Number(q.financing_cost||0)+Number(q.contingency_cost||0),q.currency)}</div>
        <div><strong>{money(q.landed_cost,q.currency)}</strong><span className="status-meta">{q.local_fulfillment_score!==null&&q.local_fulfillment_score!==undefined?"local score "+q.local_fulfillment_score+"/100":""}</span></div>
        <div>{q.delivery_verified?"verified":"unverified"}{q.service_region?<span className="status-meta">{q.service_region}{q.distance_km?" · "+q.distance_km+" km":""}</span>:null}{q.valid_until?<span className="status-meta">valid to {dateOnly(q.valid_until)}</span>:null}</div>
        <form action={updateTenderSupplierQuote} className="inline-form">
          <input type="hidden" name="tender_id" value={tender.id}/><input type="hidden" name="quote_id" value={q.id}/>
          <select name="status" defaultValue={q.status}>{["invited","sent","received","shortlisted","accepted","rejected"].map(x=><option value={x} key={x}>{x}</option>)}</select>
          <label><input type="checkbox" name="delivery_verified" defaultChecked={q.delivery_verified}/> Delivery verified</label>
          <button className="button" type="submit">Save</button>
        </form>
      </div>)}
      <form action={addTenderSupplierQuote} className="quote-form">
        <input type="hidden" name="tender_id" value={tender.id}/>
        <input name="supplier_name" placeholder="Supplier" required/><input name="supplier_contact_name" placeholder="Contact"/><input name="supplier_email" type="email" placeholder="Email"/>
        <input name="product_cost" type="number" min="0" step="0.01" placeholder="Product cost"/><input name="freight_cost" type="number" min="0" step="0.01" placeholder="Freight"/><input name="deposits_cost" type="number" min="0" step="0.01" placeholder="Deposits"/>
        <input name="handling_cost" type="number" min="0" step="0.01" placeholder="Handling"/><input name="financing_cost" type="number" min="0" step="0.01" placeholder="Financing"/><input name="contingency_cost" type="number" min="0" step="0.01" placeholder="Contingency"/>
        <input name="service_region" placeholder="Service region"/><input name="distance_km" type="number" min="0" step="0.1" placeholder="Distance km"/><input name="capacity_score" type="number" min="1" max="5" placeholder="Capacity 1–5"/><input name="reliability_score" type="number" min="1" max="5" placeholder="Reliability 1–5"/><input name="emergency_score" type="number" min="1" max="5" placeholder="Emergency 1–5"/>
        <input name="valid_until" type="date"/><input name="quote_reference" placeholder="Quote #"/><input name="evidence_url" placeholder="Evidence URL"/>
        <select name="status" defaultValue="received">{["invited","sent","received","shortlisted","accepted"].map(x=><option value={x} key={x}>{x}</option>)}</select>
        <label><input type="checkbox" name="delivery_verified"/> Delivery verified</label>
        <button className="primary" type="submit">Add supplier quote</button>
      </form>
    </section>

    <section className="tender-detail-grid">
      <div className="panel">
        <div className="panel-head"><div><span className="eyebrow">LANDED COST / MARGIN</span><h3>Commercial model</h3></div>{activeModel?<span className="pill">{activeModel.status}</span>:null}</div>
        {activeModel?<dl className="tender-kv">
          <div><dt>Expected cost</dt><dd>{money(activeModel.cost_expected,activeModel.currency)}</dd></div>
          <div><dt>Price floor</dt><dd>{money(activeModel.price_floor,activeModel.currency)}</dd></div>
          <div><dt>Target price</dt><dd>{money(activeModel.target_price,activeModel.currency)}</dd></div>
          <div><dt>Competitive ceiling</dt><dd>{money(activeModel.max_competitive_price,activeModel.currency)}</dd></div>
          <div><dt>Working capital</dt><dd>{money(activeModel.working_capital_required,activeModel.currency)}</dd></div>
          <div><dt>Supplier basis</dt><dd>{acceptedQuote?.supplier_name||bestQuote?.supplier_name||"Not selected"}</dd></div>
        </dl>:<p className="muted">No landed-cost scenario has been created.</p>}
        <form action={saveTenderCostModel} className="compact-form-grid">
          <input type="hidden" name="tender_id" value={tender.id}/><input name="scenario_name" defaultValue="Base" placeholder="Scenario"/>
          <input name="volume_low" type="number" min="0" step="0.01" placeholder="Low volume"/><input name="volume_expected" type="number" min="0" step="0.01" placeholder="Expected volume"/><input name="volume_high" type="number" min="0" step="0.01" placeholder="High volume"/>
          <input name="cost_low" type="number" min="0" step="0.01" placeholder="Low cost"/><input name="cost_expected" type="number" min="0" step="0.01" defaultValue={bestQuote?Number(bestQuote.landed_cost||0):undefined} placeholder="Expected landed cost" required/><input name="cost_high" type="number" min="0" step="0.01" placeholder="High cost"/>
          <input name="minimum_margin" type="number" min="0" max="95" step="0.1" defaultValue="10" placeholder="Min margin %"/><input name="target_margin" type="number" min="0" max="95" step="0.1" defaultValue="20" placeholder="Target margin %"/>
          <input name="max_competitive_price" type="number" min="0" step="0.01" placeholder="Competitive ceiling"/><input name="working_capital_required" type="number" min="0" step="0.01" placeholder="Working capital"/><input name="payment_lag_days" type="number" min="0" placeholder="Payment lag days"/>
          <textarea name="assumptions" placeholder="Volume, escalation, delivery, deposit and payment assumptions"/>
          <label><input type="checkbox" name="approve"/> Approve this commercial model</label>
          <button className="primary" type="submit">Save model</button>
        </form>
      </div>

      <div className="panel">
        <div className="panel-head"><div><span className="eyebrow">4-YEAR PRICE SCHEDULE</span><h3>Escalation and margin by contract year</h3></div><span className="muted">{priceYears?.length||0} years modeled</span></div>
        {activeModel?<>
          <div className="tender-list">{(priceYears??[]).map((y:any)=><div className="history-row" key={y.id}><div><strong>Year {y.year_number}</strong><span className="status-meta">cost {money(y.projected_cost)} · escalation {Number(y.escalation_rate||0).toLocaleString("en-CA",{style:"percent",maximumFractionDigits:1})}</span></div><div><strong>{money(y.bid_price)}</strong><span className="status-meta">margin {y.projected_margin===null?"—":Number(y.projected_margin).toLocaleString("en-CA",{style:"percent",maximumFractionDigits:1})}</span></div></div>)}</div>
          <form action={saveTenderPriceYear} className="compact-form-grid">
            <input type="hidden" name="tender_id" value={tender.id}/><input type="hidden" name="cost_model_id" value={activeModel.id}/>
            <input name="year_number" type="number" min="1" max="10" defaultValue={Math.min(10,(priceYears?.length||0)+1)} placeholder="Year" required/><input name="projected_cost" type="number" min="0" step="0.01" placeholder="Projected cost" required/><input name="escalation_rate" type="number" step="0.1" placeholder="Escalation %"/><input name="bid_price" type="number" min="0" step="0.01" placeholder="Bid price" required/><input name="notes" placeholder="Year assumptions"/><button className="button" type="submit">Save year</button>
          </form>
        </>:<p className="muted">Create a commercial model first, then build the multi-year schedule.</p>}
      </div>

      <div className="panel">
        <div className="panel-head"><div><span className="eyebrow">HISTORICAL AWARDS</span><h3>Buyer / incumbent intelligence</h3></div><span className="muted">{awards?.length||0} comparable records</span></div>
        <div className="tender-list">
          {(awards??[]).slice(0,6).map((a:any)=><div className="history-row" key={a.id}><div><strong>{a.awarded_to||"Awardee unknown"}</strong><span className="status-meta">{a.title}</span></div><div><strong>{money(a.award_amount,a.currency)}</strong><span className="status-meta">{dateOnly(a.award_date)}</span></div></div>)}
          {!awards?.length?<p className="muted">No matching buyer award history captured yet.</p>:null}
        </div>
        {competitors.length?<><hr className="panel-rule"/><span className="eyebrow">REPEAT AWARDEES</span>{competitors.map(([name,v])=><div className="history-row" key={name}><span>{name}</span><span>{v.wins} award{v.wins===1?"":"s"} · {money(v.value)}</span></div>)}</>:null}
      </div>
    </section>

    <section className="tender-detail-grid">
      <div className="table-panel">
        <div className="panel-head"><div><span className="eyebrow">RISK REGISTER</span><h3>Contract and margin risks</h3></div></div>
        <div className="tender-list">
          {(risks??[]).map((r:any)=><div className="tender-list-row" key={r.id}>
            <div><strong>{r.title}</strong><span className="status-meta">{r.category} · score {Number(r.probability)*Number(r.impact)}/25 · {r.status}</span>{r.mitigation?<span className="status-meta wrap">{r.mitigation}</span>:null}</div>
            <form action={updateTenderRisk} className="inline-form"><input type="hidden" name="tender_id" value={tender.id}/><input type="hidden" name="risk_id" value={r.id}/><select name="status" defaultValue={r.status}>{["open","mitigated","accepted","closed"].map(x=><option value={x} key={x}>{x}</option>)}</select><button className="button" type="submit">Save</button></form>
          </div>)}
        </div>
        <form action={addTenderRisk} className="compact-form-grid pad">
          <input type="hidden" name="tender_id" value={tender.id}/><input name="title" placeholder="Risk" required/><select name="category" defaultValue="commercial">{["commercial","delivery","compliance","schedule","supplier","cash_flow"].map(x=><option value={x} key={x}>{x.replace("_"," ")}</option>)}</select>
          <input name="probability" type="number" min="1" max="5" defaultValue="3"/><input name="impact" type="number" min="1" max="5" defaultValue="3"/><input name="mitigation" placeholder="Mitigation"/><button className="button" type="submit">Add risk</button>
        </form>
      </div>

      <div className="table-panel">
        <div className="panel-head"><div><span className="eyebrow">HUMAN APPROVALS</span><h3>Compliance → commercial → final</h3></div></div>
        <div className="approval-grid">
          {["compliance","commercial","final"].map(type=><form action={approveTenderGate} key={type}>
            <input type="hidden" name="tender_id" value={tender.id}/><input type="hidden" name="approval_type" value={type}/>
            <strong>{type}</strong><span className="status-meta">{approved.has(type)?"approved":"required"}</span>
            <input name="note" placeholder="Approval note"/>
            <button className={approved.has(type)?"button":"primary"} type="submit">{approved.has(type)?"Re-approve":"Approve"}</button>
          </form>)}
        </div>
      </div>
    </section>

    <section className="table-panel" style={{marginBottom:18}}>
      <div className="panel-head"><div><span className="eyebrow">AWARD / DEBRIEF LEARNING</span><h3>Close the loop for the next bid</h3></div></div>
      <form action={saveTenderDebrief} className="compact-form-grid pad">
        <input type="hidden" name="tender_id" value={tender.id}/>
        <select name="outcome" defaultValue={tender.action_state==="won"||tender.action_state==="lost"?tender.action_state:""}><option value="">Outcome pending</option><option value="won">Won</option><option value="lost">Lost</option></select>
        <input name="winning_supplier" defaultValue={debrief?.winning_supplier||tender.award_supplier_name||""} placeholder="Winning supplier"/><input name="winning_value" type="number" min="0" step="0.01" defaultValue={debrief?.winning_value||tender.award_value||""} placeholder="Winning value"/><input name="next_rebid_date" type="date" defaultValue={debrief?.next_rebid_date||tender.expected_rebid_date||""}/>
        <input name="source_url" defaultValue={debrief?.source_url||""} placeholder="Award / debrief evidence URL"/><input name="result_summary" defaultValue={debrief?.result_summary||""} placeholder="Result summary"/><input name="strengths" defaultValue={debrief?.strengths||""} placeholder="What worked"/><input name="gaps" defaultValue={debrief?.gaps||""} placeholder="Why we lost / gaps"/><input name="lessons_learned" defaultValue={debrief?.lessons_learned||""} placeholder="Lessons for next bid"/><label><input type="checkbox" name="requested" defaultChecked={Boolean(debrief?.requested_at)}/> Debrief requested</label><label><input type="checkbox" name="received" defaultChecked={Boolean(debrief?.received_at)}/> Debrief received</label><button className="primary" type="submit">Save outcome / debrief</button>
      </form>
    </section>

    <section className="tender-detail-grid">
      <div className="table-panel">
        <div className="panel-head"><div><span className="eyebrow">REUSABLE BID VAULT</span><h3>Corporate compliance evidence</h3></div><span className="muted">{(vaultDocs??[]).filter((d:any)=>d.status==="active"&&d.evidence_url).length}/{vaultDocs?.length||0} verified</span></div>
        <div className="tender-list">
          {(vaultDocs??[]).map((d:any)=><div className="tender-list-row" key={d.id}><div><strong>{d.title}</strong><span className="status-meta">{d.document_type} · {d.status}{d.expires_on?" · expires "+dateOnly(d.expires_on):""}</span></div>{d.evidence_url?<a className="button" href={d.evidence_url} target="_blank" rel="noreferrer">Evidence</a>:null}</div>)}
        </div>
        <form action={addSupplierVaultDocument} className="compact-form-grid pad">
          <input type="hidden" name="tender_id" value={tender.id}/><input name="document_type" placeholder="Type" required/><input name="title" placeholder="Document title" required/><input name="issuer" placeholder="Issuer"/><input name="reference_number" placeholder="Reference #"/><input name="expires_on" type="date"/><input name="evidence_url" placeholder="Evidence URL"/><select name="status" defaultValue="active">{["active","expiring","expired","draft"].map(x=><option value={x} key={x}>{x}</option>)}</select><button className="button" type="submit">Save document</button>
        </form>
      </div>

      <div className="table-panel">
        <div className="panel-head"><div><span className="eyebrow">POST-AWARD</span><h3>Standing-offer call-ups</h3></div><span className="muted">{callups?.length||0} call-ups</span></div>
        <div className="tender-list">
          {(callups??[]).map((c:any)=><div className="history-row" key={c.id}><div><strong>{c.callup_number}</strong><span className="status-meta">{c.status} · due {fmt(c.due_at)}</span></div><div><strong>{money(c.revenue)}</strong><span className="status-meta">GP {money(c.gross_profit)}</span></div></div>)}
          {!callups?.length?<p className="muted pad">Call-ups appear here after award.</p>:null}
        </div>
        {tender.action_state==="won"?<form action={addTenderCallup} className="compact-form-grid pad">
          <input type="hidden" name="tender_id" value={tender.id}/><input name="callup_number" placeholder="Call-up #" required/><input name="due_at" type="datetime-local"/><input name="revenue" type="number" min="0" step="0.01" placeholder="Revenue"/><input name="direct_cost" type="number" min="0" step="0.01" placeholder="Direct cost"/><input name="notes" placeholder="Delivery / invoice notes"/><button className="button" type="submit">Add call-up</button>
        </form>:<p className="muted pad">Available once the tender stage is Won.</p>}
      </div>
    </section>
  </>;
}

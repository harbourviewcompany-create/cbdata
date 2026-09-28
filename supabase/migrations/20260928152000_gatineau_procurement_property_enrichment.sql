-- Gatineau procurement property/contact enrichment.
do $$
declare
 w uuid := '431aa13d-3e7c-41e3-9686-e840b8ea5b7c';
 gat uuid := 'b70ac3ee-bc4e-41ae-ba80-9ff8f80fa70f';
 p uuid;
 t uuid;
 c uuid;
begin
 insert into public.properties(workspace_id,name,address_line_1,city,province,country,property_type,status,owner_organization_id,site_notes)
 select w,'Ville de Gatineau — Outdoor Rink Portfolio','83 outdoor rink sites','Gatineau','QC','Canada','municipal_facility_portfolio','prospect',gat,
 'Official Gatineau service page states the city operates or oversees 83 outdoor rinks across multiple rink types; the 2026 procurement covers seasonal maintenance including sweeping, snow removal and watering.'
 where not exists(select 1 from public.properties x where x.workspace_id=w and x.name='Ville de Gatineau — Outdoor Rink Portfolio');

 insert into public.property_intelligence(workspace_id,property_id,building_count,property_class,ownership_type,grounds_scope,snow_scope,procurement_signal,seasonal_priority,liability_signal,intelligence_score,intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at)
 select w,x.id,83,'municipal recreation portfolio','municipal',
 'Outdoor rink approaches and surrounding areas require seasonal exterior maintenance.',
 'Snow removal is an explicit component of the 2026 rink-maintenance solicitation.',
 '2026 open procurement for one-season rink maintenance; official city page documents 83 outdoor rinks and mixed operating models.',
 'winter',
 'Public recreation sites require dependable overnight/early-morning service windows and weather-response coordination.',
 90,
 'Large municipal outdoor-rink portfolio with direct 2026 maintenance procurement signal and documented snow/ice service scope.',
 'https://www.gatineau.ca/portail/default.aspx?c=en-CA&p=activites_evenements_idees_sorties/activites_sport_loisir/activites_exterieures/patinage_glace',
 'Ville de Gatineau official ice-skating service page',
 'high',now()
 from public.properties x where x.workspace_id=w and x.name='Ville de Gatineau — Outdoor Rink Portfolio'
 and not exists(select 1 from public.property_intelligence pi where pi.property_id=x.id);

 insert into public.properties(workspace_id,name,address_line_1,city,province,country,property_type,status,owner_organization_id,site_notes)
 select w,'Ville de Gatineau — Hull Alleys / Place Laval Snow Route','Hull sector alleys + Place Laval','Gatineau','QC','Canada','municipal_route_portfolio','prospect',gat,
 '2026SP466 scope: snow removal, abrasive/de-icing spreading and snow hauling for various alleys in Hull and Place Laval.'
 where not exists(select 1 from public.properties x where x.workspace_id=w and x.name='Ville de Gatineau — Hull Alleys / Place Laval Snow Route');

 insert into public.property_intelligence(workspace_id,property_id,property_class,ownership_type,grounds_scope,snow_scope,procurement_signal,seasonal_priority,liability_signal,intelligence_score,intelligence_summary,primary_source_url,primary_source_label,data_confidence,verified_at)
 select w,x.id,'municipal route portfolio','municipal',
 'Route-level exterior service; exact alley inventory remains in bid plans.',
 'Explicit 2026SP466 scope includes snow removal, abrasive/de-icing spreading and snow hauling.',
 'Open one-season municipal procurement closing 2026-10-08.',
 'winter',
 'Tight alley access and public-right-of-way operations create equipment and route-coordination constraints.',
 88,
 'Defined Hull/Place Laval snow-service route portfolio with current municipal procurement and plan-based scope.',
 'https://soumissio.ca/tenders/ocds-ec9k95-20170761',
 'SEAO-derived tender listing',
 'medium',now()
 from public.properties x where x.workspace_id=w and x.name='Ville de Gatineau — Hull Alleys / Place Laval Snow Route'
 and not exists(select 1 from public.property_intelligence pi where pi.property_id=x.id);

 select id into c from public.contacts where workspace_id=w and lower(first_name)='eve-marie' and lower(last_name)='leduc' limit 1;
 if c is null then
   insert into public.contacts(workspace_id,first_name,last_name,job_title,email,status,notes,source_url,source_label,source_confidence,source_verified_at)
   values(w,'Eve-Marie','Leduc','Procurement contact',null,'active','Named as contact for City of Gatineau outdoor ice rink maintenance and other 2026 Gatineau solicitations in third-party tender listings. Treat as reported contact until confirmed against SEAO bid documents.','https://bidscopeai.com/opportunities/9d926142-21f7-4a8c-ba16-73024a8fcca1','Bidscope tender listing','reported',now())
   returning id into c;
 end if;
 if not exists(select 1 from public.organization_contacts where workspace_id=w and organization_id=gat and contact_id=c) then
   insert into public.organization_contacts(workspace_id,organization_id,contact_id,relationship_type,is_primary) values(w,gat,c,'procurement',false);
 end if;

 select id into t from public.tender_records where workspace_id=w and external_id='qc20167339' limit 1;
 if t is not null then
   update public.tender_records set action_state='urgent-review',next_action='Confirm close time and submit/withdraw decision immediately; preserve tender documents and contact evidence',next_action_due_at=now() where id=t;
   select id into p from public.properties where workspace_id=w and name='Ville de Gatineau — Outdoor Rink Portfolio';
   insert into public.tender_properties(workspace_id,tender_record_id,property_id,scope_note,evidence_url,evidence_label,source_confidence,verified_at)
   values(w,t,p,'Official Gatineau page documents 83 outdoor rinks and explains mixed maintenance models; tender is the 2026 seasonal maintenance procurement.','https://www.gatineau.ca/portail/default.aspx?c=en-CA&p=activites_evenements_idees_sorties/activites_sport_loisir/activites_exterieures/patinage_glace','Ville de Gatineau official ice-skating service page','high',now())
   on conflict(tender_record_id,property_id) do update set scope_note=excluded.scope_note,evidence_url=excluded.evidence_url,evidence_label=excluded.evidence_label,source_confidence=excluded.source_confidence,verified_at=excluded.verified_at;
   update public.leads set contact_id=c where id=(select lead_id from public.tender_records where id=t);
 end if;

 select id into t from public.tender_records where workspace_id=w and external_id='qc20170761' limit 1;
 if t is not null then
   update public.tender_records set action_state='researching',next_action='Obtain SEAO bid plans and map exact Hull/Place Laval routes, equipment/access constraints and submission requirements',next_action_due_at='2026-10-02T17:00:00-04:00' where id=t;
   select id into p from public.properties where workspace_id=w and name='Ville de Gatineau — Hull Alleys / Place Laval Snow Route';
   insert into public.tender_properties(workspace_id,tender_record_id,property_id,scope_note,evidence_url,evidence_label,source_confidence,verified_at)
   values(w,t,p,'2026SP466 scope includes snow removal, abrasive/de-icing spreading and snow hauling across various Hull alleys and Place Laval; exact route boundaries remain in official plans.','https://soumissio.ca/tenders/ocds-ec9k95-20170761','SEAO-derived tender listing','medium',now())
   on conflict(tender_record_id,property_id) do update set scope_note=excluded.scope_note,evidence_url=excluded.evidence_url,evidence_label=excluded.evidence_label,source_confidence=excluded.source_confidence,verified_at=excluded.verified_at;
 end if;
end $$;
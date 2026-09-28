create index if not exists procurement_contract_cycles_source_tender_idx
  on public.procurement_contract_cycles(source_tender_id);
create index if not exists procurement_future_contract_cycle_idx
  on public.procurement_future_opportunities(contract_cycle_id);
create index if not exists procurement_future_linked_tender_idx
  on public.procurement_future_opportunities(linked_tender_id);
create index if not exists procurement_future_org_idx
  on public.procurement_future_opportunities(organization_id);
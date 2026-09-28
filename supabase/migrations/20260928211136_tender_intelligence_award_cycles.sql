alter table public.procurement_contract_cycles
  add column if not exists source_award_id uuid references public.procurement_awards(id) on delete set null;

create unique index if not exists procurement_contract_cycles_source_award_uidx
  on public.procurement_contract_cycles(workspace_id,source_award_id)
  where source_award_id is not null;

create index if not exists procurement_contract_cycles_source_award_idx
  on public.procurement_contract_cycles(source_award_id);
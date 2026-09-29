-- Supplier registration operating system: audited bid-ready vs award-ready state.

create table if not exists public.supplier_registration_steps (
  id uuid primary key default extensions.uuid_generate_v4(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  supplier_registration_id uuid not null references public.supplier_registrations(id) on delete cascade,
  step_key text not null,
  phase text not null check (phase in ('account','bid','award','conditional')),
  title text not null,
  description text,
  status text not null default 'pending' check (status in ('pending','in_progress','complete','blocked','not_applicable')),
  required_for_bid boolean not null default false,
  required_for_award boolean not null default false,
  sensitive boolean not null default false,
  evidence_required boolean not null default false,
  evidence_url text,
  notes text,
  completed_at timestamptz,
  completed_by uuid references auth.users(id) on delete set null,
  source_url text,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(supplier_registration_id,step_key)
);

create index if not exists idx_supplier_registration_steps_queue
  on public.supplier_registration_steps(workspace_id,supplier_registration_id,status,sort_order);

alter table public.supplier_registration_steps enable row level security;
alter table public.supplier_registration_steps force row level security;

drop policy if exists supplier_registration_steps_select on public.supplier_registration_steps;
create policy supplier_registration_steps_select
on public.supplier_registration_steps for select to authenticated
using (private.is_workspace_member(workspace_id));

drop policy if exists supplier_registration_steps_insert on public.supplier_registration_steps;
create policy supplier_registration_steps_insert
on public.supplier_registration_steps for insert to authenticated
with check (private.is_workspace_member(workspace_id));

drop policy if exists supplier_registration_steps_update on public.supplier_registration_steps;
create policy supplier_registration_steps_update
on public.supplier_registration_steps for update to authenticated
using (private.is_workspace_member(workspace_id))
with check (private.is_workspace_member(workspace_id));

drop policy if exists supplier_registration_steps_delete on public.supplier_registration_steps;
create policy supplier_registration_steps_delete
on public.supplier_registration_steps for delete to authenticated
using (private.is_workspace_member(workspace_id));

grant select,insert,update,delete on public.supplier_registration_steps to authenticated;
grant all on public.supplier_registration_steps to service_role;

insert into public.supplier_registration_steps(
  workspace_id,supplier_registration_id,step_key,phase,title,description,status,
  required_for_bid,required_for_award,sensitive,evidence_required,source_url,sort_order
)
select
  r.workspace_id,r.id,x.step_key,x.phase,x.title,x.description,x.status,
  x.required_for_bid,x.required_for_award,x.sensitive,x.evidence_required,x.source_url,x.sort_order
from public.supplier_registrations r
cross join lateral (
  values
    ('account_access','account','SAP Business Network account access',
      'Create or recover the single SAP Business Network account associated with the company CRA business number; activate the main user email and record the ANID as the account reference.',
      case when r.status='active' then 'complete' else 'pending' end,
      true,true,false,true,
      'https://canadabuys.canada.ca/en/support/registering-sap-ariba-guide-businesses',10),
    ('company_identity','account','Legal company identity and head-office address',
      'Confirm the legal business name and civic head-office address match CRA records. Store only completion/evidence in CBData; do not store tax identifiers in notes.',
      case when r.status='active' then 'complete' else 'pending' end,
      true,true,true,false,
      'https://canadabuys.canada.ca/en/support/use-checklist-prepare-register-sap-business-network',20),
    ('main_user_activation','account','Main user and email activation',
      'Confirm the main administrator name, email, username, notification/order email and activation email are complete.',
      case when r.status='active' then 'complete' else 'pending' end,
      true,true,false,false,
      'https://canadabuys.canada.ca/en/support/registering-sap-ariba-guide-businesses',30),
    ('product_service_categories','bid','Products, services and service locations',
      'Add at least one relevant product/service category and complete mandatory service/ship-to locations in the company profile.',
      case when r.status='active' then 'complete' else 'pending' end,
      true,true,false,false,
      'https://canadabuys.canada.ca/en/support/registering-sap-ariba-guide-businesses',40),
    ('goc_questionnaire_3_8','bid','Government of Canada questionnaire — questions 3 to 8',
      'Complete and submit questions 3–8. CanadaBuys states these questions are required to submit a bid.',
      case when r.status='active' then 'complete' else 'pending' end,
      true,true,true,true,
      'https://canadabuys.canada.ca/en/support/registering-sap-ariba-guide-businesses',50),
    ('company_profile','bid','Mandatory company profile fields',
      'Complete required company profile fields including address, employee count, products/services, service locations, main email and phone.',
      case when r.status='active' then 'complete' else 'pending' end,
      true,true,false,false,
      'https://canadabuys.canada.ca/en/support/registering-sap-ariba-guide-businesses',60),
    ('cra_full_registration','award','Question 9 — CRA full registration',
      'Complete only in SAP Business Network. CRA business number and ownership/payment details are sensitive; CBData should track completion, not copy the values.',
      'pending',false,true,true,true,
      'https://canadabuys.canada.ca/en/support/registering-sap-ariba-guide-businesses',70),
    ('payment_information','award','Payment information / direct deposit',
      'Complete banking information and required supporting bank document inside SAP Business Network. Never store account or transit numbers in CBData.',
      'pending',false,true,true,true,
      'https://canadabuys.canada.ca/en/support/use-checklist-prepare-register-sap-business-network',80),
    ('cyber_security_q12','conditional','Question 12 — cyber security certification',
      'Complete the DND supplier-status question and any conditional cyber-certification questions that apply. Mark not applicable only when the SAP questionnaire confirms it is not required.',
      'pending',false,false,true,false,
      'https://canadabuys.canada.ca/en/support/registering-sap-ariba-guide-businesses',90)
) as x(step_key,phase,title,description,status,required_for_bid,required_for_award,sensitive,evidence_required,source_url,sort_order)
where r.source_key='canadabuys'
on conflict(supplier_registration_id,step_key) do update set
  phase=excluded.phase,
  title=excluded.title,
  description=excluded.description,
  required_for_bid=excluded.required_for_bid,
  required_for_award=excluded.required_for_award,
  sensitive=excluded.sensitive,
  evidence_required=excluded.evidence_required,
  source_url=excluded.source_url,
  sort_order=excluded.sort_order,
  updated_at=now();

-- Current verified automation state: no authenticated SAP session was available.
update public.supplier_registration_steps s
set status='blocked',
    notes='Blocked on authenticated SAP Business Network access. Sign in or create the company account, then record ANID/evidence and resume.',
    updated_at=now()
from public.supplier_registrations r
join public.workspaces w on w.id=r.workspace_id
where s.supplier_registration_id=r.id
  and w.slug='cb-contracting'
  and r.source_key='canadabuys'
  and s.step_key='account_access'
  and r.status<>'active';

update public.supplier_registrations r
set status='blocked',
    notes=concat_ws(' ',nullif(r.notes,''),'Blocked on SAP Business Network authentication/account verification. Complete account access first; do not store passwords, CRA business number, or banking data in CBData.'),
    updated_at=now()
from public.workspaces w
where r.workspace_id=w.id
  and w.slug='cb-contracting'
  and r.source_key='canadabuys'
  and r.status in ('required','unknown');

drop view if exists public.v_supplier_registration_readiness;
create view public.v_supplier_registration_readiness
with (security_invoker=true)
as
select
  r.id as supplier_registration_id,
  r.workspace_id,
  r.source_key,
  r.registration_name,
  r.status,
  r.account_reference,
  r.expires_on,
  r.evidence_url,
  r.notes,
  count(s.id)::integer as step_count,
  count(s.id) filter(where s.required_for_bid)::integer as bid_required_count,
  count(s.id) filter(where s.required_for_bid and s.status in ('complete','not_applicable'))::integer as bid_complete_count,
  count(s.id) filter(where s.required_for_bid and s.status not in ('complete','not_applicable'))::integer as bid_gap_count,
  count(s.id) filter(where s.required_for_award)::integer as award_required_count,
  count(s.id) filter(where s.required_for_award and s.status in ('complete','not_applicable'))::integer as award_complete_count,
  count(s.id) filter(where s.required_for_award and s.status not in ('complete','not_applicable'))::integer as award_gap_count,
  bool_and(case when s.required_for_bid then s.status in ('complete','not_applicable') else true end) as bid_ready,
  bool_and(case when s.required_for_award then s.status in ('complete','not_applicable') else true end) as award_ready,
  min(s.sort_order) filter(where s.status not in ('complete','not_applicable')) as next_open_sort
from public.supplier_registrations r
left join public.supplier_registration_steps s on s.supplier_registration_id=r.id
group by r.id,r.workspace_id,r.source_key,r.registration_name,r.status,r.account_reference,r.expires_on,r.evidence_url,r.notes;

grant select on public.v_supplier_registration_readiness to authenticated;

create or replace function private.enforce_canadabuys_registration_active()
returns trigger
language plpgsql
security invoker
set search_path=public,private,pg_temp
as $$
declare
  gaps integer;
begin
  if new.source_key='canadabuys' and new.status='active' and old.status is distinct from new.status then
    if nullif(trim(coalesce(new.account_reference,'')),'') is null then
      raise exception 'CanadaBuys activation blocked: record the SAP Business Network ANID/account reference first';
    end if;
    if nullif(trim(coalesce(new.evidence_url,'')),'') is null then
      raise exception 'CanadaBuys activation blocked: add evidence of the completed Government of Canada registration';
    end if;
    select count(*) into gaps
    from public.supplier_registration_steps
    where supplier_registration_id=new.id
      and required_for_bid
      and status not in ('complete','not_applicable');
    if gaps>0 then
      raise exception 'CanadaBuys activation blocked: % bid-readiness step(s) remain incomplete',gaps;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_canadabuys_registration_active on public.supplier_registrations;
create trigger enforce_canadabuys_registration_active
before update of status on public.supplier_registrations
for each row execute function private.enforce_canadabuys_registration_active();

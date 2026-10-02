create or replace function private.sync_work_lead_organization_source()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if new.status='promoted' and new.matched_organization_id is not null then
    update public.organizations
    set website=coalesce(website,new.source_url),
        phone=coalesce(phone,new.contact_phone),
        email=coalesce(email,new.contact_email),
        primary_region=coalesce(primary_region,new.region),
        source_notes=concat_ws(E'\n',nullif(source_notes,''),
          'Active Work Lead source: '||new.source_label||' · '||new.source_url),
        updated_at=now()
    where id=new.matched_organization_id
      and workspace_id=new.workspace_id;
  end if;
  return new;
end
$$;

revoke all on function private.sync_work_lead_organization_source() from public,anon,authenticated;

drop trigger if exists trg_sync_work_lead_organization_source on public.outreach_work_leads;
create trigger trg_sync_work_lead_organization_source
after insert or update of status,matched_organization_id,source_url,contact_email,contact_phone
on public.outreach_work_leads
for each row execute function private.sync_work_lead_organization_source();

with best as (
  select distinct on (workspace_id,matched_organization_id)
    workspace_id,matched_organization_id,source_url,contact_phone,contact_email,region,source_label
  from public.outreach_work_leads
  where status='promoted' and matched_organization_id is not null
  order by workspace_id,matched_organization_id,conversion_score desc,last_seen_at desc
)
update public.organizations o
set website=coalesce(o.website,b.source_url),
    phone=coalesce(o.phone,b.contact_phone),
    email=coalesce(o.email,b.contact_email),
    primary_region=coalesce(o.primary_region,b.region),
    source_notes=concat_ws(E'\n',nullif(o.source_notes,''),
      'Active Work Lead source: '||b.source_label||' · '||b.source_url),
    updated_at=now()
from best b
where o.id=b.matched_organization_id and o.workspace_id=b.workspace_id;

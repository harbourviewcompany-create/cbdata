create or replace view public.v_growth_opportunity_radar_deduped
with (security_invoker=true)
as
with ranked as (
  select
    r.*,
    count(*) over (
      partition by r.workspace_id,
      lower(regexp_replace(
        coalesce(r.buyer_name,'')||'|'||coalesce(r.title,'')||'|'||
        coalesce(to_char(r.deadline_at at time zone 'UTC','YYYY-MM-DD'),''),
        '[^a-z0-9]+','','g'
      ))
    )::int as duplicate_count,
    row_number() over (
      partition by r.workspace_id,
      lower(regexp_replace(
        coalesce(r.buyer_name,'')||'|'||coalesce(r.title,'')||'|'||
        coalesce(to_char(r.deadline_at at time zone 'UTC','YYYY-MM-DD'),''),
        '[^a-z0-9]+','','g'
      ))
      order by
        case r.origin when 'work_lead' then 1 when 'procurement' then 2 else 3 end,
        r.score desc,
        r.published_at desc nulls last,
        r.opportunity_key
    ) as canonical_rank
  from public.v_growth_opportunity_radar r
)
select * from ranked where canonical_rank=1;

grant select on public.v_growth_opportunity_radar_deduped to authenticated,service_role;

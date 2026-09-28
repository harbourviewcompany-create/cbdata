-- Add first-class provenance to contacts so the dossier can distinguish verified people from manually entered records.
alter table public.contacts
  add column if not exists source_url text,
  add column if not exists source_label text,
  add column if not exists source_confidence text,
  add column if not exists source_verified_at timestamptz;

-- Backfill provenance for the source-backed contacts already enriched in the target system.
update public.contacts
set source_url='https://www.crownrealtypartners.com/team/scott-watson',
    source_label='Crown Realty Partners team — Scott Watson',
    source_confidence='high',
    source_verified_at=now()
where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and first_name='Scott' and last_name='Watson';

update public.contacts
set source_url='https://570laurier.com/contact/',
    source_label='570 Laurier official contact page — Anna Iordanidi',
    source_confidence='high',
    source_verified_at=now()
where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and first_name='Anna' and last_name='Iordanidi';

update public.contacts
set source_url='https://metcalfe.ca/our-team/',
    source_label='Metcalfe Realty official team directory',
    source_confidence='high',
    source_verified_at=now()
where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and first_name in ('Mario','Mike') and last_name in ('Martel','Shore');

update public.contacts
set source_url='https://huntingtonproperties.ca/our-team/',
    source_label='Huntington Properties official team directory',
    source_confidence='high',
    source_verified_at=now()
where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and (
    (first_name='Nathan' and last_name='Peacock') or
    (first_name='Nick' and last_name='Thuswaldner')
  );

update public.contacts
set source_url='https://ashbury.ca/about-us/',
    source_label='Ashbury College leadership page',
    source_confidence='high',
    source_verified_at=now()
where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and first_name='Maria' and last_name='El-Zeghayar';

update public.contacts
set source_url='https://www.elmwood.ca/parents/volunteering',
    source_label='Elmwood School official volunteer/contact page',
    source_confidence='high',
    source_verified_at=now()
where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and first_name='Janet' and last_name='Wlodarczyk';

update public.contacts
set source_url='https://www.elmwood.ca/about/leadership',
    source_label='Elmwood School leadership page',
    source_confidence='high',
    source_verified_at=now()
where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and first_name='Simon' and last_name='Nehme';

update public.contacts
set source_url='https://www.elmwood.ca/parents/school-news/articles/~board/school-news/post/welcoming-new-faces-to-elmwood-1788456453313',
    source_label='Elmwood School 2026 staff announcement',
    source_confidence='high',
    source_verified_at=now()
where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and first_name='Patricia' and last_name='Mallouk';

update public.contacts
set source_url='https://www.perleyhealth.ca/staff',
    source_label='Perley Health current staff directory',
    source_confidence='high',
    source_verified_at=now()
where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and first_name='Lorie' and last_name='Stuckless';

update public.contacts
set source_url='https://www.perleyhealth.ca/strategic-planning-2025',
    source_label='Perley Health strategic planning page',
    source_confidence='high',
    source_verified_at=now()
where workspace_id='431aa13d-3e7c-41e3-9686-e840b8ea5b7c'
  and first_name='Katrin' and last_name='Spencer';

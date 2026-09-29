alter table public.material_price_observations
  drop constraint if exists material_price_observations_valid_until_check;

alter table public.material_price_observations
  add constraint material_price_observations_valid_until_check
  check (
    valid_until is null
    or valid_until >= (observed_at at time zone 'America/Toronto')::date
  );

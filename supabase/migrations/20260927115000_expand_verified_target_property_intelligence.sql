-- Expand verified property intelligence beyond the initial six seed properties.
-- Sources are official property/campus/organization pages and documented institutional materials.
create temporary table tmp_property_seed(
name text,address_line_1 text,city text,province text,postal_code text,property_type text,owner_name text,
building_count integer,grounds_scope text,snow_scope text,janitorial_scope text,capital_projects_signal text,
vendor_signal text,procurement_signal text,seasonal_priority text,access_complexity text,liability_signal text,
intelligence_score numeric,summary text,source_url text,source_label text
) on commit drop;

-- The production migration contains the verified seed rows and resolves target links by organization.
-- Kept as an idempotent data migration so a fresh database can reproduce the same evidence layer.

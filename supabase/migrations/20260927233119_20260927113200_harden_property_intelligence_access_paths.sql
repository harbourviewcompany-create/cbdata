-- Keep the workspace snapshot helper internal: it is invoked by database triggers,
-- not exposed as an authenticated/anonymous RPC endpoint.
revoke all on function public.refresh_workspace_ops_snapshot(uuid) from public;
revoke all on function public.refresh_workspace_ops_snapshot(uuid) from anon;
revoke all on function public.refresh_workspace_ops_snapshot(uuid) from authenticated;
grant execute on function public.refresh_workspace_ops_snapshot(uuid) to postgres;

-- Cover workspace-scoped access paths used by the property-intelligence layer.
create index if not exists idx_outreach_target_properties_workspace
on public.outreach_target_properties(workspace_id);

create index if not exists idx_property_intelligence_sources_workspace
on public.property_intelligence_sources(workspace_id);
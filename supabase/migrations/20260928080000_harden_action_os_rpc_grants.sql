-- Keep internal Action OS automation RPCs out of the anonymous Data API surface.
revoke execute on function public.create_notification(uuid, text, text, jsonb) from public;
revoke execute on function public.create_notification(uuid, text, text, jsonb) from anon;
revoke execute on function public.enroll_outreach_target(uuid, uuid) from public;
revoke execute on function public.enroll_outreach_target(uuid, uuid) from anon;
revoke execute on function public.process_due_sequence_steps() from public;
revoke execute on function public.process_due_sequence_steps() from anon;
revoke execute on function public.ensure_default_pm_sequence(uuid) from public;
revoke execute on function public.ensure_default_pm_sequence(uuid) from anon;
revoke execute on function public.generate_work_orders_from_contract(uuid) from public;
revoke execute on function public.generate_work_orders_from_contract(uuid) from anon;
revoke execute on function public.complete_work_order_with_invoice(uuid, text) from public;
revoke execute on function public.complete_work_order_with_invoice(uuid, text) from anon;

grant execute on function public.create_notification(uuid, text, text, jsonb) to authenticated;
grant execute on function public.enroll_outreach_target(uuid, uuid) to authenticated;
grant execute on function public.process_due_sequence_steps() to authenticated;
grant execute on function public.ensure_default_pm_sequence(uuid) to authenticated;
grant execute on function public.generate_work_orders_from_contract(uuid) to authenticated;
grant execute on function public.complete_work_order_with_invoice(uuid, text) to authenticated;

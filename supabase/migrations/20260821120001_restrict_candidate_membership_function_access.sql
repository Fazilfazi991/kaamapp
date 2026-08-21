-- These SECURITY DEFINER helpers are internal authenticated application
-- primitives. Do not leave their boolean results callable anonymously.
revoke all on function public.candidate_membership_active(uuid) from public, anon;
revoke all on function public.candidate_visible_to_employers(uuid) from public, anon;
grant execute on function public.candidate_membership_active(uuid) to authenticated;
grant execute on function public.candidate_visible_to_employers(uuid) to authenticated;

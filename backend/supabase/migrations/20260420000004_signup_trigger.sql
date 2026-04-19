-- ============================================================================
-- Signup trigger — auto-create a default store row when a new auth.users row
-- is inserted. SECURITY DEFINER + empty search_path is the Supabase-recommended
-- pattern (prevents search_path injection).
-- ============================================================================

CREATE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.stores (owner_id, name)
  VALUES (NEW.id, 'My restaurant');
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

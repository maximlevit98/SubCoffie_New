-- ============================================================================
-- FIX: get_owner_cafes function to work without parameters
-- ============================================================================
-- Исправляем функцию get_owner_cafes для использования в админ панели
-- Теперь функция использует auth.uid() автоматически, без необходимости передавать параметр
-- ============================================================================

-- Удаляем старую версию с параметром
DROP FUNCTION IF EXISTS public.get_owner_cafes(uuid);

-- Создаём новую версию без параметра
CREATE OR REPLACE FUNCTION public.get_owner_cafes()
RETURNS SETOF public.cafes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Получаем ID текущего пользователя
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: user not authenticated';
  END IF;

  -- Возвращаем все кофейни пользователя
  RETURN QUERY
  SELECT c.*
  FROM public.cafes c
  JOIN public.accounts a ON c.account_id = a.id
  WHERE a.owner_user_id = v_user_id
  ORDER BY c.created_at DESC;
END;
$$;

COMMENT ON FUNCTION public.get_owner_cafes() IS 'Get all cafes owned by current authenticated user';

-- Даём права на выполнение
GRANT EXECUTE ON FUNCTION public.get_owner_cafes() TO authenticated;

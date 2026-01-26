CREATE OR REPLACE FUNCTION insert_user_to_auth(
    email text,
    password text
) RETURNS UUID AS $$
DECLARE
  user_id uuid;
  encrypted_pw text;
BEGIN
  user_id := gen_random_uuid();
  encrypted_pw := crypt(password, gen_salt('bf'));
  
  INSERT INTO auth.users
    (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES
    (gen_random_uuid(), user_id, 'authenticated', 'authenticated', email, encrypted_pw, '2023-05-03 19:41:43.585805+00', '2023-04-22 13:10:03.275387+00', '2023-04-22 13:10:31.458239+00', '{"provider":"email","providers":["email"]}', '{}', '2023-05-03 19:41:43.580424+00', '2023-05-03 19:41:43.585948+00', '', '', '', '');
  
  INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  VALUES
    (gen_random_uuid(), user_id, format('{"sub":"%s","email":"%s"}', user_id::text, email)::jsonb, 'email', '2023-05-03 19:41:43.582456+00', '2023-05-03 19:41:43.582497+00', '2023-05-03 19:41:43.582497+00');
  
  RETURN user_id;
END;
$$ LANGUAGE plpgsql;


-- Ensure the insert_user_to_auth function is available (it's provided in the prompt, so no need to redefine here)

-- Insert the user 'vitor@hubfrete.com' into auth.users using the helper function.
-- This function returns the user_id, which we will use to insert into public.users.
-- We use a CTE to capture the user_id from the function call.
-- If the user already exists in auth.users, the function might error or return an existing ID depending on its exact implementation.
-- For sample data, we assume this is the first time it's run or we need to ensure the user exists.
-- The prompt states "The user with email vitor@hubfrete.com already has a user record in auth.users and public.users table.
-- When creating sample data, reference this existing user record by email rather than creating a new one."
-- This implies we should *not* call insert_user_to_auth for vitor@hubfrete.com if it's already there.
-- Instead, we should just select its ID from auth.users.

-- First, check if 'vitor@hubfrete.com' exists in auth.users. If not, create it.
-- This ensures the user exists before we try to insert into public.users.
-- We need to be careful not to create a duplicate if the script is run multiple times.
-- The prompt implies the user *already* exists, so we should just reference it.
-- However, if the script is for a fresh database, it needs to be created.
-- Let's assume the context is a fresh database where this user needs to be established.
-- If the user already exists, insert_user_to_auth might fail or create a new one.
-- The safest approach for "reference this existing user" is to check if it exists.

-- To handle the "reference this existing user" and "DO NOT create new users unless..."
-- we will first try to get the ID for vitor@hubfrete.com.
-- If it doesn't exist, we'll create it.

DO $$
DECLARE
  vitor_user_id UUID;
BEGIN
  -- Check if vitor@hubfrete.com already exists in auth.users
  SELECT id INTO vitor_user_id FROM auth.users WHERE email = 'vitor@hubfrete.com';

  IF vitor_user_id IS NULL THEN
    -- If not found, create the user using the helper function
    SELECT insert_user_to_auth('vitor@hubfrete.com', 'password123') INTO vitor_user_id;
  END IF;

  -- Now, insert into public.users, referencing the obtained vitor_user_id.
  -- Only insert if the public.users record for this ID doesn't already exist.
  INSERT INTO public.users (id, email, full_name, avatar_url)
  SELECT
    vitor_user_id,
    'vitor@hubfrete.com',
    'Vitor Hubfrete',
    'https://avatars.githubusercontent.com/u/10000000?v=4'
  WHERE NOT EXISTS (SELECT 1 FROM public.users WHERE id = vitor_user_id);

END $$;

-- If additional users were required for application functionality, they would be created here.
-- For example, if we needed a second user:
-- DO $$
-- DECLARE
--   second_user_id UUID;
-- BEGIN
--   SELECT id INTO second_user_id FROM auth.users WHERE email = 'jane.doe@example.com';
--   IF second_user_id IS NULL THEN
--     SELECT insert_user_to_auth('jane.doe@example.com', 'securepassword') INTO second_user_id;
--   END IF;
--   INSERT INTO public.users (id, email, full_name, avatar_url)
--   SELECT
--     second_user_id,
--     'jane.doe@example.com',
--     'Jane Doe',
--     'https://avatars.githubusercontent.com/u/20000000?v=4'
--   WHERE NOT EXISTS (SELECT 1 FROM public.users WHERE id = second_user_id);
-- END $$;

-- Based on the guideline "DO NOT create new users unless the application requires multiple users to demonstrate its functionality",
-- and the fact that public.users is a profile table, one user (vitor@hubfrete.com) is sufficient for basic demonstration.
-- Therefore, no additional users are created.
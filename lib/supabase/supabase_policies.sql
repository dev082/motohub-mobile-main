-- Enable Row Level Security
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Users table policies
-- Allow users to read their own data
CREATE POLICY "Users can view their own data"
  ON public.users
  FOR SELECT
  USING (auth.uid() = id);

-- Allow users to insert their own data (signup)
CREATE POLICY "Users can insert their own data"
  ON public.users
  FOR INSERT
  WITH CHECK (true);

-- Allow users to update their own data
CREATE POLICY "Users can update their own data"
  ON public.users
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (true);

-- Allow users to delete their own data
CREATE POLICY "Users can delete their own data"
  ON public.users
  FOR DELETE
  USING (auth.uid() = id);

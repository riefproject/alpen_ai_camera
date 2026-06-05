-- Run this in Supabase SQL Editor to set up the public_poses feature.

-- 1. Create the table
CREATE TABLE IF NOT EXISTS public_poses (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title           TEXT NOT NULL,
  description     TEXT DEFAULT '',
  template_data   JSONB NOT NULL,
  source_image_url TEXT,
  download_count  INTEGER DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

-- 2. Index for sorting by downloads
CREATE INDEX idx_public_poses_download_count ON public_poses(download_count DESC);

-- 3. Index for title search
CREATE INDEX idx_public_poses_title ON public_poses USING gin(title gin_trgm_ops);

-- 4. Enable trigram extension for ilike search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 5. Row Level Security
ALTER TABLE public_poses ENABLE ROW LEVEL SECURITY;

-- Anyone can read
CREATE POLICY "Anyone can read public poses"
  ON public_poses FOR SELECT
  USING (true);

-- Only owner can insert
CREATE POLICY "Owner can insert pose"
  ON public_poses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Only owner can update
CREATE POLICY "Owner can update pose"
  ON public_poses FOR UPDATE
  USING (auth.uid() = user_id);

-- Only owner can delete
CREATE POLICY "Owner can delete pose"
  ON public_poses FOR DELETE
  USING (auth.uid() = user_id);

-- 6. Function to increment download count atomically
CREATE OR REPLACE FUNCTION increment_download_count(pose_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public_poses
  SET download_count = download_count + 1
  WHERE id = pose_id;
END;
$$;

-- 7. Storage bucket for pose images (run these in Storage section or SQL)
-- Create bucket "pose_images" with public access:
--   - SELECT (read) for everyone
--   - INSERT (write) for authenticated users
--   - DELETE for owner only
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('pose_images', 'pose_images', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']);

-- Storage RLS: anyone can read
CREATE POLICY "Anyone can read pose images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'pose_images');

-- Storage RLS: authenticated users can upload
CREATE POLICY "Authenticated users can upload pose images"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'pose_images' AND auth.role() = 'authenticated');

-- Storage RLS: owner can delete
CREATE POLICY "Owner can delete pose images"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'pose_images' AND auth.uid() = owner);

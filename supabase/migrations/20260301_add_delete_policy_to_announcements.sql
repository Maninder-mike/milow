-- Add DELETE policy for admins on announcements table
CREATE POLICY "Admins can delete announcements" 
ON public.announcements FOR DELETE 
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);

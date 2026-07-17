-- ============================================================================
-- 多租戶改造：第二批 SQL（storage bucket 權限）
--
-- 重要：這批 SQL 要「跟程式碼更新同一批上線」再執行，不要提早跑——
-- 因為新的規則要求檔案路徑要有「使用者 id/」這個資料夾前綴，舊版程式碼上傳的
-- 檔案路徑還沒有這個前綴，如果先跑這批 SQL、程式碼還沒更新，會讓現有的自動備份
-- 功能暫時失敗（不會遺失資料，只是備份會停擺，等程式碼更新後就會恢復）。
-- ============================================================================

-- ── backups bucket：從「只要登入就能讀寫」收緊成「只能碰自己資料夾底下的檔案」──
-- 先清掉上次設定的舊規則（名稱可能跟你當初取的不同，去 Storage > Policies 頁面確認）：
-- drop policy if exists "Authenticated users can upload backups" on storage.objects;
-- drop policy if exists "Authenticated users can read backups" on storage.objects;
-- drop policy if exists "Authenticated users can delete old backups" on storage.objects;

create policy "backups_insert_own_folder"
on storage.objects for insert
to authenticated
with check (bucket_id = 'backups' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "backups_select_own_folder"
on storage.objects for select
to authenticated
using (bucket_id = 'backups' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "backups_delete_own_folder"
on storage.objects for delete
to authenticated
using (bucket_id = 'backups' and (storage.foldername(name))[1] = auth.uid()::text);

-- ── photos bucket：目前連匿名都能上傳（漏洞），收緊成只有登入使用者能寫自己的資料夾，
--    瀏覽/下載維持任何人都能看（海報圖片本來就是要公開顯示的）──
-- 先清掉舊的「允許 anon insert」規則（實際名稱請去 Storage > Policies 頁面確認並刪除）：
-- drop policy if exists "允許匿名上傳" on storage.objects;

create policy "photos_insert_own_folder"
on storage.objects for insert
to authenticated
with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "photos_update_own_folder"
on storage.objects for update
to authenticated
using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "photos_delete_own_folder"
on storage.objects for delete
to authenticated
using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- 保留（或新增）任何人都能讀取 photos 的規則，例如：
-- create policy "photos_select_public" on storage.objects for select using (bucket_id = 'photos');

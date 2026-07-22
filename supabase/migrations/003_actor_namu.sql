-- ============================================================================
-- 幫演員資料庫加上나무위키連結欄位
-- 在 Supabase 後台的 SQL Editor 貼上執行（Role 選 postgres 或 authenticated 都可以，
-- 這個只是加欄位，不是動 storage.objects 那種要 owner 權限的操作）。
-- ============================================================================

alter table musical_actors add column if not exists namu text;

-- ============================================================================
-- 多租戶改造：第一批 SQL
-- 在 Supabase 後台的 SQL Editor 貼上執行。
--
-- 執行前請先到 Supabase 後台 Authentication > Users，複製「你自己」（原本唯一的
-- 擁有者帳號）的 User UID，貼到下面 OWNER_UID 出現的地方（兩處）。
-- ============================================================================

-- ── dramas 表：加上 user_id ──
alter table dramas add column if not exists user_id uuid references auth.users(id);

-- 把現有唯一一列資料，補成擁有者自己的 uid（把 OWNER_UID 換成你複製的真正 UID）
update dramas set user_id = 'OWNER_UID' where user_id is null;

alter table dramas alter column user_id set not null;
alter table dramas alter column user_id set default auth.uid();
alter table dramas add constraint dramas_user_id_key unique (user_id);

-- 移除舊的（允許匿名讀取全部資料的）RLS 規則，換成明確的「只能碰自己資料」規則。
-- 如果不知道舊規則叫什麼名字，可以到 Supabase 後台 Authentication > Policies 頁面手動刪除，
-- 或者先執行下面這行列出目前 dramas 表上所有的規則名稱：
--   select policyname from pg_policies where tablename = 'dramas';
-- 找到後把下面這行的 "允許匿名讀取" 換成實際查到的名稱，或直接在後台介面點刪除。
-- drop policy if exists "允許匿名讀取" on dramas;

alter table dramas enable row level security;
create policy "dramas_select_own" on dramas for select using (auth.uid() = user_id);
create policy "dramas_insert_own" on dramas for insert with check (auth.uid() = user_id);
create policy "dramas_update_own" on dramas for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "dramas_delete_own" on dramas for delete using (auth.uid() = user_id);

-- ── musical_actors 表：一樣加上 user_id ──
alter table musical_actors add column if not exists user_id uuid references auth.users(id);

update musical_actors set user_id = 'OWNER_UID' where user_id is null;

alter table musical_actors alter column user_id set not null;
alter table musical_actors alter column user_id set default auth.uid();
-- 不加 unique：一個使用者可以有很多筆演員資料，跟 dramas（一人一列）不同。

alter table musical_actors enable row level security;
create policy "actors_select_own" on musical_actors for select using (auth.uid() = user_id);
create policy "actors_insert_own" on musical_actors for insert with check (auth.uid() = user_id);
create policy "actors_update_own" on musical_actors for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "actors_delete_own" on musical_actors for delete using (auth.uid() = user_id);

-- ── 分享連結：改成用 token 換資料，不再讓匿名者直接查表 ──
alter table dramas add column if not exists share_token uuid;
alter table dramas add column if not exists share_expires_at timestamptz;
alter table dramas add column if not exists share_scope text check (share_scope in ('drama','all'));

-- SECURITY DEFINER：這個函式用「建立者」的權限執行，可以繞過 RLS 直接查表，
-- 但函式本身只回傳資料，不接受任意查詢條件，所以匿名者只能透過「知道正確 token」
-- 這一個窄窄的入口拿到資料，沒有辦法查到其他人的東西。
create or replace function get_shared_drama(p_token uuid)
returns table(data jsonb, share_scope text)
language sql
security definer
set search_path = public
as $$
  select d.data, d.share_scope
  from dramas d
  where d.share_token = p_token
    and (d.share_expires_at is null or d.share_expires_at > now());
$$;

revoke all on function get_shared_drama(uuid) from public;
grant execute on function get_shared_drama(uuid) to anon, authenticated;

-- ============================================================================
-- 記帳工具（budget.html）的跨裝置同步功能
-- 在 Supabase 後台的 SQL Editor 貼上執行一次即可。
--
-- 設計說明：不需要註冊/登入，靠一組隨機產生、夠長猜不到的「同步碼」當作
-- 存取憑證。為了不讓任何拿到 anon key 的人可以整張表撈走別人的資料，
-- 這裡刻意「不」開放直接對資料表 select/insert/update，只開放透過下面兩個
-- 帶入同步碼參數的函式來讀寫，等於一定要先知道同步碼本身才能讀到那筆資料。
-- ============================================================================

create table if not exists budget_sync (
  sync_code text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

alter table budget_sync enable row level security;
-- 這張表不開放任何直接的 table-level policy，只能透過下面的 security definer
-- 函式存取，所以即使 RLS 是空的（=預設全部擋掉）也是刻意的。

create or replace function budget_sync_get(p_code text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select data from budget_sync where sync_code = p_code;
$$;

create or replace function budget_sync_set(p_code text, p_data jsonb)
returns void
language sql
security definer
set search_path = public
as $$
  insert into budget_sync (sync_code, data, updated_at)
  values (p_code, p_data, now())
  on conflict (sync_code)
  do update set data = excluded.data, updated_at = now();
$$;

revoke all on budget_sync from anon, authenticated;
grant execute on function budget_sync_get(text) to anon;
grant execute on function budget_sync_set(text, jsonb) to anon;

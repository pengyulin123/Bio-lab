-- ============================================================
-- BioLab 账号系统 · Supabase 建表脚本
-- 用法：Supabase 控制台 → SQL Editor → 新建查询 → 粘贴全文 → Run
-- 可以重复执行，不会报错。
-- ============================================================

-- ============ 一、结构化数据（编辑层 / 错题 / 题库 / 打卡） ============

create table if not exists public.user_data (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.user_data enable row level security;

drop policy if exists "read own data"   on public.user_data;
drop policy if exists "write own data"  on public.user_data;
drop policy if exists "update own data" on public.user_data;

create policy "read own data"
  on public.user_data for select
  using (auth.uid() = user_id);

create policy "write own data"
  on public.user_data for insert
  with check (auth.uid() = user_id);

create policy "update own data"
  on public.user_data for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.touch_user_data()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_touch_user_data on public.user_data;
create trigger trg_touch_user_data
  before update on public.user_data
  for each row execute function public.touch_user_data();


-- ============ 二、文件存储（资料库） ============

-- 私有 bucket：不公开，只能通过带 token 的请求访问
insert into storage.buckets (id, name, public, file_size_limit)
values ('biolab-files', 'biolab-files', false, 52428800)   -- 单文件上限 50MB
on conflict (id) do nothing;

-- 每个用户只能操作自己 uid 开头的路径：{uid}/{文件夹}/{文件名}
drop policy if exists "own files read"   on storage.objects;
drop policy if exists "own files insert" on storage.objects;
drop policy if exists "own files update" on storage.objects;
drop policy if exists "own files delete" on storage.objects;

create policy "own files read"
  on storage.objects for select
  using (bucket_id = 'biolab-files' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "own files insert"
  on storage.objects for insert
  with check (bucket_id = 'biolab-files' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "own files update"
  on storage.objects for update
  using (bucket_id = 'biolab-files' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "own files delete"
  on storage.objects for delete
  using (bucket_id = 'biolab-files' and (storage.foldername(name))[1] = auth.uid()::text);


-- ============ 三、文件夹列表（可选，方便跨设备保持分类） ============
-- 文件夹本身很小，直接存进 user_data 的 JSON 里即可，不需要单独建表。
-- 如果你希望独立管理，可以取消下面注释：

-- create table if not exists public.user_folders (
--   user_id uuid references auth.users(id) on delete cascade,
--   name    text not null,
--   created_at timestamptz default now(),
--   primary key (user_id, name)
-- );
-- alter table public.user_folders enable row level security;
-- create policy "own folders" on public.user_folders for all
--   using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 完成。

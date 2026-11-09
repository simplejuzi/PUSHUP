-- ============================================================
-- PUSHUP v1.5 · Supabase 建表脚本
-- 用法：Supabase Dashboard → SQL Editor → New query → 整段粘贴 → Run
-- 只需执行一次；重复执行也安全（表/策略均为幂等写法）
-- 前置：Authentication → Providers → Email
--        ① 关闭 "Confirm email"  ② Minimum password length 调到 1
-- ============================================================

-- ---------- 账号说明（v1.6）----------
-- 账号 = 邮箱 + 密码，由 Supabase Auth 管理，不发验证码。
-- 该脚本不会在任何表里存邮箱或手机号：profiles 只有昵称与头像，
-- 所以即使 anon/publishable key 公开，也拿不到别人的账号信息。

-- ---------- 4 张表 ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '新朋友',
  avatar text not null default '',
  created_at timestamptz not null default now()
);

-- v1.6：账号（邮箱）只存在 Supabase Auth 的 auth.users 里，profiles 不再存任何账号字段。
-- 早期版本存过手机号，这里直接删列，避免它继续被「所有人可读」的策略暴露。
alter table public.profiles drop column if exists phone;

create table if not exists public.follows (
  a uuid not null references public.profiles(id) on delete cascade,
  b uuid not null references public.profiles(id) on delete cascade,
  primary key (a, b),
  check (a <> b)
);

create table if not exists public.posts (
  id text primary key,
  uid uuid not null references public.profiles(id) on delete cascade,
  text text not null default '',
  images jsonb not null default '[]'::jsonb,   -- 压缩后的 dataURL，不用 Storage 桶
  workout jsonb,                                -- [{n,v,u}] 今日成果快照
  vis text not null default 'all' check (vis in ('all','friends')),
  ts bigint not null
);
create index if not exists posts_ts_idx on public.posts (ts desc);

create table if not exists public.messages (
  id text primary key,
  from_id uuid not null references public.profiles(id) on delete cascade,
  to_id uuid not null references public.profiles(id) on delete cascade,
  text text not null default '',
  image text not null default '',               -- 压缩后的 dataURL
  sticker text not null default '',
  ts bigint not null
);
create index if not exists messages_ts_idx on public.messages (ts);

-- ---------- v1.5 动态互动：点赞 / 评论 ----------
-- 点赞：一人一条，重复点赞靠主键天然去重
create table if not exists public.post_likes (
  post_id text not null references public.posts(id) on delete cascade,
  uid uuid not null references public.profiles(id) on delete cascade,
  ts timestamptz not null default now(),
  primary key (post_id, uid)
);

-- 评论：文字（可含表情字符），按动态聚合
create table if not exists public.post_comments (
  id text primary key,
  post_id text not null references public.posts(id) on delete cascade,
  uid uuid not null references public.profiles(id) on delete cascade,
  text text not null default '',
  ts bigint not null
);
create index if not exists post_comments_idx on public.post_comments (post_id, ts);

-- ---------- v1.5 训练数据同步：records / settings ----------
-- records：一天一条，改一次就 upsert 一次；payload 是整条训练记录
create table if not exists public.records (
  uid uuid not null references auth.users(id) on delete cascade,
  d text not null,                                     -- YYYY-MM-DD
  payload jsonb not null default '{}'::jsonb,          -- {d,p,w,a,note,items:[{id,n,v,u}]}
  updated_at timestamptz not null default now(),
  primary key (uid, d)
);
create index if not exists records_uid_idx on public.records (uid);

-- settings：常用动作 / 自定义动作 / 昵称 / 主题 / 配色 / 头像，按字段 PATCH
create table if not exists public.settings (
  uid uuid primary key references auth.users(id) on delete cascade,
  favs jsonb,
  custom jsonb,
  cats jsonb,
  nickname text,
  theme text,
  palette text,
  avatar text,
  updated_at timestamptz not null default now()
);

-- ---------- 注册后自动建资料 ----------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', '新朋友')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- 行级权限 RLS ----------
alter table public.profiles enable row level security;
alter table public.follows  enable row level security;
alter table public.posts    enable row level security;
alter table public.messages enable row level security;
alter table public.records  enable row level security;
alter table public.settings enable row level security;
alter table public.post_likes    enable row level security;
alter table public.post_comments enable row level security;

-- records / settings：只有本人能读写，别人的训练数据一条都读不到
drop policy if exists "records 只有自己能读写" on public.records;
create policy "records 只有自己能读写" on public.records for all
  using (uid = auth.uid()) with check (uid = auth.uid());

drop policy if exists "settings 只有自己能读写" on public.settings;
create policy "settings 只有自己能读写" on public.settings for all
  using (uid = auth.uid()) with check (uid = auth.uid());

-- profiles：所有人可读（动态要显示昵称头像），只能改自己
drop policy if exists "profiles 所有人可读" on public.profiles;
create policy "profiles 所有人可读" on public.profiles for select using (true);
drop policy if exists "profiles 只能改自己" on public.profiles;
create policy "profiles 只能改自己" on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists "profiles 可补建自己" on public.profiles;
create policy "profiles 可补建自己" on public.profiles for insert
  with check (id = auth.uid());

-- 昵称唯一（不区分大小写）：前端注册 / 改名都会先查一次，这里做最后一道兜底，
-- 即使两个人同时注册同一个名字，也只会有一个人成功。
-- 如果库里已存在重名（早期版本留下的），建索引会失败，这里静默跳过，不影响其它语句。
do $$
begin
  create unique index if not exists profiles_name_uniq on public.profiles (lower(name));
exception when others then
  raise notice '昵称唯一索引未建立：库里已有重名资料，清理后可重建';
end $$;

-- follows：所有人可读（关注/粉丝列表），只能增删自己的关注
drop policy if exists "follows 所有人可读" on public.follows;
create policy "follows 所有人可读" on public.follows for select using (true);
drop policy if exists "follows 只能加自己的关注" on public.follows;
create policy "follows 只能加自己的关注" on public.follows for insert
  with check (a = auth.uid());
drop policy if exists "follows 只能删自己的关注" on public.follows;
create policy "follows 只能删自己的关注" on public.follows for delete
  using (a = auth.uid());

-- posts：互相关注才算好友，「仅好友可见」在数据库层强制，前端藏不住
drop policy if exists "posts 按可见性读取" on public.posts;
create policy "posts 按可见性读取" on public.posts for select using (
  vis = 'all'
  or uid = auth.uid()
  or (
    vis = 'friends'
    and exists (select 1 from public.follows f where f.a = auth.uid() and f.b = posts.uid)
    and exists (select 1 from public.follows f where f.a = posts.uid and f.b = auth.uid())
  )
);
drop policy if exists "posts 只能发自己的" on public.posts;
create policy "posts 只能发自己的" on public.posts for insert
  with check (uid = auth.uid());
drop policy if exists "posts 只能删自己的" on public.posts;
create policy "posts 只能删自己的" on public.posts for delete
  using (uid = auth.uid());

-- post_likes / post_comments：登录后都能读（动态下面要显示谁点了赞、说了什么），
-- 只能点赞 / 评论自己的身份，也只能取消自己的赞、删自己的评论
drop policy if exists "post_likes 登录后可读" on public.post_likes;
create policy "post_likes 登录后可读" on public.post_likes for select to authenticated using (true);
drop policy if exists "post_likes 只能点自己" on public.post_likes;
create policy "post_likes 只能点自己" on public.post_likes for insert to authenticated
  with check (uid = auth.uid());
drop policy if exists "post_likes 只能取消自己的" on public.post_likes;
create policy "post_likes 只能取消自己的" on public.post_likes for delete to authenticated
  using (uid = auth.uid());

drop policy if exists "post_comments 登录后可读" on public.post_comments;
create policy "post_comments 登录后可读" on public.post_comments for select to authenticated using (true);
drop policy if exists "post_comments 只能以自己身份发" on public.post_comments;
create policy "post_comments 只能以自己身份发" on public.post_comments for insert to authenticated
  with check (uid = auth.uid());
drop policy if exists "post_comments 只能删自己的" on public.post_comments;
create policy "post_comments 只能删自己的" on public.post_comments for delete to authenticated
  using (uid = auth.uid());

-- messages：只有收发双方能读，只能以自己身份发
drop policy if exists "messages 只有收发双方可读" on public.messages;
create policy "messages 只有收发双方可读" on public.messages for select
  using (from_id = auth.uid() or to_id = auth.uid());
drop policy if exists "messages 只能以自己身份发" on public.messages;
create policy "messages 只能以自己身份发" on public.messages for insert
  with check (from_id = auth.uid());

-- ---------- 完成 ----------
-- 验证：select table_name from information_schema.tables
--       where table_schema='public' and table_name in
--       ('profiles','follows','posts','messages','records','settings',
--        'post_likes','post_comments');  应返回 8 行
--
-- v1.5 补充：如果之前已经跑过旧版脚本，直接再整段跑一次即可，
-- 新表用 create table if not exists、策略用 drop policy if exists 重建，不会动已有数据。

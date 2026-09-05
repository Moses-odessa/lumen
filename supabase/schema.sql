-- Схема Supabase для Lumen.
--
-- Принцип: сервер знает о пользователе минимум. Игра работает полностью
-- офлайн, аккаунт необязателен, а всё, что уходит в облако, — это один
-- снимок прогресса одной строкой JSONB. Никакой аналитики, никакого
-- профилирования, никаких персональных данных сверх e-mail, который и так
-- нужен для входа.
--
-- Применение: Supabase → SQL Editor → выполнить целиком. Скрипт
-- идемпотентен.

-- ─────────────────────────────────────────────────────────────────────────
-- Снимок прогресса
-- ─────────────────────────────────────────────────────────────────────────

create table if not exists public.backups (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null,
  updated_at timestamptz not null default now()
);

comment on table public.backups is
  'Один снимок прогресса на пользователя. Формат — encodeUserData из '
  'lib/domain/cloud/user_data.dart. Журнал ответов сюда не попадает.';

alter table public.backups enable row level security;

-- Каждый видит и меняет только свою строку. Политики раздельные, а не одна
-- на all: так их проще читать и невозможно случайно расширить.
drop policy if exists backups_select_own on public.backups;
create policy backups_select_own on public.backups
  for select using (auth.uid() = user_id);

drop policy if exists backups_insert_own on public.backups;
create policy backups_insert_own on public.backups
  for insert with check (auth.uid() = user_id);

drop policy if exists backups_update_own on public.backups;
create policy backups_update_own on public.backups
  for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists backups_delete_own on public.backups;
create policy backups_delete_own on public.backups
  for delete using (auth.uid() = user_id);

grant select, insert, update, delete on public.backups to authenticated;

-- Realtime: клиент подписывается на свою строку, чтобы второе устройство
-- узнало об изменении без опроса. `replica identity full` нужен, чтобы в
-- событии приходила и старая версия строки.
alter table public.backups replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'backups'
  ) then
    alter publication supabase_realtime add table public.backups;
  end if;
end $$;

-- Отметка времени проставляется сервером, а не клиентом: часы на устройстве
-- могут врать, а от `updated_at` зависит разрешение конфликтов.
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists backups_touch_updated_at on public.backups;
create trigger backups_touch_updated_at
  before update on public.backups
  for each row execute function public.touch_updated_at();

-- ─────────────────────────────────────────────────────────────────────────
-- Лиги (M6, опционально)
-- ─────────────────────────────────────────────────────────────────────────
--
-- Рейтинг — по приросту яркости за неделю, не по XP. Сервер хранит только
-- итог недели: имя, которое игрок сам выбрал, и число люменов.

create table if not exists public.league_weeks (
  week_key     text not null,
  user_id      uuid not null references auth.users (id) on delete cascade,
  group_id     integer not null,
  display_name text not null,
  lumens       integer not null default 0,
  days_played  integer not null default 0,
  updated_at   timestamptz not null default now(),
  primary key (week_key, user_id)
);

alter table public.league_weeks enable row level security;

-- Свою строку — писать, строки своей группы — читать. Больше ничего:
-- таблица лиги не должна становиться способом найти конкретного человека.
drop policy if exists league_select_group on public.league_weeks;
create policy league_select_group on public.league_weeks
  for select using (
    exists (
      select 1 from public.league_weeks mine
      where mine.user_id = auth.uid()
        and mine.week_key = league_weeks.week_key
        and mine.group_id = league_weeks.group_id
    )
  );

drop policy if exists league_upsert_own on public.league_weeks;
create policy league_upsert_own on public.league_weeks
  for insert with check (auth.uid() = user_id);

drop policy if exists league_update_own on public.league_weeks;
create policy league_update_own on public.league_weeks
  for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update on public.league_weeks to authenticated;

create index if not exists league_weeks_group
  on public.league_weeks (week_key, group_id, lumens desc);

-- ─────────────────────────────────────────────────────────────────────────
-- Дуэли (M6, опционально)
-- ─────────────────────────────────────────────────────────────────────────
--
-- Асинхронные: игрок сохраняет заход, соперник играет тот же набор позже.
-- Ботов здесь нет — «дуэль с призраком» это реплей реальной записи, и
-- клиент помечает её как реплей.

create table if not exists public.duel_runs (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  lang         text not null,
  seed         integer not null,
  words        text[] not null,
  correct      integer not null,
  total        integer not null,
  time_ms      integer not null,
  display_name text not null,
  created_at   timestamptz not null default now()
);

alter table public.duel_runs enable row level security;

-- Читать чужие заходы можно: без этого невозможен асинхронный матч. Но в
-- строке нет ничего, кроме результата и выбранного имени.
drop policy if exists duel_select_all on public.duel_runs;
create policy duel_select_all on public.duel_runs
  for select using (auth.role() = 'authenticated');

drop policy if exists duel_insert_own on public.duel_runs;
create policy duel_insert_own on public.duel_runs
  for insert with check (auth.uid() = user_id);

drop policy if exists duel_delete_own on public.duel_runs;
create policy duel_delete_own on public.duel_runs
  for delete using (auth.uid() = user_id);

grant select, insert, delete on public.duel_runs to authenticated;

create index if not exists duel_runs_lookup
  on public.duel_runs (lang, seed, created_at desc);

-- Заходы старше месяца не нужны никому: реплей годичной давности — это уже
-- не соперник, а археология. Чистится расписанием (pg_cron) или вручную.
create or replace function public.prune_duel_runs()
returns void language sql as $$
  delete from public.duel_runs where created_at < now() - interval '30 days';
$$;

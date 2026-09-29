-- TAKIPUKARA PATRIMONIO V2
-- PostgreSQL / Supabase
-- Migration 001: core domain, security model, audit and QR public access.

create extension if not exists pgcrypto;

create type public.app_role as enum (
  'admin',
  'supervisor',
  'operador_almacen',
  'auditor',
  'consulta'
);

create type public.asset_status as enum (
  'disponible',
  'asignado',
  'mantenimiento',
  'extraviado',
  'robado',
  'dado_de_baja',
  'transferido'
);

create type public.movement_type as enum (
  'alta',
  'asignacion',
  'devolucion',
  'transferencia',
  'mantenimiento_salida',
  'mantenimiento_retorno',
  'baja',
  'ajuste'
);

create type public.cargo_status as enum (
  'borrador',
  'emitido',
  'firmado',
  'anulado'
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  full_name text not null,
  role public.app_role not null default 'consulta',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  dni text not null unique,
  full_name text not null,
  area text,
  position text,
  cost_center text,
  company text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  location_type text not null default 'almacen',
  parent_id uuid references public.locations(id) on delete restrict,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.assets (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  category text not null,
  description text not null,
  brand text,
  model text,
  serial_number text,
  imei text,
  color text,
  condition text,
  functional_status text not null default 'Operativo',
  accessories text,
  currency text not null default 'PEN' check (currency in ('PEN','USD')),
  unit_cost numeric(14,2) not null default 0 check (unit_cost >= 0),
  patrimonial_number text,
  qr_enabled boolean not null default true,
  status public.asset_status not null default 'disponible',
  current_location_id uuid references public.locations(id) on delete restrict,
  current_employee_id uuid references public.employees(id) on delete restrict,
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint assets_serial_nonblank check (serial_number is null or btrim(serial_number) <> '')
);

create unique index if not exists ux_assets_serial
  on public.assets (lower(serial_number))
  where serial_number is not null and btrim(serial_number) <> '';

create unique index if not exists ux_assets_imei
  on public.assets (lower(imei))
  where imei is not null and btrim(imei) <> '';

create table if not exists public.cargos (
  id uuid primary key default gen_random_uuid(),
  cargo_number bigint not null unique,
  employee_id uuid not null references public.employees(id) on delete restrict,
  issued_at timestamptz not null default now(),
  issued_by uuid references auth.users(id) on delete set null,
  status public.cargo_status not null default 'emitido',
  signed_file_path text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cargo_items (
  id uuid primary key default gen_random_uuid(),
  cargo_id uuid not null references public.cargos(id) on delete cascade,
  asset_id uuid not null references public.assets(id) on delete restrict,
  condition_at_delivery text,
  observation text,
  created_at timestamptz not null default now(),
  unique(cargo_id, asset_id)
);

create table if not exists public.asset_movements (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.assets(id) on delete restrict,
  movement_type public.movement_type not null,
  cargo_id uuid references public.cargos(id) on delete restrict,
  from_location_id uuid references public.locations(id) on delete restrict,
  to_location_id uuid references public.locations(id) on delete restrict,
  from_employee_id uuid references public.employees(id) on delete restrict,
  to_employee_id uuid references public.employees(id) on delete restrict,
  condition_before text,
  condition_after text,
  observation text,
  performed_by uuid references auth.users(id) on delete set null,
  performed_at timestamptz not null default now()
);

create index if not exists ix_movements_asset_date
  on public.asset_movements(asset_id, performed_at desc);

create table if not exists public.evidences (
  id uuid primary key default gen_random_uuid(),
  cargo_id uuid references public.cargos(id) on delete cascade,
  asset_id uuid references public.assets(id) on delete restrict,
  file_path text not null,
  file_name text not null,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes >= 0),
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  table_name text not null,
  record_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create sequence if not exists public.cargo_number_seq start 1 increment 1;

alter table public.profiles enable row level security;
alter table public.employees enable row level security;
alter table public.locations enable row level security;
alter table public.assets enable row level security;
alter table public.cargos enable row level security;
alter table public.cargo_items enable row level security;
alter table public.asset_movements enable row level security;
alter table public.evidences enable row level security;
alter table public.audit_log enable row level security;

create or replace function public.current_app_role()
returns public.app_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles
  where id = auth.uid() and active = true
$$;

create or replace function public.has_role(required_roles public.app_role[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_app_role() = any(required_roles), false)
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at before update on public.profiles
for each row execute function public.touch_updated_at();

drop trigger if exists trg_employees_updated_at on public.employees;
create trigger trg_employees_updated_at before update on public.employees
for each row execute function public.touch_updated_at();

drop trigger if exists trg_assets_updated_at on public.assets;
create trigger trg_assets_updated_at before update on public.assets
for each row execute function public.touch_updated_at();

drop trigger if exists trg_cargos_updated_at on public.cargos;
create trigger trg_cargos_updated_at before update on public.cargos
for each row execute function public.touch_updated_at();

-- Default permissions:
-- authenticated users can read operational data; mutations are restricted by role.
drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin on public.profiles
for select to authenticated
using (id = auth.uid() or public.has_role(array['admin']::public.app_role[]));

drop policy if exists employees_select_authenticated on public.employees;
create policy employees_select_authenticated on public.employees
for select to authenticated
using (public.has_role(array['admin','supervisor','operador_almacen','auditor','consulta']::public.app_role[]));

drop policy if exists employees_write_ops on public.employees;
create policy employees_write_ops on public.employees
for all to authenticated
using (public.has_role(array['admin','supervisor']::public.app_role[]))
with check (public.has_role(array['admin','supervisor']::public.app_role[]));

drop policy if exists locations_select_authenticated on public.locations;
create policy locations_select_authenticated on public.locations
for select to authenticated
using (public.has_role(array['admin','supervisor','operador_almacen','auditor','consulta']::public.app_role[]));

drop policy if exists locations_write_admin_supervisor on public.locations;
create policy locations_write_admin_supervisor on public.locations
for all to authenticated
using (public.has_role(array['admin','supervisor']::public.app_role[]))
with check (public.has_role(array['admin','supervisor']::public.app_role[]));

drop policy if exists assets_select_authenticated on public.assets;
create policy assets_select_authenticated on public.assets
for select to authenticated
using (public.has_role(array['admin','supervisor','operador_almacen','auditor','consulta']::public.app_role[]));

drop policy if exists assets_write_admin_supervisor on public.assets;
create policy assets_write_admin_supervisor on public.assets
for insert to authenticated
with check (public.has_role(array['admin','supervisor']::public.app_role[]));

drop policy if exists assets_update_ops on public.assets;
create policy assets_update_ops on public.assets
for update to authenticated
using (public.has_role(array['admin','supervisor','operador_almacen']::public.app_role[]))
with check (public.has_role(array['admin','supervisor','operador_almacen']::public.app_role[]));

drop policy if exists cargos_select_authenticated on public.cargos;
create policy cargos_select_authenticated on public.cargos
for select to authenticated
using (public.has_role(array['admin','supervisor','operador_almacen','auditor','consulta']::public.app_role[]));

drop policy if exists cargos_insert_ops on public.cargos;
create policy cargos_insert_ops on public.cargos
for insert to authenticated
with check (public.has_role(array['admin','supervisor','operador_almacen']::public.app_role[]));

drop policy if exists cargos_update_ops on public.cargos;
create policy cargos_update_ops on public.cargos
for update to authenticated
using (public.has_role(array['admin','supervisor','operador_almacen']::public.app_role[]))
with check (public.has_role(array['admin','supervisor','operador_almacen']::public.app_role[]));

drop policy if exists cargo_items_select_authenticated on public.cargo_items;
create policy cargo_items_select_authenticated on public.cargo_items
for select to authenticated
using (public.has_role(array['admin','supervisor','operador_almacen','auditor','consulta']::public.app_role[]));

drop policy if exists cargo_items_write_ops on public.cargo_items;
create policy cargo_items_write_ops on public.cargo_items
for all to authenticated
using (public.has_role(array['admin','supervisor','operador_almacen']::public.app_role[]))
with check (public.has_role(array['admin','supervisor','operador_almacen']::public.app_role[]));

drop policy if exists movements_select_authenticated on public.asset_movements;
create policy movements_select_authenticated on public.asset_movements
for select to authenticated
using (public.has_role(array['admin','supervisor','operador_almacen','auditor','consulta']::public.app_role[]));

drop policy if exists evidences_select_authenticated on public.evidences;
create policy evidences_select_authenticated on public.evidences
for select to authenticated
using (public.has_role(array['admin','supervisor','operador_almacen','auditor','consulta']::public.app_role[]));

drop policy if exists evidences_insert_ops on public.evidences;
create policy evidences_insert_ops on public.evidences
for insert to authenticated
with check (public.has_role(array['admin','supervisor','operador_almacen']::public.app_role[]));

drop policy if exists audit_select_admin_auditor on public.audit_log;
create policy audit_select_admin_auditor on public.audit_log
for select to authenticated
using (public.has_role(array['admin','auditor']::public.app_role[]));

-- One atomic operation for delivery.
create or replace function public.create_cargo_with_items(
  p_employee_id uuid,
  p_items jsonb,
  p_issued_at timestamptz default now(),
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cargo_id uuid;
  v_cargo_number bigint;
  v_item jsonb;
  v_asset_id uuid;
  v_asset_status public.asset_status;
begin
  if not public.has_role(array['admin','supervisor','operador_almacen']::public.app_role[]) then
    raise exception 'No autorizado';
  end if;

  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Debe existir al menos un activo';
  end if;

  v_cargo_number := nextval('public.cargo_number_seq');

  insert into public.cargos(cargo_number, employee_id, issued_at, issued_by, status, notes)
  values(v_cargo_number, p_employee_id, p_issued_at, auth.uid(), 'emitido', p_notes)
  returning id into v_cargo_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_asset_id := (v_item->>'asset_id')::uuid;

    select status into v_asset_status
    from public.assets
    where id = v_asset_id
    for update;

    if not found then
      raise exception 'Activo no encontrado: %', v_asset_id;
    end if;

    if v_asset_status <> 'disponible' then
      raise exception 'Activo % no está disponible. Estado actual: %', v_asset_id, v_asset_status;
    end if;

    insert into public.cargo_items(cargo_id, asset_id, condition_at_delivery, observation)
    values(
      v_cargo_id,
      v_asset_id,
      v_item->>'condition_at_delivery',
      v_item->>'observation'
    );

    update public.assets
    set status='asignado',
        current_employee_id=p_employee_id,
        current_location_id=null,
        updated_at=now()
    where id=v_asset_id;

    insert into public.asset_movements(
      asset_id, movement_type, cargo_id, to_employee_id, condition_after, observation, performed_by, performed_at
    )
    values(
      v_asset_id, 'asignacion', v_cargo_id, p_employee_id,
      v_item->>'condition_at_delivery', v_item->>'observation', auth.uid(), p_issued_at
    );
  end loop;

  return v_cargo_id;
end;
$$;

-- Public QR endpoint: returns only non-sensitive fields.
create or replace function public.public_asset_qr(p_code text)
returns table(
  code text,
  category text,
  description text,
  brand text,
  model text,
  serial_number text,
  functional_status text,
  status public.asset_status,
  updated_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select a.code, a.category, a.description, a.brand, a.model, a.serial_number,
         a.functional_status, a.status, a.updated_at
  from public.assets a
  where a.code = trim(p_code)
    and a.qr_enabled = true
    and a.active = true;
$$;

revoke all on function public.public_asset_qr(text) from public;
grant execute on function public.public_asset_qr(text) to anon, authenticated;

grant execute on function public.create_cargo_with_items(uuid,jsonb,timestamptz,text) to authenticated;

-- Storage bucket recommendation:
-- create a PRIVATE bucket named 'evidencias' in Supabase Storage.
-- Do not expose signed URLs from the database as public URLs.

comment on table public.assets is 'Activos patrimoniales con QR permanente y estado actual.';
comment on table public.asset_movements is 'Historial inmutable de movimientos del activo.';
comment on table public.audit_log is 'Auditoria de operaciones administrativas.';

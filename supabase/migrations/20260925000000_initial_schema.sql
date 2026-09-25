-- HisabSaathi production schema.
-- Apply with Supabase migrations. The mobile client must never write directly
-- to ledger or inventory history; those writes belong in authorized RPCs or
-- Edge Functions added in later phases.

create extension if not exists pgcrypto;

create type public.member_role as enum ('owner', 'manager', 'staff');
create type public.membership_status as enum ('active', 'invited', 'suspended');
create type public.invoice_status as enum ('draft', 'issued', 'paid', 'credit', 'void');
create type public.payment_method as enum ('cash', 'upi', 'bank', 'other');
create type public.payment_status as enum ('pending', 'received', 'reversed', 'failed');
create type public.ledger_entry_type as enum (
  'opening_balance',
  'invoice_credit',
  'payment_received',
  'adjustment',
  'refund',
  'reversal',
  'advance_payment'
);
create type public.inventory_movement_type as enum (
  'purchase',
  'sale',
  'sale_reversal',
  'adjustment',
  'damage',
  'return'
);
create type public.sync_status as enum (
  'local_pending',
  'syncing',
  'synced',
  'failed',
  'conflict'
);
create type public.claim_status as enum (
  'created',
  'pending_verification',
  'approved',
  'rejected',
  'expired',
  'cancelled'
);
create type public.subscription_status as enum ('trial', 'active', 'expired', 'pending_verification', 'suspended');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.generate_profile_id()
returns text
language sql
volatile
as $$
  select 'HS-' || upper(encode(gen_random_bytes(4), 'hex'));
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  phone text,
  default_language text not null default 'hi'
    check (default_language in (
      'hi', 'en', 'bn', 'mr', 'te', 'ta', 'gu', 'kn', 'ml', 'pa', 'or',
      'as', 'ur', 'ks', 'kok', 'mai', 'ne', 'sa', 'sd', 'doi', 'mni',
      'brx', 'sat'
    )),
  disabled_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.shops (
  id uuid primary key default gen_random_uuid(),
  profile_id text not null unique default public.generate_profile_id()
    check (profile_id ~ '^HS-[A-F0-9]{8}$'),
  name text not null check (length(btrim(name)) between 1 and 160),
  address text not null default '',
  phone text not null default '',
  category text not null default '',
  owner_profile_id uuid not null references public.profiles(id) on delete restrict,
  language text not null default 'hi'
    check (language in (
      'hi', 'en', 'bn', 'mr', 'te', 'ta', 'gu', 'kn', 'ml', 'pa', 'or',
      'as', 'ur', 'ks', 'kok', 'mai', 'ne', 'sa', 'sd', 'doi', 'mni',
      'brx', 'sat'
    )),
  subscription_status public.subscription_status not null default 'trial',
  subscription_expires_at timestamptz,
  trial_started_at timestamptz not null default timezone('utc', now()),
  disabled_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.shop_memberships (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role public.member_role not null default 'staff',
  status public.membership_status not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (shop_id, profile_id)
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 160),
  phone text not null check (length(btrim(phone)) between 3 and 32),
  address text not null default '',
  due_date date,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null check (length(btrim(name)) between 1 and 160),
  sku text not null default '',
  price_minor bigint not null check (price_minor >= 0),
  unit text not null default 'piece',
  low_stock_threshold numeric(12, 3) not null default 5 check (low_stock_threshold >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (shop_id, sku)
);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  customer_id uuid references public.customers(id) on delete restrict,
  invoice_no text not null,
  subtotal_minor bigint not null check (subtotal_minor >= 0),
  paid_minor bigint not null default 0 check (paid_minor >= 0),
  credit_minor bigint not null default 0 check (credit_minor >= 0),
  status public.invoice_status not null default 'issued',
  client_operation_id uuid,
  issued_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  unique (shop_id, invoice_no),
  unique (shop_id, client_operation_id),
  check (paid_minor + credit_minor = subtotal_minor)
);

create table public.invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  product_id uuid references public.products(id) on delete restrict,
  item_name text not null check (length(btrim(item_name)) between 1 and 160),
  quantity numeric(12, 3) not null check (quantity > 0),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  amount_minor bigint not null check (amount_minor >= 0),
  created_at timestamptz not null default timezone('utc', now())
);

create table public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  customer_id uuid references public.customers(id) on delete restrict,
  invoice_id uuid references public.invoices(id) on delete restrict,
  payment_id uuid,
  entry_type public.ledger_entry_type not null,
  amount_minor bigint not null check (amount_minor <> 0),
  reference text,
  metadata jsonb not null default '{}'::jsonb,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  client_operation_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  unique (shop_id, client_operation_id)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  customer_id uuid references public.customers(id) on delete restrict,
  invoice_id uuid references public.invoices(id) on delete restrict,
  amount_minor bigint not null check (amount_minor > 0),
  method public.payment_method not null,
  status public.payment_status not null default 'received',
  provider_reference text,
  client_operation_id uuid,
  received_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  unique (shop_id, client_operation_id)
);

alter table public.ledger_entries
  add constraint ledger_payment_fk
  foreign key (payment_id) references public.payments(id) on delete restrict;

create table public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  movement_type public.inventory_movement_type not null,
  quantity numeric(12, 3) not null check (quantity <> 0),
  reference text,
  metadata jsonb not null default '{}'::jsonb,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  client_operation_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  unique (shop_id, client_operation_id)
);

create table public.subscription_entitlements (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  plan_code text not null default 'premium_monthly',
  starts_at timestamptz not null,
  expires_at timestamptz not null,
  activated_by uuid references public.profiles(id) on delete set null,
  source_claim_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  check (expires_at > starts_at)
);

create table public.payment_claims (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null default 'INR' check (currency = 'INR'),
  utr text not null check (length(btrim(utr)) between 6 and 80),
  receipt_path text not null,
  status public.claim_status not null default 'created',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  verified_at timestamptz,
  verified_by uuid references public.profiles(id) on delete set null,
  rejection_reason text,
  client_operation_id uuid,
  unique (utr),
  unique (shop_id, client_operation_id)
);

alter table public.subscription_entitlements
  add constraint entitlement_claim_fk
  foreign key (source_claim_id) references public.payment_claims(id) on delete set null;

create table public.reminder_jobs (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete cascade,
  channel text not null check (channel in ('whatsapp', 'sms', 'call')),
  scheduled_for timestamptz not null,
  status text not null default 'queued'
    check (status in ('queued', 'scheduled', 'processing', 'sent', 'failed', 'retrying', 'cancelled')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  idempotency_key uuid not null unique,
  provider_reference text,
  last_error text,
  sent_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.sync_operations (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete restrict,
  client_operation_id uuid not null,
  entity_id uuid,
  operation_type text not null
    check (operation_type in (
      'create_customer', 'create_invoice', 'create_payment',
      'create_product', 'create_inventory_movement', 'create_payment_claim'
    )),
  payload jsonb not null default '{}'::jsonb,
  request_hash text not null,
  status public.sync_status not null default 'local_pending',
  retry_count integer not null default 0 check (retry_count >= 0),
  error_code text,
  error_message text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  processed_at timestamptz,
  unique (shop_id, client_operation_id)
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references public.shops(id) on delete set null,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index idx_memberships_profile on public.shop_memberships(profile_id, status);
create index idx_customers_shop_name on public.customers(shop_id, name);
create index idx_products_shop_name on public.products(shop_id, name);
create index idx_invoices_shop_issued on public.invoices(shop_id, issued_at desc);
create index idx_ledger_shop_customer on public.ledger_entries(shop_id, customer_id, created_at desc);
create index idx_payments_shop_received on public.payments(shop_id, received_at desc);
create index idx_inventory_shop_product on public.inventory_movements(shop_id, product_id, created_at desc);
create index idx_claims_shop_status on public.payment_claims(shop_id, status, created_at desc);
create index idx_reminders_due on public.reminder_jobs(status, scheduled_for);
create index idx_sync_pending on public.sync_operations(shop_id, status, created_at);
create index idx_audit_shop_created on public.audit_logs(shop_id, created_at desc);

create trigger profiles_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger shops_updated_at before update on public.shops
for each row execute function public.set_updated_at();
create trigger memberships_updated_at before update on public.shop_memberships
for each row execute function public.set_updated_at();
create trigger customers_updated_at before update on public.customers
for each row execute function public.set_updated_at();
create trigger products_updated_at before update on public.products
for each row execute function public.set_updated_at();
create trigger claims_updated_at before update on public.payment_claims
for each row execute function public.set_updated_at();
create trigger reminders_updated_at before update on public.reminder_jobs
for each row execute function public.set_updated_at();
create trigger sync_operations_updated_at before update on public.sync_operations
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, phone)
  values (
    new.id,
    nullif(new.raw_user_meta_data ->> 'display_name', ''),
    nullif(new.phone, '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.is_shop_member(target_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.shop_memberships membership
    where membership.shop_id = target_shop_id
      and membership.profile_id = auth.uid()
      and membership.status = 'active'
  );
$$;

create or replace function public.is_shop_admin(target_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.shop_memberships membership
    where membership.shop_id = target_shop_id
      and membership.profile_id = auth.uid()
      and membership.status = 'active'
      and membership.role in ('owner', 'manager')
  );
$$;

create or replace function public.create_shop(
  shop_name text,
  shop_address text default '',
  shop_phone text default '',
  shop_category text default '',
  shop_language text default 'hi'
)
returns public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  created_shop public.shops;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  if length(btrim(coalesce(shop_name, ''))) not between 1 and 160 then
    raise exception 'INVALID_SHOP_NAME' using errcode = '22023';
  end if;

  insert into public.shops (name, address, phone, category, owner_profile_id, language)
  values (btrim(shop_name), coalesce(shop_address, ''), coalesce(shop_phone, ''),
          coalesce(shop_category, ''), auth.uid(), coalesce(shop_language, 'hi'))
  returning * into created_shop;

  insert into public.shop_memberships (shop_id, profile_id, role, status)
  values (created_shop.id, auth.uid(), 'owner', 'active');

  return created_shop;
end;
$$;

create or replace function public.accept_sync_operation(
  operation_id uuid,
  target_entity_id uuid,
  target_operation_type text,
  target_payload jsonb,
  target_request_hash text
)
returns public.sync_operations
language plpgsql
security invoker
set search_path = public
as $$
declare
  existing public.sync_operations;
  target_shop uuid;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  target_shop := (target_payload ->> 'shop_id')::uuid;
  if target_shop is null or not public.is_shop_member(target_shop) then
    raise exception 'SHOP_ACCESS_DENIED' using errcode = '42501';
  end if;

  select *
    into existing
    from public.sync_operations
   where shop_id = target_shop
     and client_operation_id = operation_id;

  if existing.id is not null then
    if existing.request_hash <> target_request_hash
       or existing.operation_type <> target_operation_type then
      update public.sync_operations
         set status = 'conflict',
             error_code = 'IDEMPOTENCY_KEY_REUSED',
             error_message = 'The same client operation id was reused with different data.'
       where id = existing.id
       returning * into existing;
    end if;
    return existing;
  end if;

  insert into public.sync_operations (
    shop_id, profile_id, client_operation_id, entity_id,
    operation_type, payload, request_hash, status
  )
  values (
    target_shop, auth.uid(), operation_id, target_entity_id,
    target_operation_type, target_payload, target_request_hash, 'local_pending'
  )
  returning * into existing;

  return existing;
end;
$$;

-- Ledger history and inventory history are read-only to clients. Authorized
-- financial functions will be the only write path in the billing phases.
alter table public.profiles enable row level security;
alter table public.shops enable row level security;
alter table public.shop_memberships enable row level security;
alter table public.customers enable row level security;
alter table public.products enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.payments enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.subscription_entitlements enable row level security;
alter table public.payment_claims enable row level security;
alter table public.reminder_jobs enable row level security;
alter table public.sync_operations enable row level security;
alter table public.audit_logs enable row level security;

create policy profiles_self_select on public.profiles for select to authenticated
using (id = auth.uid());
create policy profiles_self_update on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

create policy shops_member_select on public.shops for select to authenticated
using (public.is_shop_member(id));
create policy shops_owner_insert on public.shops for insert to authenticated
with check (owner_profile_id = auth.uid());
create policy shops_owner_update on public.shops for update to authenticated
using (owner_profile_id = auth.uid()) with check (owner_profile_id = auth.uid());

create policy memberships_self_select on public.shop_memberships for select to authenticated
using (profile_id = auth.uid() or public.is_shop_admin(shop_id));
create policy memberships_admin_insert on public.shop_memberships for insert to authenticated
with check (public.is_shop_admin(shop_id));
create policy memberships_admin_update on public.shop_memberships for update to authenticated
using (public.is_shop_admin(shop_id)) with check (public.is_shop_admin(shop_id));

create policy customers_member_select on public.customers for select to authenticated
using (public.is_shop_member(shop_id));
create policy customers_member_insert on public.customers for insert to authenticated
with check (public.is_shop_member(shop_id));
create policy customers_member_update on public.customers for update to authenticated
using (public.is_shop_member(shop_id)) with check (public.is_shop_member(shop_id));

create policy products_member_select on public.products for select to authenticated
using (public.is_shop_member(shop_id));
create policy products_member_insert on public.products for insert to authenticated
with check (public.is_shop_member(shop_id));
create policy products_member_update on public.products for update to authenticated
using (public.is_shop_member(shop_id)) with check (public.is_shop_member(shop_id));

create policy invoices_member_select on public.invoices for select to authenticated
using (public.is_shop_member(shop_id));
create policy invoice_items_member_select on public.invoice_items for select to authenticated
using (exists (
  select 1 from public.invoices invoice
  where invoice.id = invoice_id and public.is_shop_member(invoice.shop_id)
));

create policy ledger_member_select on public.ledger_entries for select to authenticated
using (public.is_shop_member(shop_id));
create policy payments_member_select on public.payments for select to authenticated
using (public.is_shop_member(shop_id));
create policy inventory_member_select on public.inventory_movements for select to authenticated
using (public.is_shop_member(shop_id));

create policy entitlements_member_select on public.subscription_entitlements for select to authenticated
using (public.is_shop_member(shop_id));
create policy claims_member_select on public.payment_claims for select to authenticated
using (public.is_shop_member(shop_id));
create policy claims_member_insert on public.payment_claims for insert to authenticated
with check (public.is_shop_member(shop_id));
create policy reminders_member_select on public.reminder_jobs for select to authenticated
using (public.is_shop_member(shop_id));
create policy reminders_member_insert on public.reminder_jobs for insert to authenticated
with check (public.is_shop_member(shop_id));
create policy reminders_member_update on public.reminder_jobs for update to authenticated
using (public.is_shop_member(shop_id)) with check (public.is_shop_member(shop_id));

create policy sync_member_select on public.sync_operations for select to authenticated
using (public.is_shop_member(shop_id));
create policy audit_member_select on public.audit_logs for select to authenticated
using (shop_id is null or public.is_shop_member(shop_id));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payment-proofs',
  'payment-proofs',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy payment_proofs_member_read on storage.objects
for select to authenticated
using (
  bucket_id = 'payment-proofs'
  and public.is_shop_member((storage.foldername(name))[1]::uuid)
);

create policy payment_proofs_member_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'payment-proofs'
  and public.is_shop_member((storage.foldername(name))[1]::uuid)
);

revoke all on function public.accept_sync_operation(uuid, uuid, text, jsonb, text) from public;
grant execute on function public.accept_sync_operation(uuid, uuid, text, jsonb, text) to authenticated;
revoke all on function public.create_shop(text, text, text, text, text) from public;
grant execute on function public.create_shop(text, text, text, text, text) to authenticated;
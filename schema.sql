-- SHOES STORE POS & INVENTORY v2 - Supabase/PostgreSQL
-- Jalankan di Supabase SQL Editor pada project baru.
create extension if not exists pgcrypto;

-- ===================== MASTER =====================
create table if not exists public.profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default 'User', role text not null check(role in('kasir','admin','owner')) default 'kasir',
  phone text, active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.settings(
  id int primary key default 1 check(id=1), store_name text not null default 'Shoes Store', address text, phone text,
  receipt_footer text default 'Terima kasih telah berbelanja.', default_min_stock int default 3,
  cashier_max_discount numeric(14,2) default 50000, cost_method text default 'average', updated_at timestamptz default now()
);
insert into public.settings(id) values(1) on conflict do nothing;
create table if not exists public.categories(id uuid primary key default gen_random_uuid(),name text unique not null,active boolean default true);
create table if not exists public.brands(id uuid primary key default gen_random_uuid(),name text unique not null,active boolean default true);
create table if not exists public.suppliers(
  id uuid primary key default gen_random_uuid(),name text not null,phone text,whatsapp text,email text,address text,contact_person text,notes text,active boolean default true,created_at timestamptz default now()
);
create table if not exists public.customers(
  id uuid primary key default gen_random_uuid(),name text not null,phone text,whatsapp text,email text,address text,birth_date date,points int default 0,notes text,created_at timestamptz default now()
);
create table if not exists public.products(
  id uuid primary key default gen_random_uuid(),sku text unique not null,name text not null,brand_id uuid references public.brands(id),category_id uuid references public.categories(id),
  gender text default 'Unisex',description text,cost_price numeric(14,2) not null default 0,sale_price numeric(14,2) not null default 0,wholesale_price numeric(14,2) default 0,
  active boolean not null default true,created_at timestamptz not null default now(),updated_at timestamptz default now()
);
create table if not exists public.product_variants(
  id uuid primary key default gen_random_uuid(),product_id uuid not null references public.products(id) on delete cascade,size text not null,color text not null,barcode text unique,
  stock_qty int not null default 0,min_stock int not null default 3,active boolean default true,unique(product_id,size,color)
);

-- ===================== SALES / POS =====================
create table if not exists public.shifts(
  id uuid primary key default gen_random_uuid(),cashier_id uuid not null references public.profiles(id),opened_at timestamptz default now(),opening_cash numeric(14,2) default 0,
  closed_at timestamptz,actual_cash numeric(14,2),expected_cash numeric(14,2),difference numeric(14,2),status text default 'open' check(status in('open','closed')),notes text
);
create table if not exists public.sales(
  id uuid primary key default gen_random_uuid(),invoice_no text unique not null default('INV-'||to_char(clock_timestamp(),'YYYYMMDD-HH24MISSMS')),
  cashier_id uuid not null references public.profiles(id),shift_id uuid references public.shifts(id),customer_id uuid references public.customers(id),
  gross_total numeric(14,2) not null default 0,discount_total numeric(14,2) not null default 0,net_total numeric(14,2) not null default 0,cogs_total numeric(14,2) not null default 0,
  payment_method text not null default 'Tunai',paid_amount numeric(14,2) default 0,change_amount numeric(14,2) default 0,item_count int default 0,
  status text not null default 'completed' check(status in('completed','void','returned','partial_return')),void_reason text,voided_by uuid references public.profiles(id),created_at timestamptz not null default now()
);
create table if not exists public.sale_items(
  id uuid primary key default gen_random_uuid(),sale_id uuid not null references public.sales(id) on delete cascade,variant_id uuid not null references public.product_variants(id),
  qty int not null check(qty>0),unit_price numeric(14,2) not null,unit_cost numeric(14,2) not null,discount numeric(14,2) default 0,subtotal numeric(14,2) not null
);

-- ===================== PURCHASE =====================
create table if not exists public.purchases(
  id uuid primary key default gen_random_uuid(),purchase_no text unique not null default('PO-'||to_char(clock_timestamp(),'YYYYMMDD-HH24MISSMS')),
  supplier_id uuid references public.suppliers(id),purchase_date date default current_date,subtotal numeric(14,2) default 0,discount numeric(14,2) default 0,shipping numeric(14,2) default 0,total numeric(14,2) default 0,
  notes text,status text default 'received' check(status in('draft','received','cancelled')),created_by uuid references public.profiles(id),created_at timestamptz default now()
);
create table if not exists public.purchase_items(
  id uuid primary key default gen_random_uuid(),purchase_id uuid not null references public.purchases(id) on delete cascade,variant_id uuid not null references public.product_variants(id),qty int not null check(qty>0),unit_cost numeric(14,2) not null,subtotal numeric(14,2) not null
);

-- ===================== STOCK =====================
create table if not exists public.stock_movements(
  id uuid primary key default gen_random_uuid(),variant_id uuid not null references public.product_variants(id),movement_type text not null,qty_change int not null,
  balance_after int,reference_id uuid,notes text,created_by uuid references public.profiles(id),created_at timestamptz not null default now()
);
create table if not exists public.stock_opnames(
  id uuid primary key default gen_random_uuid(),opname_no text unique not null default('SO-'||to_char(clock_timestamp(),'YYYYMMDD-HH24MISSMS')),
  opname_date date default current_date,notes text,created_by uuid references public.profiles(id),created_at timestamptz default now()
);
create table if not exists public.stock_opname_items(
  id uuid primary key default gen_random_uuid(),opname_id uuid not null references public.stock_opnames(id) on delete cascade,variant_id uuid not null references public.product_variants(id),
  system_qty int not null,physical_qty int not null,difference int not null,reason text
);

-- ===================== RETURNS =====================
create table if not exists public.sale_returns(
  id uuid primary key default gen_random_uuid(),return_no text unique not null default('RET-'||to_char(clock_timestamp(),'YYYYMMDD-HH24MISSMS')),
  sale_id uuid not null references public.sales(id),return_date date default current_date,return_type text default 'refund',refund_amount numeric(14,2) default 0,reason text,created_by uuid references public.profiles(id),created_at timestamptz default now()
);
create table if not exists public.sale_return_items(
  id uuid primary key default gen_random_uuid(),return_id uuid not null references public.sale_returns(id) on delete cascade,sale_item_id uuid not null references public.sale_items(id),variant_id uuid not null references public.product_variants(id),qty int not null check(qty>0),amount numeric(14,2) default 0,condition text default 'baik',restock boolean default true
);
create table if not exists public.purchase_returns(
  id uuid primary key default gen_random_uuid(),return_no text unique not null default('RTS-'||to_char(clock_timestamp(),'YYYYMMDD-HH24MISSMS')),
  purchase_id uuid not null references public.purchases(id),return_date date default current_date,reason text,created_by uuid references public.profiles(id),created_at timestamptz default now()
);
create table if not exists public.purchase_return_items(
  id uuid primary key default gen_random_uuid(),return_id uuid not null references public.purchase_returns(id) on delete cascade,variant_id uuid not null references public.product_variants(id),qty int not null check(qty>0),unit_cost numeric(14,2) default 0
);

-- ===================== FINANCE / AUDIT =====================
create table if not exists public.expense_categories(id uuid primary key default gen_random_uuid(),name text unique not null,active boolean default true);
create table if not exists public.expenses(
  id uuid primary key default gen_random_uuid(),expense_date date not null default current_date,category text not null,description text,amount numeric(14,2) not null check(amount>0),payment_method text default 'Tunai',created_by uuid not null references public.profiles(id),created_at timestamptz default now()
);
create table if not exists public.audit_logs(
  id bigint generated always as identity primary key,user_id uuid references public.profiles(id),action text not null,entity text,entity_id text,details jsonb default '{}'::jsonb,created_at timestamptz default now()
);

-- ===================== FUNCTIONS / TRIGGERS =====================
create or replace function public.current_role() returns text language sql stable security definer set search_path=public as $$ select role from public.profiles where id=auth.uid() and active=true $$;
create or replace function public.write_audit(p_action text,p_entity text,p_entity_id text,p_details jsonb default '{}'::jsonb) returns void language plpgsql security definer set search_path=public as $$ begin insert into public.audit_logs(user_id,action,entity,entity_id,details) values(auth.uid(),p_action,p_entity,p_entity_id,p_details); end $$;

create or replace function public.handle_sale_item_stock() returns trigger language plpgsql security definer set search_path=public as $$
declare current_stock int; new_balance int;
begin
  select stock_qty into current_stock from public.product_variants where id=new.variant_id for update;
  if current_stock < new.qty then raise exception 'Stok tidak cukup'; end if;
  new_balance:=current_stock-new.qty;
  update public.product_variants set stock_qty=new_balance where id=new.variant_id;
  insert into public.stock_movements(variant_id,movement_type,qty_change,balance_after,reference_id,created_by) select new.variant_id,'sale',-new.qty,new_balance,new.sale_id,s.cashier_id from public.sales s where s.id=new.sale_id;
  return new;
end $$;
drop trigger if exists trg_sale_item_stock on public.sale_items; create trigger trg_sale_item_stock after insert on public.sale_items for each row execute function public.handle_sale_item_stock();

create or replace function public.handle_purchase_item_stock() returns trigger language plpgsql security definer set search_path=public as $$
declare old_stock int; old_cost numeric; new_cost numeric; new_balance int; creator uuid;
begin
  select v.stock_qty,p.cost_price into old_stock,old_cost from public.product_variants v join public.products p on p.id=v.product_id where v.id=new.variant_id for update;
  new_balance:=old_stock+new.qty;
  if new_balance>0 then new_cost:=((old_stock*old_cost)+(new.qty*new.unit_cost))/new_balance; else new_cost:=new.unit_cost; end if;
  update public.product_variants set stock_qty=new_balance where id=new.variant_id;
  update public.products set cost_price=new_cost,updated_at=now() where id=(select product_id from public.product_variants where id=new.variant_id);
  select created_by into creator from public.purchases where id=new.purchase_id;
  insert into public.stock_movements(variant_id,movement_type,qty_change,balance_after,reference_id,created_by) values(new.variant_id,'purchase',new.qty,new_balance,new.purchase_id,creator);
  return new;
end $$;
drop trigger if exists trg_purchase_item_stock on public.purchase_items; create trigger trg_purchase_item_stock after insert on public.purchase_items for each row execute function public.handle_purchase_item_stock();

create or replace function public.apply_stock_opname_item() returns trigger language plpgsql security definer set search_path=public as $$
declare creator uuid;
begin
  update public.product_variants set stock_qty=new.physical_qty where id=new.variant_id;
  select created_by into creator from public.stock_opnames where id=new.opname_id;
  insert into public.stock_movements(variant_id,movement_type,qty_change,balance_after,reference_id,notes,created_by) values(new.variant_id,'opname',new.difference,new.physical_qty,new.opname_id,new.reason,creator);
  return new;
end $$;
drop trigger if exists trg_opname_item on public.stock_opname_items; create trigger trg_opname_item after insert on public.stock_opname_items for each row execute function public.apply_stock_opname_item();

create or replace function public.handle_sale_return_stock() returns trigger language plpgsql security definer set search_path=public as $$
declare bal int; creator uuid;
begin
  if new.restock then update public.product_variants set stock_qty=stock_qty+new.qty where id=new.variant_id returning stock_qty into bal;
    select created_by into creator from public.sale_returns where id=new.return_id;
    insert into public.stock_movements(variant_id,movement_type,qty_change,balance_after,reference_id,created_by) values(new.variant_id,'sale_return',new.qty,bal,new.return_id,creator);
  end if; return new;
end $$;
drop trigger if exists trg_sale_return_stock on public.sale_return_items; create trigger trg_sale_return_stock after insert on public.sale_return_items for each row execute function public.handle_sale_return_stock();

create or replace function public.handle_purchase_return_stock() returns trigger language plpgsql security definer set search_path=public as $$
declare current_stock int; bal int; creator uuid;
begin
  select stock_qty into current_stock from public.product_variants where id=new.variant_id for update;
  if current_stock<new.qty then raise exception 'Stok tidak cukup untuk retur supplier'; end if; bal:=current_stock-new.qty;
  update public.product_variants set stock_qty=bal where id=new.variant_id;
  select created_by into creator from public.purchase_returns where id=new.return_id;
  insert into public.stock_movements(variant_id,movement_type,qty_change,balance_after,reference_id,created_by) values(new.variant_id,'purchase_return',-new.qty,bal,new.return_id,creator);
  return new;
end $$;
drop trigger if exists trg_purchase_return_stock on public.purchase_return_items; create trigger trg_purchase_return_stock after insert on public.purchase_return_items for each row execute function public.handle_purchase_return_stock();

-- ===================== RLS =====================
do $$ declare t text; begin foreach t in array array['profiles','settings','categories','brands','suppliers','customers','products','product_variants','shifts','sales','sale_items','purchases','purchase_items','stock_movements','stock_opnames','stock_opname_items','sale_returns','sale_return_items','purchase_returns','purchase_return_items','expense_categories','expenses','audit_logs'] loop execute format('alter table public.%I enable row level security',t); end loop; end $$;

-- Read master for logged-in users
create policy "read settings" on public.settings for select to authenticated using(true);
create policy "owner settings" on public.settings for all to authenticated using(public.current_role()='owner') with check(public.current_role()='owner');
create policy "read own profile or privileged" on public.profiles for select to authenticated using(id=auth.uid() or public.current_role() in('admin','owner'));
create policy "owner profiles" on public.profiles for all to authenticated using(public.current_role()='owner') with check(public.current_role()='owner');
create policy "read categories" on public.categories for select to authenticated using(true); create policy "manage categories" on public.categories for all to authenticated using(public.current_role() in('admin','owner')) with check(public.current_role() in('admin','owner'));
create policy "read brands" on public.brands for select to authenticated using(true); create policy "manage brands" on public.brands for all to authenticated using(public.current_role() in('admin','owner')) with check(public.current_role() in('admin','owner'));
create policy "read products" on public.products for select to authenticated using(true); create policy "manage products" on public.products for all to authenticated using(public.current_role() in('admin','owner')) with check(public.current_role() in('admin','owner'));
create policy "read variants" on public.product_variants for select to authenticated using(true); create policy "manage variants" on public.product_variants for all to authenticated using(public.current_role() in('admin','owner')) with check(public.current_role() in('admin','owner'));
create policy "priv suppliers" on public.suppliers for all to authenticated using(public.current_role() in('admin','owner')) with check(public.current_role() in('admin','owner'));
create policy "customers read" on public.customers for select to authenticated using(true); create policy "customers manage" on public.customers for all to authenticated using(public.current_role() in('kasir','admin','owner')) with check(public.current_role() in('kasir','admin','owner'));

-- Operational policies
create policy "sales read" on public.sales for select to authenticated using(cashier_id=auth.uid() or public.current_role() in('admin','owner'));
create policy "sales insert own" on public.sales for insert to authenticated with check(cashier_id=auth.uid());
create policy "sales update priv" on public.sales for update to authenticated using(public.current_role() in('admin','owner'));
create policy "sale items read" on public.sale_items for select to authenticated using(exists(select 1 from public.sales s where s.id=sale_id and(s.cashier_id=auth.uid() or public.current_role() in('admin','owner'))));
create policy "sale items insert" on public.sale_items for insert to authenticated with check(exists(select 1 from public.sales s where s.id=sale_id and s.cashier_id=auth.uid()));
create policy "shifts read" on public.shifts for select to authenticated using(cashier_id=auth.uid() or public.current_role() in('admin','owner')); create policy "shifts insert own" on public.shifts for insert to authenticated with check(cashier_id=auth.uid()); create policy "shifts update" on public.shifts for update to authenticated using(cashier_id=auth.uid() or public.current_role() in('admin','owner'));

create policy "purchases priv" on public.purchases for all to authenticated using(public.current_role() in('admin','owner')) with check(public.current_role() in('admin','owner'));
create policy "purchase items priv" on public.purchase_items for all to authenticated using(public.current_role() in('admin','owner')) with check(public.current_role() in('admin','owner'));
create policy "stock movements read" on public.stock_movements for select to authenticated using(public.current_role() in('admin','owner'));
create policy "opname priv" on public.stock_opnames for all to authenticated using(public.current_role() in('admin','owner')) with check(public.current_role() in('admin','owner'));
create policy "opname items priv" on public.stock_opname_items for all to authenticated using(public.current_role() in('admin','owner')) with check(public.current_role() in('admin','owner'));
create policy "sale returns priv" on public.sale_returns for all to authenticated using(public.current_role() in('admin','owner')) with check(public.current_role() in('admin','owner'));
create policy "sale return items priv" on public.sale_return_items for all to authenticated using(public.current_role() in('admin','owner')) with check(public.current_role() in('admin','owner'));
create policy "purchase returns priv" on public.purchase_returns for all to authenticated using(public.current_role() in('admin','owner')) with check(public.current_role() in('admin','owner'));
create policy "purchase return items priv" on public.purchase_return_items for all to authenticated using(public.current_role() in('admin','owner')) with check(public.current_role() in('admin','owner'));
create policy "expense categories priv" on public.expense_categories for all to authenticated using(public.current_role() in('admin','owner')) with check(public.current_role() in('admin','owner'));
create policy "expenses read" on public.expenses for select to authenticated using(public.current_role() in('admin','owner')); create policy "expenses insert" on public.expenses for insert to authenticated with check(public.current_role() in('admin','owner') and created_by=auth.uid()); create policy "expenses owner update" on public.expenses for update to authenticated using(public.current_role()='owner');
create policy "audit read owner" on public.audit_logs for select to authenticated using(public.current_role()='owner'); create policy "audit insert self" on public.audit_logs for insert to authenticated with check(user_id=auth.uid());

-- ===================== REALTIME =====================
do $$ begin
  begin alter publication supabase_realtime add table public.sales; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.product_variants; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.expenses; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.purchases; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.shifts; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.sale_returns; exception when duplicate_object then null; end;
end $$;

-- ===================== SAMPLE DATA =====================
insert into public.categories(name) values('Sneakers'),('Running'),('Casual'),('Formal'),('Sepatu Sekolah') on conflict do nothing;
insert into public.brands(name) values('Nike'),('Adidas'),('Puma'),('Converse'),('New Balance') on conflict do nothing;
insert into public.expense_categories(name) values('Listrik'),('Internet'),('Gaji'),('Sewa'),('Promosi'),('Lain-lain') on conflict do nothing;
insert into public.suppliers(name,phone,whatsapp,address) values('Supplier Sepatu Utama','081200000001','081200000001','Surabaya'),('Distributor Sport','081200000002','081200000002','Jakarta') on conflict do nothing;
insert into public.products(sku,name,brand_id,category_id,cost_price,sale_price)
select x.sku,x.name,b.id,c.id,x.cost,x.sale from (values
('NK-AIR-001','Nike Air Runner','Nike','Running',450000::numeric,699000::numeric),('AD-SM-002','Adidas Street Move','Adidas','Sneakers',390000,599000),('PM-CS-003','Puma Casual Flex','Puma','Casual',320000,499000),('CV-CL-004','Converse Classic','Converse','Sneakers',300000,479000),('NB-RN-005','New Balance Daily Run','New Balance','Running',520000,799000)
) x(sku,name,brand,category,cost,sale) join public.brands b on b.name=x.brand join public.categories c on c.name=x.category on conflict(sku) do nothing;
insert into public.product_variants(product_id,size,color,barcode,stock_qty,min_stock)
select p.id,v.size,v.color,v.barcode,v.stock,3 from public.products p join(values
('NK-AIR-001','39','Hitam','8990001001391',5),('NK-AIR-001','40','Hitam','8990001001407',6),('NK-AIR-001','41','Putih','8990001001414',4),('AD-SM-002','40','Putih','8990002002403',5),('AD-SM-002','41','Hitam','8990002002410',3),('PM-CS-003','42','Navy','8990003003421',7),('CV-CL-004','39','Hitam','8990004004397',4),('CV-CL-004','40','Putih','8990004004403',5),('NB-RN-005','42','Abu-abu','8990005005423',2)
)v(sku,size,color,barcode,stock) on p.sku=v.sku on conflict(product_id,size,color) do nothing;

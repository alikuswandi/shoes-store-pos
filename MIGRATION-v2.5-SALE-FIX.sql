
-- ============================================================
-- v2.5 FIX: ATOMIC POS SALE TRANSACTION
-- Jalankan blok ini di Supabase SQL Editor setelah schema.sql.
-- ============================================================
create or replace function public.create_sale_transaction(
  p_shift_id uuid default null,
  p_customer_id uuid default null,
  p_discount_total numeric default 0,
  p_payment_method text default 'Tunai',
  p_paid_amount numeric default 0,
  p_items jsonb default '[]'::jsonb
)
returns public.sales
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cashier uuid := auth.uid();
  v_sale public.sales;
  v_item jsonb;
  v_variant uuid;
  v_qty int;
  v_price numeric;
  v_cost numeric;
  v_stock int;
  v_gross numeric := 0;
  v_cogs numeric := 0;
  v_discount numeric := greatest(coalesce(p_discount_total,0),0);
  v_net numeric;
  v_paid numeric;
  v_change numeric;
  v_count int := 0;
begin
  if v_cashier is null then
    raise exception 'Sesi login tidak valid.';
  end if;

  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Keranjang penjualan kosong.';
  end if;

  if p_payment_method not in ('Tunai','QRIS','Transfer','Debit','Kredit','E-Wallet') then
    raise exception 'Metode pembayaran tidak valid.';
  end if;

  if p_shift_id is not null and not exists (
    select 1 from public.shifts
    where id=p_shift_id and cashier_id=v_cashier and status='open'
  ) then
    raise exception 'Shift kasir tidak ditemukan atau sudah ditutup.';
  end if;

  -- Hitung ulang harga dan HPP dari database, bukan mempercayai browser.
  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_variant := (v_item->>'variant_id')::uuid;
    v_qty := (v_item->>'qty')::int;

    if v_variant is null or coalesce(v_qty,0) <= 0 then
      raise exception 'Item penjualan tidak valid.';
    end if;

    select pv.stock_qty, p.sale_price, p.cost_price
      into v_stock, v_price, v_cost
    from public.product_variants pv
    join public.products p on p.id=pv.product_id
    where pv.id=v_variant and pv.active=true
    for update;

    if not found then
      raise exception 'Varian produk tidak ditemukan.';
    end if;

    if v_stock < v_qty then
      raise exception 'Stok tidak cukup untuk salah satu produk.';
    end if;

    v_gross := v_gross + (v_qty * v_price);
    v_cogs := v_cogs + (v_qty * v_cost);
    v_count := v_count + v_qty;
  end loop;

  v_discount := least(v_discount, v_gross);
  v_net := v_gross - v_discount;
  v_paid := case when p_payment_method='Tunai' then coalesce(p_paid_amount,0) else v_net end;

  if v_paid < v_net then
    raise exception 'Uang dibayar kurang.';
  end if;

  v_change := greatest(0, v_paid-v_net);

  insert into public.sales(
    cashier_id, shift_id, customer_id,
    gross_total, discount_total, net_total, cogs_total,
    payment_method, paid_amount, change_amount, item_count, status
  )
  values(
    v_cashier, p_shift_id, p_customer_id,
    v_gross, v_discount, v_net, v_cogs,
    p_payment_method, v_paid, v_change, v_count, 'completed'
  )
  returning * into v_sale;

  -- Trigger trg_sale_item_stock akan mengurangi stok.
  -- Jika satu item gagal, seluruh function rollback: tidak ada
  -- transaksi "setengah tersimpan" dan tidak ada transaksi void palsu.
  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_variant := (v_item->>'variant_id')::uuid;
    v_qty := (v_item->>'qty')::int;

    select p.sale_price, p.cost_price
      into v_price, v_cost
    from public.product_variants pv
    join public.products p on p.id=pv.product_id
    where pv.id=v_variant;

    insert into public.sale_items(
      sale_id, variant_id, qty, unit_price, unit_cost, subtotal
    )
    values(
      v_sale.id, v_variant, v_qty, v_price, v_cost, v_qty*v_price
    );
  end loop;

  return v_sale;
end;
$$;

revoke all on function public.create_sale_transaction(uuid,uuid,numeric,text,numeric,jsonb) from public;
grant execute on function public.create_sale_transaction(uuid,uuid,numeric,text,numeric,jsonb) to authenticated;

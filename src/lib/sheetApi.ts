import {
  SheetPayload,
  SheetHeader,
  PastryLine,
  YoghurtHeader,
  YoghurtContainerLine,
  YoghurtRefillLine,
  YoghurtNonContainer,
  YoghurtSectionBIncome,
  MaterialLine,
  CurrencyNote,
  StaffEntry,
  ExtraExpense,
} from "./types";
import { SupabaseClient } from "@supabase/supabase-js";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Client = SupabaseClient<any, "public", any>;

/**
 * Fetch the full sheet payload by querying each table directly.
 * Frontend will compute all derived values.
 */
export async function fetchSheet(
  client: Client,
  sheetId: string
): Promise<SheetPayload> {
  // Fetch sheet header with branch name
  const { data: sheetData, error: sheetError } = await client
    .from("daily_sheets")
    .select("*, branches(name)")
    .eq("id", sheetId)
    .single();

  if (sheetError || !sheetData) {
    throw new Error(sheetError?.message || "Sheet not found");
  }

  // Fetch all related data in parallel
  const [
    pastriesRes,
    yoghurtHeaderRes,
    yoghurtContainersRes,
    yoghurtRefillsRes,
    yoghurtNonContainerRes,
    yoghurtSectionBRes,
    materialsRes,
    currencyNotesRes,
    staffRes,
    expensesRes,
  ] = await Promise.all([
    client
      .from("pastry_lines")
      .select("*, received_from_branch:branches!pastry_lines_received_from_branch_id_fkey(name), transfer_to_branch:branches!pastry_lines_transfer_to_branch_id_fkey(name)")
      .eq("sheet_id", sheetId),
    client.from("yoghurt_headers").select("*").eq("sheet_id", sheetId).single(),
    client.from("yoghurt_container_lines").select("*").eq("sheet_id", sheetId),
    client.from("yoghurt_refill_lines").select("*").eq("sheet_id", sheetId),
    client.from("yoghurt_non_container").select("*").eq("sheet_id", sheetId).maybeSingle(),
    client.from("yoghurt_section_b_income").select("*").eq("sheet_id", sheetId),
    client
      .from("material_lines")
      .select("*, transfer_to_branch:branches!material_lines_transfer_to_branch_id_fkey(name)")
      .eq("sheet_id", sheetId),
    client.from("currency_notes").select("*").eq("sheet_id", sheetId),
    client.from("staff_attendance").select("*").eq("sheet_id", sheetId),
    client.from("extra_expenses").select("*").eq("sheet_id", sheetId),
  ]);

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const sd = sheetData as any;
  const header: SheetHeader = {
    id: sd.id,
    branch_id: sd.branch_id,
    branch_name: sd.branches?.name || "",
    sheet_date: sd.sheet_date,
    supervisor_name: null,
    locked: sd.locked,
    total_pastries_income: sd.total_pastries_income || 0,
    yoghurt_section_a_total_volume: sd.yoghurt_section_a_total_volume || 0,
    yoghurt_section_a_total_income: sd.yoghurt_section_a_total_income || 0,
    yoghurt_section_b_total: sd.yoghurt_section_b_total || 0,
    grand_total: sd.grand_total || 0,
    cash_on_hand: sd.cash_on_hand || 0,
    momo_amount: sd.momo_amount || 0,
    cash_balance_delta: sd.cash_balance_delta || 0,
    currency_total_cash: sd.currency_total_cash || 0,
  };

  const pastries: PastryLine[] = (pastriesRes.data || []).map((p: Record<string, unknown>) => ({
    id: p.id as string,
    item_name: p.item_name as string,
    qty_received: Number(p.qty_received) || 0,
    received_from_other_qty: Number(p.received_from_other_qty) || 0,
    received_from_branch_id: p.received_from_branch_id as string | null,
    received_from_branch_name: (p.received_from_branch as { name?: string } | null)?.name || null,
    transfer_to_other_qty: Number(p.transfer_to_other_qty) || 0,
    transfer_to_branch_id: p.transfer_to_branch_id as string | null,
    transfer_to_branch_name: (p.transfer_to_branch as { name?: string } | null)?.name || null,
    qty_sold: Number(p.qty_sold) || 0,
    unit_price: Number(p.unit_price) || 0,
    leftovers: Number(p.leftovers) || 0,
    amount: Number(p.amount) || 0,
  }));

  const yoghurtHeader: YoghurtHeader | null = yoghurtHeaderRes.data
    ? {
        sheet_id: yoghurtHeaderRes.data.sheet_id,
        opening_stock: Number(yoghurtHeaderRes.data.opening_stock) || 0,
        stock_received: Number(yoghurtHeaderRes.data.stock_received) || 0,
        total_stock: Number(yoghurtHeaderRes.data.total_stock) || 0,
        closing_stock: Number(yoghurtHeaderRes.data.closing_stock) || 0,
      }
    : null;

  const yoghurtContainers: YoghurtContainerLine[] = (yoghurtContainersRes.data || []).map(
    (c: Record<string, unknown>) => ({
      id: c.id as string,
      item_name: c.item_name as string,
      volume_factor: Number(c.volume_factor) || 1,
      qty_sold: Number(c.qty_sold) || 0,
      volume_sold: Number(c.volume_sold) || 0,
      unit_price: Number(c.unit_price) || 0,
      income: Number(c.income) || 0,
    })
  );

  const yoghurtRefills: YoghurtRefillLine[] = (yoghurtRefillsRes.data || []).map(
    (r: Record<string, unknown>) => ({
      id: r.id as string,
      item_name: r.item_name as string,
      volume_factor: Number(r.volume_factor) || 1,
      qty_sold: Number(r.qty_sold) || 0,
      volume_sold: Number(r.volume_sold) || 0,
      unit_price: Number(r.unit_price) || 0,
      income: Number(r.income) || 0,
    })
  );

  const yoghurtNonContainer: YoghurtNonContainer | null = yoghurtNonContainerRes.data
    ? {
        id: yoghurtNonContainerRes.data.id,
        item_name: yoghurtNonContainerRes.data.item_name,
        unit_price: Number(yoghurtNonContainerRes.data.unit_price) || 0,
        volume_sold: Number(yoghurtNonContainerRes.data.volume_sold) || 0,
        income: Number(yoghurtNonContainerRes.data.income) || 0,
      }
    : null;

  const yoghurtSectionB: YoghurtSectionBIncome[] = (yoghurtSectionBRes.data || []).map(
    (b: Record<string, unknown>) => ({
      id: b.id as string,
      source: b.source as "pastries" | "smoothies" | "water",
      unit_price: b.unit_price != null ? Number(b.unit_price) : null,
      qty_sold: b.qty_sold != null ? Number(b.qty_sold) : null,
      income: Number(b.income) || 0,
    })
  );

  const materials: MaterialLine[] = (materialsRes.data || []).map((m: Record<string, unknown>) => ({
    id: m.id as string,
    item_name: m.item_name as string,
    opening: Number(m.opening) || 0,
    received: Number(m.received) || 0,
    used_normal: Number(m.used_normal) || 0,
    used_spoilt: Number(m.used_spoilt) || 0,
    transferred_out: Number(m.transferred_out) || 0,
    transfer_to_branch_id: m.transfer_to_branch_id as string | null,
    transfer_to_branch_name: (m.transfer_to_branch as { name?: string } | null)?.name || null,
    total_used: Number(m.total_used) || 0,
    closing: Number(m.closing) || 0,
  }));

  const currencyNotes: CurrencyNote[] = (currencyNotesRes.data || []).map(
    (n: Record<string, unknown>) => ({
      id: n.id as string,
      denomination: Number(n.denomination) || 0,
      quantity: Number(n.quantity) || 0,
      amount: Number(n.amount) || 0,
    })
  );

  const staff: StaffEntry[] = (staffRes.data || []).map((s: Record<string, unknown>) => ({
    id: s.id as string,
    staff_name: s.staff_name as string,
  }));

  const expenses: ExtraExpense[] = (expensesRes.data || []).map((e: Record<string, unknown>) => ({
    id: e.id as string,
    description: e.description as string,
    amount: Number(e.amount) || 0,
    created_at: e.created_at as string,
  }));

  return {
    header,
    pastries,
    yoghurtHeader,
    yoghurtContainers,
    yoghurtRefills,
    yoghurtNonContainer,
    yoghurtSectionB,
    materials,
    currencyNotes,
    staff,
    expenses,
  };
}

/**
 * Helper to update any editable table row.
 */
export async function updateTableRow(
  client: Client,
  table: string,
  id: string,
  patch: Record<string, unknown>
) {
  const { error } = await client.from(table).update(patch).eq("id", id);
  if (error) {
    throw new Error(error.message);
  }
}

export async function insertRow(
  client: Client,
  table: string,
  payload: Record<string, unknown>
): Promise<{ id: string }> {
  const { data, error } = await client.from(table).insert(payload).select("id").single();
  if (error) {
    throw new Error(error.message);
  }
  return { id: data.id };
}

export async function deleteRow(client: Client, table: string, id: string) {
  const { error } = await client.from(table).delete().eq("id", id);
  if (error) {
    throw new Error(error.message);
  }
}

/**
 * Submit the complete sheet with all calculated values.
 * Updates all line items and the sheet header with frontend-computed values.
 */
export async function submitSheet(
  client: Client,
  payload: SheetPayload
): Promise<void> {
  const sheetId = payload.header.id;

  // Update all pastry lines
  for (const line of payload.pastries) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (client as any)
      .from("pastry_lines")
      .update({
        qty_received: line.qty_received,
        received_from_other_qty: line.received_from_other_qty,
        received_from_branch_id: line.received_from_branch_id || null,
        transfer_to_other_qty: line.transfer_to_other_qty,
        transfer_to_branch_id: line.transfer_to_branch_id || null,
        qty_sold: line.qty_sold,
        leftovers: line.leftovers,
        amount: line.amount,
      })
      .eq("id", line.id);
    if (error) throw new Error(`Pastry line update failed: ${error.message}`);
  }

  // Update yoghurt header
  if (payload.yoghurtHeader) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (client as any)
      .from("yoghurt_headers")
      .update({
        opening_stock: payload.yoghurtHeader.opening_stock,
        stock_received: payload.yoghurtHeader.stock_received,
        total_stock: payload.yoghurtHeader.total_stock,
        closing_stock: payload.yoghurtHeader.closing_stock,
      })
      .eq("sheet_id", sheetId);
    if (error) throw new Error(`Yoghurt header update failed: ${error.message}`);
  }

  // Update yoghurt container lines
  for (const line of payload.yoghurtContainers) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (client as any)
      .from("yoghurt_container_lines")
      .update({
        qty_sold: line.qty_sold,
        volume_sold: line.volume_sold,
        income: line.income,
      })
      .eq("id", line.id);
    if (error) throw new Error(`Yoghurt container update failed: ${error.message}`);
  }

  // Update yoghurt refill lines
  for (const line of payload.yoghurtRefills) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (client as any)
      .from("yoghurt_refill_lines")
      .update({
        qty_sold: line.qty_sold,
        volume_sold: line.volume_sold,
        income: line.income,
      })
      .eq("id", line.id);
    if (error) throw new Error(`Yoghurt refill update failed: ${error.message}`);
  }

  // Update yoghurt non-container
  if (payload.yoghurtNonContainer) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (client as any)
      .from("yoghurt_non_container")
      .update({
        volume_sold: payload.yoghurtNonContainer.volume_sold,
        income: payload.yoghurtNonContainer.income,
      })
      .eq("id", payload.yoghurtNonContainer.id);
    if (error) throw new Error(`Yoghurt non-container update failed: ${error.message}`);
  }

  // Update yoghurt section B
  for (const line of payload.yoghurtSectionB) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (client as any)
      .from("yoghurt_section_b_income")
      .update({
        qty_sold: line.qty_sold,
        income: line.income,
      })
      .eq("id", line.id);
    if (error) throw new Error(`Section B update failed: ${error.message}`);
  }

  // Update material lines
  for (const line of payload.materials) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (client as any)
      .from("material_lines")
      .update({
        opening: line.opening,
        received: line.received,
        used_normal: line.used_normal,
        used_spoilt: line.used_spoilt,
        transferred_out: line.transferred_out,
        transfer_to_branch_id: line.transfer_to_branch_id || null,
        total_used: line.total_used,
        closing: line.closing,
      })
      .eq("id", line.id);
    if (error) throw new Error(`Material line update failed: ${error.message}`);
  }

  // Update currency notes
  for (const note of payload.currencyNotes) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (client as any)
      .from("currency_notes")
      .update({
        quantity: note.quantity,
        amount: note.amount,
      })
      .eq("id", note.id);
    if (error) throw new Error(`Currency note update failed: ${error.message}`);
  }

  // Update sheet header with all totals
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { error: headerError } = await (client as any)
    .from("daily_sheets")
    .update({
      total_pastries_income: payload.header.total_pastries_income,
      yoghurt_section_a_total_volume: payload.header.yoghurt_section_a_total_volume,
      yoghurt_section_a_total_income: payload.header.yoghurt_section_a_total_income,
      yoghurt_section_b_total: payload.header.yoghurt_section_b_total,
      grand_total: payload.header.grand_total,
      currency_total_cash: payload.header.currency_total_cash || 0,
      cash_on_hand: payload.header.cash_on_hand,
      momo_amount: payload.header.momo_amount,
      cash_balance_delta: payload.header.cash_balance_delta,
      locked: true,
    })
    .eq("id", sheetId);

  if (headerError) {
    throw new Error(`Sheet header update failed: ${headerError.message}`);
  }
}


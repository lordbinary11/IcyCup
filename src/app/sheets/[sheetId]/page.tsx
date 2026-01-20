"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useParams } from "next/navigation";
import {
  fetchSheet,
  insertRow,
  deleteRow,
  submitSheet,
} from "@/lib/sheetApi";
import { exportElementToPdf } from "@/lib/pdf";
import { createBrowserSupabaseClient } from "@/lib/supabaseBrowser";
import {
  CurrencyNote,
  ExtraExpense,
  MaterialLine,
  PastryLine,
  SheetPayload,
  StaffEntry,
  YoghurtContainerLine,
  YoghurtHeader,
  YoghurtNonContainer,
  YoghurtRefillLine,
  YoghurtSectionBIncome,
} from "@/lib/types";

type Params = {
  sheetId: string;
};

// ============================================================================
// FRONTEND CALCULATION HELPERS
// ============================================================================

function computePastryLine(line: PastryLine): PastryLine {
  const leftovers =
    (line.qty_received + line.received_from_other_qty) -
    (line.qty_sold + line.transfer_to_other_qty);
  const amount = line.qty_sold * line.unit_price;
  return { ...line, leftovers, amount };
}

function computeYoghurtContainerLine(line: YoghurtContainerLine): YoghurtContainerLine {
  const volume_sold = line.qty_sold * line.volume_factor;
  const income = line.qty_sold * line.unit_price;
  return { ...line, volume_sold, income };
}

function computeYoghurtRefillLine(line: YoghurtRefillLine): YoghurtRefillLine {
  const volume_sold = line.qty_sold * line.volume_factor;
  const income = line.qty_sold * line.unit_price;
  return { ...line, volume_sold, income };
}

function computeYoghurtNonContainer(line: YoghurtNonContainer): YoghurtNonContainer {
  const income = line.volume_sold * line.unit_price;
  return { ...line, income };
}

function computeMaterialLine(line: MaterialLine): MaterialLine {
  const total_used = line.used_normal + line.used_spoilt;
  const closing = (line.opening + line.received) - (total_used + line.transferred_out);
  return { ...line, total_used, closing };
}

function computeCurrencyNote(note: CurrencyNote): CurrencyNote {
  const amount = note.denomination * note.quantity;
  return { ...note, amount };
}

function computeYoghurtHeader(
  header: YoghurtHeader,
  totalVolumeSold: number
): YoghurtHeader {
  const total_stock = header.opening_stock + header.stock_received;
  const closing_stock = total_stock - totalVolumeSold;
  return { ...header, total_stock, closing_stock };
}

function computeSheetTotals(data: SheetPayload): SheetPayload {
  // Compute all line items first
  const pastries = data.pastries.map(computePastryLine);
  const yoghurtContainers = data.yoghurtContainers.map(computeYoghurtContainerLine);
  const yoghurtRefills = data.yoghurtRefills.map(computeYoghurtRefillLine);
  const yoghurtNonContainer = data.yoghurtNonContainer
    ? computeYoghurtNonContainer(data.yoghurtNonContainer)
    : null;
  const materials = data.materials.map(computeMaterialLine);
  const currencyNotes = data.currencyNotes.map(computeCurrencyNote);

  // Compute totals
  const total_pastries_income = pastries.reduce((sum, p) => sum + p.amount, 0);

  const yoghurt_section_a_total_volume =
    yoghurtContainers.reduce((sum, c) => sum + c.volume_sold, 0) +
    yoghurtRefills.reduce((sum, r) => sum + r.volume_sold, 0) +
    (yoghurtNonContainer?.volume_sold || 0);

  const yoghurt_section_a_total_income =
    yoghurtContainers.reduce((sum, c) => sum + c.income, 0) +
    yoghurtRefills.reduce((sum, r) => sum + r.income, 0) +
    (yoghurtNonContainer?.income || 0);

  // Section B: update pastries income row, compute others
  const yoghurtSectionB = data.yoghurtSectionB.map((row) => {
    if (row.source === "pastries") {
      return { ...row, income: total_pastries_income };
    }
    const income = (row.qty_sold || 0) * (row.unit_price || 0);
    return { ...row, income };
  });

  const yoghurt_section_b_total = yoghurtSectionB.reduce((sum, b) => sum + b.income, 0);

  const grand_total = yoghurt_section_a_total_income + yoghurt_section_b_total;

  const currency_total_cash = currencyNotes.reduce((sum, n) => sum + n.amount, 0);

  const cash_balance_delta =
    (data.header.cash_on_hand + data.header.momo_amount) - grand_total;

  // Compute yoghurt header
  const yoghurtHeader = data.yoghurtHeader
    ? computeYoghurtHeader(data.yoghurtHeader, yoghurt_section_a_total_volume)
    : null;

  return {
    ...data,
    pastries,
    yoghurtContainers,
    yoghurtRefills,
    yoghurtNonContainer,
    yoghurtSectionB,
    materials,
    currencyNotes,
    yoghurtHeader,
    header: {
      ...data.header,
      total_pastries_income,
      yoghurt_section_a_total_volume,
      yoghurt_section_a_total_income,
      yoghurt_section_b_total,
      grand_total,
      currency_total_cash,
      cash_balance_delta,
    },
  };
}

// ============================================================================
// MAIN COMPONENT
// ============================================================================

export default function SheetPage() {
  const params = useParams<Params>();
  const sheetId = useMemo(() => params?.sheetId, [params]);
  const [data, setData] = useState<SheetPayload | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const pdfRef = useRef<HTMLDivElement | null>(null);
  const supabase = useMemo(() => createBrowserSupabaseClient(), []);
  const [branches, setBranches] = useState<Array<{ id: string; name: string; code: string }>>(
    []
  );

  const loadSheet = useCallback(
    async (opts?: { silent?: boolean }) => {
      if (!sheetId) return;
      const silent = opts?.silent ?? false;
      if (!silent) {
        setLoading(true);
      }
      setError(null);
      try {
        const payload = await fetchSheet(supabase, sheetId);
        // Compute all derived values on load
        setData(computeSheetTotals(payload));
      } catch (err) {
        const message = err instanceof Error ? err.message : "Unable to load sheet";
        setError(message);
      } finally {
        if (!silent) {
          setLoading(false);
        }
      }
    },
    [sheetId, supabase]
  );

  useEffect(() => {
    void loadSheet();
  }, [loadSheet]);

  useEffect(() => {
    // Fetch branches for drop-downs
    void (async () => {
      const { data: branchesData } = await supabase.from("branches").select("id, name, code");
      if (branchesData) {
        setBranches(
          branchesData.map((b: { id: string; name: string | null; code: string | null }) => ({
            id: b.id,
            name: b.name ?? "",
            code: b.code ?? "",
          }))
        );
      }
    })();
  }, [supabase]);

  // Update local state and recompute totals (no API call)
  const updateLocalData = useCallback(
    (updater: (prev: SheetPayload) => SheetPayload) => {
      setData((prev) => {
        if (!prev) return prev;
        const updated = updater(prev);
        return computeSheetTotals(updated);
      });
    },
    []
  );

  // Handle staff insert - updates local state immediately
  const handleStaffAdd = useCallback(
    async (name: string) => {
      if (!data) return;
      setSaving(true);
      setError(null);
      try {
        const { id } = await insertRow(supabase, "staff_attendance", {
          sheet_id: data.header.id,
          staff_name: name,
        });
        // Update local state with the new staff entry
        setData((prev) => {
          if (!prev) return prev;
          return {
            ...prev,
            staff: [...prev.staff, { id, staff_name: name }],
          };
        });
      } catch (err) {
        const message =
          err instanceof Error ? err.message : "Unable to add staff";
        setError(message);
      } finally {
        setSaving(false);
      }
    },
    [data, supabase]
  );

  // Handle expense insert - updates local state immediately
  const handleExpenseAdd = useCallback(
    async (description: string, amount: number) => {
      if (!data) return;
      setSaving(true);
      setError(null);
      try {
        const { id } = await insertRow(supabase, "extra_expenses", {
          sheet_id: data.header.id,
          description,
          amount,
        });
        // Update local state with the new expense
        setData((prev) => {
          if (!prev) return prev;
          return {
            ...prev,
            expenses: [...prev.expenses, { id, description, amount, created_at: new Date().toISOString() }],
          };
        });
      } catch (err) {
        const message =
          err instanceof Error ? err.message : "Unable to add expense";
        setError(message);
      } finally {
        setSaving(false);
      }
    },
    [data, supabase]
  );

  // Handle staff delete - updates local state immediately
  const handleStaffDelete = useCallback(
    async (id: string) => {
      setSaving(true);
      setError(null);
      try {
        await deleteRow(supabase, "staff_attendance", id);
        // Update local state
        setData((prev) => {
          if (!prev) return prev;
          return {
            ...prev,
            staff: prev.staff.filter((s) => s.id !== id),
          };
        });
      } catch (err) {
        const message =
          err instanceof Error ? err.message : "Unable to delete row";
        setError(message);
      } finally {
        setSaving(false);
      }
    },
    [supabase]
  );

  // Handle expense delete - updates local state immediately
  const handleExpenseDelete = useCallback(
    async (id: string) => {
      setSaving(true);
      setError(null);
      try {
        await deleteRow(supabase, "extra_expenses", id);
        // Update local state
        setData((prev) => {
          if (!prev) return prev;
          return {
            ...prev,
            expenses: prev.expenses.filter((e) => e.id !== id),
          };
        });
      } catch (err) {
        const message =
          err instanceof Error ? err.message : "Unable to delete expense";
        setError(message);
      } finally {
        setSaving(false);
      }
    },
    [supabase]
  );

  // Submit the complete sheet to the database
  const handleSubmit = useCallback(async () => {
    if (!data) return;
    if (data.staff.length === 0) {
      setError("Staff attendance is required before submission");
      return;
    }
    setSaving(true);
    setError(null);
    try {
      await submitSheet(supabase, data);
      await loadSheet({ silent: true });
    } catch (err) {
      const message = err instanceof Error ? err.message : "Unable to submit sheet";
      setError(message);
    } finally {
      setSaving(false);
    }
  }, [data, supabase, loadSheet]);

  if (loading) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-slate-50 text-sm text-slate-700">
        Loading sheet…
      </main>
    );
  }

  if (!data || !sheetId) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-slate-50 text-sm text-rose-700">
        Unable to locate sheet.
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-slate-50 text-slate-900">
      <div
        ref={pdfRef}
        className="mx-auto flex max-w-7xl flex-col gap-6 px-4 py-6 bg-white"
      >
        <header className="flex flex-col gap-2 rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="text-xs uppercase tracking-widest text-slate-500">
                Daily Sales Analysis Sheet
              </p>
              <h1 className="text-2xl font-semibold leading-tight">
                {data.header.branch_name}
              </h1>
              <p className="text-sm text-slate-600">
                Date: {data.header.sheet_date} · Supervisor:{" "}
                {data.header.supervisor_name ?? "—"}
              </p>
            </div>
            <div className="text-right text-sm">
              <div
                className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${
                  data.header.locked
                    ? "bg-amber-100 text-amber-800"
                    : "bg-emerald-100 text-emerald-800"
                }`}
              >
                {data.header.locked ? "Locked" : "Editable"}
              </div>
              <div className="mt-2 flex items-center justify-end gap-2">
                {!data.header.locked && (
                  <button
                    className="rounded-md border border-slate-300 bg-white px-3 py-2 text-xs font-semibold text-slate-800 shadow-sm disabled:opacity-50"
                    disabled={saving}
                    onClick={handleSubmit}
                  >
                    {saving ? "Submitting..." : "Submit sheet"}
                  </button>
                )}
                <button
                  className="rounded-md bg-slate-900 px-3 py-2 text-xs font-semibold text-white shadow-sm"
                  onClick={async () => {
                    if (!pdfRef.current) return;
                    await exportElementToPdf(pdfRef.current, {
                      filename: `${data.header.branch_name}_${data.header.sheet_date}_DailySheet.pdf`,
                    });
                  }}
                >
                  Download PDF
                </button>
              </div>
              <p className="mt-2 text-xs text-slate-500">
                All calculations are done in the browser. Click Submit to save.
              </p>
            </div>
          </div>
          {error && (
            <p className="rounded-md border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700">
              {error}
            </p>
          )}
          {saving && (
            <p className="rounded-md border border-slate-200 bg-slate-100 px-3 py-2 text-xs text-slate-700">
              Saving…
            </p>
          )}
        </header>

        <PastriesRecord
          lines={data.pastries}
          locked={data.header.locked}
          branches={branches}
          onChange={(id, patch) =>
            updateLocalData((prev) => ({
              ...prev,
              pastries: prev.pastries.map((p) =>
                p.id === id ? { ...p, ...patch } : p
              ),
            }))
          }
        />

        <YoghurtRecord
          header={data.yoghurtHeader}
          containers={data.yoghurtContainers}
          refills={data.yoghurtRefills}
          nonContainer={data.yoghurtNonContainer}
          sectionB={data.yoghurtSectionB}
          totals={{
            volume: data.header.yoghurt_section_a_total_volume,
            income: data.header.yoghurt_section_a_total_income,
            sectionB: data.header.yoghurt_section_b_total,
            grand: data.header.grand_total,
            pastriesIncome: data.header.total_pastries_income,
          }}
          locked={data.header.locked}
          onUpdate={(table, id, patch) => {
            updateLocalData((prev) => {
              if (table === "yoghurt_headers") {
                return {
                  ...prev,
                  yoghurtHeader: prev.yoghurtHeader
                    ? { ...prev.yoghurtHeader, ...patch }
                    : prev.yoghurtHeader,
                };
              }
              if (table === "yoghurt_container_lines") {
                return {
                  ...prev,
                  yoghurtContainers: prev.yoghurtContainers.map((c) =>
                    c.id === id ? { ...c, ...patch } : c
                  ),
                };
              }
              if (table === "yoghurt_refill_lines") {
                return {
                  ...prev,
                  yoghurtRefills: prev.yoghurtRefills.map((r) =>
                    r.id === id ? { ...r, ...patch } : r
                  ),
                };
              }
              if (table === "yoghurt_non_container") {
                return {
                  ...prev,
                  yoghurtNonContainer: prev.yoghurtNonContainer
                    ? { ...prev.yoghurtNonContainer, ...patch }
                    : prev.yoghurtNonContainer,
                };
              }
              if (table === "yoghurt_section_b_income") {
                return {
                  ...prev,
                  yoghurtSectionB: prev.yoghurtSectionB.map((b) =>
                    b.id === id ? { ...b, ...patch } : b
                  ),
                };
              }
              return prev;
            });
          }}
        />

        <CashSummary
          cashOnHand={data.header.cash_on_hand}
          momo={data.header.momo_amount}
          grandTotal={data.header.grand_total}
          cashDelta={data.header.cash_balance_delta}
          locked={data.header.locked}
          onChange={(patch) =>
            updateLocalData((prev) => ({
              ...prev,
              header: { ...prev.header, ...patch },
            }))
          }
        />

        <MaterialsRecord
          lines={data.materials}
          locked={data.header.locked}
          branches={branches}
          onChange={(id, patch) =>
            updateLocalData((prev) => ({
              ...prev,
              materials: prev.materials.map((m) =>
                m.id === id ? { ...m, ...patch } : m
              ),
            }))
          }
        />

        <CurrencyNotesRecord
          notes={data.currencyNotes}
          notesTotal={data.header.currency_total_cash ?? 0}
          locked={data.header.locked}
          onChange={(id, patch) =>
            updateLocalData((prev) => ({
              ...prev,
              currencyNotes: prev.currencyNotes.map((n) =>
                n.id === id ? { ...n, ...patch } : n
              ),
            }))
          }
        />

        <StaffAttendance
          staff={data.staff}
          locked={data.header.locked}
          onAdd={handleStaffAdd}
          onDelete={handleStaffDelete}
        />

        <ExtraExpenses
          expenses={data.expenses}
          locked={data.header.locked}
          onAdd={handleExpenseAdd}
          onDelete={handleExpenseDelete}
        />
      </div>
    </main>
  );
}

function SectionFrame({
  title,
  children,
  defaultOpen = true,
}: {
  title: string;
  children: React.ReactNode;
  defaultOpen?: boolean;
}) {
  const [isOpen, setIsOpen] = useState(defaultOpen);
  return (
    <section className="rounded-lg border border-slate-200 bg-white shadow-sm">
      <button
        type="button"
        className="flex w-full items-center justify-between border-b border-slate-200 bg-slate-50 px-4 py-2 text-left text-sm font-semibold uppercase tracking-wide text-slate-700"
        onClick={() => setIsOpen(!isOpen)}
      >
        <span>{title}</span>
        <span className="text-slate-400">{isOpen ? "▼" : "▶"}</span>
      </button>
      {isOpen && <div className="p-4">{children}</div>}
    </section>
  );
}

function PastriesRecord({
  lines,
  locked,
  branches,
  onChange,
}: {
  lines: PastryLine[];
  locked: boolean;
  branches: { id: string; name: string; code: string }[];
  onChange: (id: string, patch: Partial<PastryLine>) => void;
}) {
  const totalIncome = lines.reduce((acc, l) => acc + (l.amount ?? 0), 0);
  return (
    <SectionFrame title="Pastries Record">
      <div className="overflow-x-auto">
        <div className="grid min-w-[700px] grid-cols-8 text-[11px] font-semibold uppercase text-slate-600">
          <div className="border border-slate-200 bg-slate-50 px-2 py-1">Item</div>
          <div className="border border-slate-200 bg-slate-50 px-2 py-1">Received</div>
          <div className="border border-slate-200 bg-slate-50 px-2 py-1">Rec From</div>
          <div className="border border-slate-200 bg-slate-50 px-2 py-1">Trans To</div>
          <div className="border border-slate-200 bg-slate-50 px-2 py-1">Sold</div>
          <div className="border border-slate-200 bg-slate-50 px-2 py-1">Unit</div>
          <div className="border border-slate-200 bg-slate-50 px-2 py-1">Left</div>
          <div className="border border-slate-200 bg-slate-50 px-2 py-1">Amount</div>
        </div>
        {lines.map((line) => (
          <div key={line.id} className="grid min-w-[700px] grid-cols-8 text-[11px]">
            <div className="border border-slate-200 px-2 py-1 font-medium text-slate-800">
              {line.item_name}
            </div>
            <input
              className="border border-slate-200 px-2 py-1 text-right"
              type="number"
              disabled={locked}
              value={line.qty_received ?? 0}
              onChange={(e) =>
                onChange(line.id, { qty_received: Number(e.target.value) })
              }
            />
            <div className="flex border border-slate-200">
              <input
                className="w-12 px-1 py-1 text-right"
                type="number"
                placeholder="Qty"
                disabled={locked}
                value={line.received_from_other_qty ?? 0}
                onChange={(e) =>
                  onChange(line.id, {
                    received_from_other_qty: Number(e.target.value),
                  })
                }
              />
              <select
                className="flex-1 px-1 py-1 text-[10px]"
                disabled={locked}
                value={line.received_from_branch_id ?? ""}
                onChange={(e) =>
                  onChange(line.id, {
                    received_from_branch_id: e.target.value || null,
                  })
                }
              >
                <option value="">Branch</option>
                {branches.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.code}
                  </option>
                ))}
              </select>
            </div>
            <div className="flex border border-slate-200">
              <input
                className="w-12 px-1 py-1 text-right"
                type="number"
                placeholder="Qty"
                disabled={locked}
                value={line.transfer_to_other_qty ?? 0}
                onChange={(e) =>
                  onChange(line.id, {
                    transfer_to_other_qty: Number(e.target.value),
                  })
                }
              />
              <select
                className="flex-1 px-1 py-1 text-[10px]"
                disabled={locked}
                value={line.transfer_to_branch_id ?? ""}
                onChange={(e) =>
                  onChange(line.id, {
                    transfer_to_branch_id: e.target.value || null,
                  })
                }
              >
                <option value="">Branch</option>
                {branches.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.code}
                  </option>
                ))}
              </select>
            </div>
            <input
              className="border border-slate-200 px-2 py-1 text-right"
              type="number"
              disabled={locked}
              value={line.qty_sold ?? 0}
              onChange={(e) =>
                onChange(line.id, { qty_sold: Number(e.target.value) })
              }
            />
            <div className="border border-slate-200 px-2 py-1 text-right font-semibold text-slate-700">
              {line.unit_price?.toFixed(2)}
            </div>
            <div className="border border-slate-200 px-2 py-1 text-right">
              {line.leftovers}
            </div>
            <div className="border border-slate-200 px-2 py-1 text-right font-semibold text-slate-800">
              {line.amount?.toFixed(2)}
            </div>
          </div>
        ))}
        <div className="grid min-w-[700px] grid-cols-8 text-[11px] font-semibold uppercase text-slate-700">
          <div className="border border-slate-200 bg-slate-50 px-2 py-1">Total</div>
          <div className="border border-slate-200 px-2 py-1 text-right">—</div>
          <div className="border border-slate-200 px-2 py-1 text-right">—</div>
          <div className="border border-slate-200 px-2 py-1 text-right">—</div>
          <div className="border border-slate-200 px-2 py-1 text-right">—</div>
          <div className="border border-slate-200 px-2 py-1 text-right">—</div>
          <div className="border border-slate-200 px-2 py-1 text-right">—</div>
          <div className="border border-slate-200 px-2 py-1 text-right font-semibold">
            {totalIncome.toFixed(2)}
          </div>
        </div>
      </div>
    </SectionFrame>
  );
}

function YoghurtRecord({
  header,
  containers,
  refills,
  nonContainer,
  sectionB,
  totals,
  locked,
  onUpdate,
}: {
  header: YoghurtHeader | null;
  containers: YoghurtContainerLine[];
  refills: YoghurtRefillLine[];
  nonContainer: YoghurtNonContainer | null;
  sectionB: YoghurtSectionBIncome[];
  totals: {
    volume: number;
    income: number;
    sectionB: number;
    grand: number;
    pastriesIncome: number;
  };
  locked: boolean;
  onUpdate: (table: string, id: string, patch: Record<string, unknown>) => void;
}) {
  const sectionATotals = (
    <div className="mt-4 grid grid-cols-4 gap-3 text-sm">
      <ReadOnlyField label="Section A Volume Sold" value={totals.volume} />
      <ReadOnlyField label="Section A Income" value={totals.income} />
      <div />
      <div />
    </div>
  );

  return (
    <SectionFrame title="Yoghurt Record">
      <div className="mb-4 grid grid-cols-4 gap-3 text-sm">
        <Field
          label="Opening Stock"
          value={header?.opening_stock ?? 0}
          onChange={(value) =>
            onUpdate("yoghurt_headers", headerIdOrFail(header), {
              opening_stock: value,
            })
          }
          disabled={locked || !header}
        />
        <Field
          label="Stock Received"
          value={header?.stock_received ?? 0}
          onChange={(value) =>
            onUpdate("yoghurt_headers", headerIdOrFail(header), {
              stock_received: value,
            })
          }
          disabled={locked || !header}
        />
        <ReadOnlyField label="Total Stock" value={header?.total_stock ?? 0} />
        <ReadOnlyField
          label="Closing Stock"
          value={header?.closing_stock ?? 0}
        />
      </div>

      <YoghurtLines
        title="Section A – Container Sales"
        lines={containers}
        locked={locked}
        table="yoghurt_container_lines"
        onUpdate={onUpdate}
      />

      <YoghurtLines
        title="Refill"
        lines={refills}
        locked={locked}
        table="yoghurt_refill_lines"
        onUpdate={onUpdate}
      />

      {nonContainer ? (
        <div className="mt-6">
          <p className="mb-2 text-xs font-semibold uppercase text-slate-600">
            Non-Container Sales
          </p>
          <div className="grid grid-cols-5 text-xs font-semibold uppercase text-slate-600">
            <div className="border border-slate-200 bg-slate-50 p-2">Item</div>
            <div className="border border-slate-200 bg-slate-50 p-2">
              Volume Sold
            </div>
            <div className="border border-slate-200 bg-slate-50 p-2">
              Unit Price
            </div>
            <div className="border border-slate-200 bg-slate-50 p-2">Income</div>
            <div className="border border-slate-200 bg-slate-50 p-2">
              Action
            </div>
          </div>
          <div className="grid grid-cols-5 text-xs">
            <div className="border border-slate-200 p-2 font-medium text-slate-800">
              {nonContainer.item_name}
            </div>
            <input
              className="border border-slate-200 p-2 text-right"
              type="number"
              disabled={locked}
              value={nonContainer.volume_sold ?? 0}
              onChange={(e) =>
                onUpdate("yoghurt_non_container", nonContainer.id, {
                  volume_sold: Number(e.target.value),
                })
              }
            />
            <div className="border border-slate-200 p-2 text-right font-semibold text-slate-700">
              {nonContainer.unit_price?.toFixed(2)}
            </div>
            <div className="border border-slate-200 p-2 text-right font-semibold text-slate-800">
              {nonContainer.income?.toFixed(2)}
            </div>
            <div className="border border-slate-200 p-2 text-center text-[11px] text-slate-500">
              Income derives from backend (volume_sold × snapped price).
            </div>
          </div>
        </div>
      ) : (
        <p className="mt-4 text-xs text-slate-500">
          Non-container row missing. Ensure seed_sheet_lines ran.
        </p>
      )}

      {sectionATotals}

      <div className="mt-6">
        <p className="mb-2 text-xs font-semibold uppercase text-slate-600">
          Section B – Other Income
        </p>
        <div className="grid grid-cols-5 text-xs font-semibold uppercase text-slate-600">
          <div className="border border-slate-200 bg-slate-50 p-2">Source</div>
          <div className="border border-slate-200 bg-slate-50 p-2">Quantity</div>
          <div className="border border-slate-200 bg-slate-50 p-2">Unit Price</div>
          <div className="border border-slate-200 bg-slate-50 p-2">Income</div>
          <div className="border border-slate-200 bg-slate-50 p-2">Note</div>
        </div>
        {sectionB.map((row) => (
          <div className="grid grid-cols-5 text-xs" key={row.id}>
            <div className="border border-slate-200 p-2 font-medium text-slate-800 capitalize">
              {row.source}
            </div>
            <input
              className="border border-slate-200 p-2 text-right"
              type="number"
              disabled={locked || row.source === "pastries"}
              value={row.qty_sold ?? 0}
              onChange={(e) =>
                onUpdate("yoghurt_section_b_income", row.id, {
                  qty_sold: Number(e.target.value),
                })
              }
            />
            <div className="border border-slate-200 p-2 text-right font-semibold text-slate-700">
              {row.unit_price ? row.unit_price.toFixed(2) : "—"}
            </div>
            <div className="border border-slate-200 p-2 text-right font-semibold text-slate-800">
              {row.income?.toFixed(2)}
            </div>
            <div className="border border-slate-200 p-2 text-[11px] text-slate-500">
              {row.source === "pastries"
                ? "Pastries income auto-carried"
                : "Backend snaps price + computes income"}
            </div>
          </div>
        ))}
      </div>

      <div className="mt-6 grid grid-cols-4 gap-3 text-sm">
        <ReadOnlyField
          label="Section B Total (incl. pastries)"
          value={totals.sectionB}
        />
        <ReadOnlyField label="Grand Total" value={totals.grand} />
        <div />
        <div />
      </div>
      <p className="mt-2 text-[11px] text-slate-500">
        All totals are supplied by Supabase after triggers recompute them.
      </p>
    </SectionFrame>
  );
}

function YoghurtLines({
  title,
  lines,
  table,
  locked,
  onUpdate,
}: {
  title: string;
  lines: (YoghurtContainerLine | YoghurtRefillLine)[];
  table: "yoghurt_container_lines" | "yoghurt_refill_lines";
  locked: boolean;
  onUpdate: (table: string, id: string, patch: Record<string, unknown>) => void;
}) {
  return (
    <div className="mt-6">
      <p className="mb-2 text-xs font-semibold uppercase text-slate-600">
        {title}
      </p>
      <div className="grid grid-cols-5 text-[11px] font-semibold uppercase text-slate-600">
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Item</div>
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Qty</div>
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Vol</div>
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Unit</div>
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Income</div>
      </div>
      {lines.map((line) => (
        <div className="grid grid-cols-5 text-[11px]" key={line.id}>
          <div className="border border-slate-200 px-2 py-1 font-medium text-slate-800">
            {line.item_name}
          </div>
          <input
            className="border border-slate-200 px-2 py-1 text-right"
            type="number"
            disabled={locked}
            value={line.qty_sold ?? 0}
            onChange={(e) =>
              onUpdate(table, line.id, { qty_sold: Number(e.target.value) })
            }
          />
          <div className="border border-slate-200 px-2 py-1 text-right">
            {line.volume_sold?.toFixed(2)}
          </div>
          <div className="border border-slate-200 px-2 py-1 text-right font-semibold text-slate-700">
            {line.unit_price?.toFixed(2)}
          </div>
          <div className="border border-slate-200 px-2 py-1 text-right font-semibold text-slate-800">
            {line.income?.toFixed(2)}
          </div>
        </div>
      ))}
    </div>
  );
}

function MaterialsRecord({
  lines,
  locked,
  branches,
  onChange,
}: {
  lines: MaterialLine[];
  locked: boolean;
  branches: { id: string; name: string; code: string }[];
  onChange: (id: string, patch: Partial<MaterialLine>) => void;
}) {
  const totals = lines.reduce(
    (acc, line) => {
      acc.opening += line.opening ?? 0;
      acc.received += line.received ?? 0;
      acc.used_normal += line.used_normal ?? 0;
      acc.used_spoilt += line.used_spoilt ?? 0;
      acc.transferred_out += line.transferred_out ?? 0;
      acc.total_used += line.total_used ?? 0;
      acc.closing += line.closing ?? 0;
      return acc;
    },
    {
      opening: 0,
      received: 0,
      used_normal: 0,
      used_spoilt: 0,
      transferred_out: 0,
      total_used: 0,
      closing: 0,
    }
  );

  return (
    <SectionFrame title="Materials Used Record">
      <div className="grid grid-cols-8 text-[11px] font-semibold uppercase text-slate-600">
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Item</div>
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Opening</div>
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Received</div>
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Used (Norm)</div>
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Used (Spoilt)</div>
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Transfer</div>
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Total Used</div>
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Closing</div>
      </div>
      {lines.map((line) => (
        <div key={line.id} className="grid grid-cols-8 text-[11px]">
          <div className="border border-slate-200 px-2 py-1 font-medium text-slate-800">
            {line.item_name}
          </div>
          <input
            className="border border-slate-200 px-2 py-1 text-right"
            type="number"
            disabled={locked}
            value={line.opening ?? 0}
            onChange={(e) =>
              onChange(line.id, { opening: Number(e.target.value) })
            }
          />
          <input
            className="border border-slate-200 px-2 py-1 text-right"
            type="number"
            disabled={locked}
            value={line.received ?? 0}
            onChange={(e) =>
              onChange(line.id, { received: Number(e.target.value) })
            }
          />
          <input
            className="border border-slate-200 px-2 py-1 text-right"
            type="number"
            disabled={locked}
            value={line.used_normal ?? 0}
            onChange={(e) =>
              onChange(line.id, { used_normal: Number(e.target.value) })
            }
          />
          <input
            className="border border-slate-200 px-2 py-1 text-right"
            type="number"
            disabled={locked}
            value={line.used_spoilt ?? 0}
            onChange={(e) =>
              onChange(line.id, { used_spoilt: Number(e.target.value) })
            }
          />
          <div className="flex border border-slate-200">
            <input
              className="w-12 px-1 py-1 text-right"
              type="number"
              placeholder="Qty"
              disabled={locked}
              value={line.transferred_out ?? 0}
              onChange={(e) =>
                onChange(line.id, { transferred_out: Number(e.target.value) })
              }
            />
            <select
              className="flex-1 px-1 py-1 text-[10px]"
              disabled={locked}
              value={line.transfer_to_branch_id ?? ""}
              onChange={(e) =>
                onChange(line.id, {
                  transfer_to_branch_id: e.target.value || null,
                })
              }
            >
              <option value="">Branch</option>
              {branches.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.code}
                </option>
              ))}
            </select>
          </div>
          <div className="border border-slate-200 px-2 py-1 text-right">
            {line.total_used}
          </div>
          <div className="border border-slate-200 px-2 py-1 text-right font-semibold">
            {line.closing}
          </div>
        </div>
      ))}
      <div className="grid grid-cols-8 text-[11px] font-semibold uppercase text-slate-700">
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Totals</div>
        <div className="border border-slate-200 px-2 py-1 text-right">
          {totals.opening}
        </div>
        <div className="border border-slate-200 px-2 py-1 text-right">
          {totals.received}
        </div>
        <div className="border border-slate-200 px-2 py-1 text-right">
          {totals.used_normal}
        </div>
        <div className="border border-slate-200 px-2 py-1 text-right">
          {totals.used_spoilt}
        </div>
        <div className="border border-slate-200 px-2 py-1 text-right">
          {totals.transferred_out}
        </div>
        <div className="border border-slate-200 px-2 py-1 text-right">
          {totals.total_used}
        </div>
        <div className="border border-slate-200 px-2 py-1 text-right font-semibold">
          {totals.closing}
        </div>
      </div>
    </SectionFrame>
  );
}

function CurrencyNotesRecord({
  notes,
  notesTotal,
  locked,
  onChange,
}: {
  notes: CurrencyNote[];
  notesTotal?: number;
  locked: boolean;
  onChange: (id: string, patch: Partial<CurrencyNote>) => void;
}) {
  return (
    <SectionFrame title="Currency Notes Record">
      <div className="grid grid-cols-3 text-[11px] font-semibold uppercase text-slate-600">
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Denomination</div>
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Quantity</div>
        <div className="border border-slate-200 bg-slate-50 px-2 py-1">Amount</div>
      </div>
      {notes.map((note) => (
        <div className="grid grid-cols-3 text-[11px]" key={note.id}>
          <div className="border border-slate-200 px-2 py-1 text-right">
            {note.denomination}
          </div>
          <input
            className="border border-slate-200 px-2 py-1 text-right"
            type="number"
            disabled={locked}
            value={note.quantity ?? 0}
            onChange={(e) =>
              onChange(note.id, { quantity: Number(e.target.value) })
            }
          />
          <div className="border border-slate-200 px-2 py-1 text-right font-semibold text-slate-800">
            {note.amount?.toFixed(2)}
          </div>
        </div>
      ))}
      <div className="mt-2 text-sm font-semibold text-slate-800">
        Total Cash: {(notesTotal ?? 0).toFixed(2)}
      </div>
    </SectionFrame>
  );
}

function StaffAttendance({
  staff,
  locked,
  onAdd,
  onDelete,
}: {
  staff: StaffEntry[];
  locked: boolean;
  onAdd: (name: string) => void;
  onDelete: (id: string) => void;
}) {
  const [name, setName] = useState("");
  return (
    <SectionFrame title="Staff Attendance">
      <div className="flex flex-wrap items-center gap-2">
        {staff.map((s) => (
          <span
            key={s.id}
            className="inline-flex items-center gap-2 rounded-full border border-slate-200 bg-slate-100 px-3 py-1 text-sm"
          >
            {s.staff_name}
            {!locked && (
              <button
                className="text-rose-600"
                onClick={() => onDelete(s.id)}
                aria-label={`Remove ${s.staff_name}`}
              >
                ×
              </button>
            )}
          </span>
        ))}
      </div>
      {!locked && (
        <div className="mt-3 flex gap-2">
          <input
            className="w-64 rounded-md border border-slate-300 px-3 py-2 text-sm shadow-sm focus:border-slate-500 focus:outline-none"
            placeholder="Add staff name"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
          <button
            className="rounded-md bg-slate-900 px-3 py-2 text-sm font-semibold text-white shadow-sm disabled:opacity-50"
            disabled={!name}
            onClick={() => {
              onAdd(name);
              setName("");
            }}
          >
            Add
          </button>
        </div>
      )}
      <p className="mt-2 text-[11px] text-slate-500">
        At least one staff entry is required before submission.
      </p>
    </SectionFrame>
  );
}

function ExtraExpenses({
  expenses,
  locked,
  onAdd,
  onDelete,
}: {
  expenses: ExtraExpense[];
  locked: boolean;
  onAdd: (description: string, amount: number) => void;
  onDelete: (id: string) => void;
}) {
  const [description, setDescription] = useState("");
  const [amount, setAmount] = useState<number>(0);
  return (
    <SectionFrame title="Extra Expenses">
      <div className="space-y-2">
        {expenses.map((exp) => (
          <div
            key={exp.id}
            className="flex items-center justify-between rounded-md border border-slate-200 bg-slate-50 px-3 py-2 text-sm"
          >
            <div>
              <p className="font-semibold text-slate-800">{exp.description}</p>
              <p className="text-xs text-slate-500">
                {exp.amount.toFixed(2)} · {new Date(exp.created_at).toLocaleString()}
              </p>
            </div>
            <div className="flex items-center gap-3">
              <span className="text-sm font-semibold text-slate-800">
                {exp.amount.toFixed(2)}
              </span>
              {!locked && (
                <button
                  className="text-rose-600 hover:text-rose-800"
                  onClick={() => onDelete(exp.id)}
                  aria-label={`Delete ${exp.description}`}
                >
                  ×
                </button>
              )}
            </div>
          </div>
        ))}
      </div>
      {!locked && (
        <div className="mt-4 flex flex-wrap gap-2">
          <input
            className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm shadow-sm focus:border-slate-500 focus:outline-none md:w-2/3"
            placeholder="Description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
          <input
            className="w-40 rounded-md border border-slate-300 px-3 py-2 text-sm shadow-sm focus:border-slate-500 focus:outline-none"
            type="number"
            placeholder="Amount"
            value={amount}
            onChange={(e) => setAmount(Number(e.target.value))}
          />
          <button
            className="rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white shadow-sm disabled:opacity-50"
            disabled={!description || !amount}
            onClick={() => {
              onAdd(description, amount);
              setDescription("");
              setAmount(0);
            }}
          >
            Add expense
          </button>
        </div>
      )}
      <p className="mt-2 text-[11px] text-slate-500">
        Expenses do not change sales totals; they are kept for audit.
      </p>
    </SectionFrame>
  );
}

function CashSummary({
  cashOnHand,
  momo,
  grandTotal,
  cashDelta,
  locked,
  onChange,
}: {
  cashOnHand: number;
  momo: number;
  grandTotal: number;
  cashDelta: number;
  locked: boolean;
  onChange: (patch: Record<string, unknown>) => void;
}) {
  return (
    <SectionFrame title="Cash Breakdown">
      <div className="grid grid-cols-5 gap-3 text-sm">
        <Field
          label="Cash on Hand"
          value={cashOnHand}
          disabled={locked}
          onChange={(value) => onChange({ cash_on_hand: value })}
        />
        <Field
          label="MoMo"
          value={momo}
          disabled={locked}
          onChange={(value) => onChange({ momo_amount: value })}
        />
        <ReadOnlyField label="Grand Total (A+B)" value={grandTotal} />
        <ReadOnlyField label="Balance Delta" value={cashDelta} />
      </div>
      <p className="mt-2 text-[11px] text-slate-500">
        Warning: ideally Cash on Hand + MoMo ≈ Grand Total. Delta is computed in
        the backend as (cash_on_hand + momo_amount) - grand_total.
      </p>
    </SectionFrame>
  );
}

function Field({
  label,
  value,
  onChange,
  disabled,
}: {
  label: string;
  value: number;
  disabled?: boolean;
  onChange: (value: number) => void;
}) {
  return (
    <label className="flex flex-col gap-1 text-sm text-slate-700">
      <span className="text-xs font-semibold uppercase text-slate-600">
        {label}
      </span>
      <input
        className="rounded-md border border-slate-300 px-3 py-2 text-right text-sm shadow-sm focus:border-slate-500 focus:outline-none"
        type="number"
        disabled={disabled}
        value={value ?? 0}
        onChange={(e) => onChange(Number(e.target.value))}
      />
    </label>
  );
}

function ReadOnlyField({ label, value }: { label: string; value: number }) {
  return (
    <div className="flex flex-col gap-1 text-sm text-slate-700">
      <span className="text-xs font-semibold uppercase text-slate-600">
        {label}
      </span>
      <div className="rounded-md border border-slate-200 bg-slate-100 px-3 py-2 text-right font-semibold text-slate-800">
        {Number(value ?? 0).toFixed(2)}
      </div>
    </div>
  );
}

function headerIdOrFail(header: YoghurtHeader | null): string {
  if (!header) throw new Error("Yoghurt header missing");
  return (header.sheet_id ?? header.id)!;
}


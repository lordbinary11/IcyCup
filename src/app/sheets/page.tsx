import Link from "next/link";
import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabaseServer";

type SearchParams = {
  branch?: string;
  from?: string;
  to?: string;
};

type SheetRow = {
  id: string;
  sheet_date: string;
  locked: boolean;
  grand_total: number | null;
  branch_id: string;
  branches?: { name?: string | null; code?: string | null } | null;
};

export default async function SheetsList({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const supabase = createServerSupabaseClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    redirect("/login");
  }

  // Determine role for behavior (supervisor sees all branches, submitted only).
  const { data: profile } = await supabase
    .from("user_profiles")
    .select("*")
    .eq("user_id", session.user.id)
    .single();

  const branchFilter = searchParams.branch;
  const from = searchParams.from;
  const to = searchParams.to;

  let query = supabase
    .from("daily_sheets")
    .select(
      "id, sheet_date, locked, grand_total, branch_id, branches(name, code)"
    )
    .eq("locked", true)
    .order("sheet_date", { ascending: false })
    .limit(50);

  if (branchFilter) {
    query = query.eq("branch_id", branchFilter);
  }
  if (from) {
    query = query.gte("sheet_date", from);
  }
  if (to) {
    query = query.lte("sheet_date", to);
  }

  const { data: sheets, error } = await query;

  if (error) {
    return (
      <main className="min-h-screen bg-slate-50 text-slate-900">
        <div className="mx-auto flex max-w-5xl flex-col gap-4 px-6 py-12">
          <h1 className="text-2xl font-semibold">Sheets</h1>
          <p className="text-sm text-rose-700">{error.message}</p>
        </div>
      </main>
    );
  }

  const rows = (sheets ?? []) as SheetRow[];

  return (
    <main className="min-h-screen bg-slate-50 text-slate-900">
      <div className="mx-auto flex max-w-5xl flex-col gap-4 px-6 py-12">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-semibold">Sheets</h1>
            <p className="text-sm text-slate-600">
              Showing submitted sheets only.
            </p>
          </div>
          <Link
            href="/"
            className="rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white shadow-sm"
          >
            Back to Home
          </Link>
        </div>

        {profile?.role === "supervisor" && (
          <p className="text-xs text-slate-500">
            Supervisor view: all branches (filtered by RLS + optional query
            filters). Draft sheets are hidden until submitted.
          </p>
        )}

        <div className="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm">
          <table className="min-w-full divide-y divide-slate-200 text-sm">
            <thead className="bg-slate-50 text-xs uppercase text-slate-600">
              <tr>
                <th className="px-4 py-2 text-left">Date</th>
                <th className="px-4 py-2 text-left">Branch</th>
                <th className="px-4 py-2 text-left">Status</th>
                <th className="px-4 py-2 text-right">Grand Total</th>
                <th className="px-4 py-2 text-left">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200">
              {rows.map((sheet) => {
                const branch = sheet.branches;
                return (
                  <tr key={sheet.id}>
                    <td className="px-4 py-2">{sheet.sheet_date}</td>
                    <td className="px-4 py-2">
                      {branch?.name ?? sheet.branch_id}
                      {branch?.code ? ` (${branch.code})` : ""}
                    </td>
                    <td className="px-4 py-2">
                      {sheet.locked ? (
                        <span className="rounded-full bg-amber-100 px-2 py-1 text-xs font-semibold text-amber-800">
                          Locked
                        </span>
                      ) : (
                        <span className="rounded-full bg-emerald-100 px-2 py-1 text-xs font-semibold text-emerald-800">
                          Editable
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-2 text-right">
                      {Number(sheet.grand_total ?? 0).toFixed(2)}
                    </td>
                    <td className="px-4 py-2">
                      <Link
                        href={`/sheets/${sheet.id}`}
                        className="text-slate-900 underline"
                      >
                        Open
                      </Link>
                    </td>
                  </tr>
                );
              })}
              {!sheets?.length && (
                <tr>
                  <td
                    colSpan={5}
                    className="px-4 py-4 text-center text-slate-500"
                  >
                    No sheets found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </main>
  );
}


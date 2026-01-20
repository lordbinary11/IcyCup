import Link from "next/link";
import { createServerSupabaseClient } from "@/lib/supabaseServer";
import { OpenTodaySheetButton } from "@/app/components/OpenTodaySheetButton";

export default async function Home() {
  const supabase = createServerSupabaseClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    return (
      <main className="min-h-screen bg-slate-50 text-slate-900">
        <div className="mx-auto flex max-w-3xl flex-col gap-4 px-6 py-12">
          <h1 className="text-3xl font-semibold tracking-tight">
            Daily Sales Analysis (Digital Sheet)
          </h1>
          <p className="text-sm text-slate-600">
            Please sign in to access your branch sheet or supervisor view.
          </p>
          <Link
            className="inline-flex w-fit rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white shadow-sm"
            href="/login"
          >
            Go to login
          </Link>
        </div>
      </main>
    );
  }

  // Fetch current user profile to determine role/branch.
  const { data: profile, error: profileError } = await supabase
    .from("user_profiles")
    .select("*")
    .eq("user_id", session.user.id)
    .single() as { data: { role: "branch_user" | "supervisor"; branch_id: string | null } | null; error: unknown };

  if (profileError || !profile) {
    return (
      <main className="min-h-screen bg-slate-50 text-slate-900">
        <div className="mx-auto flex max-w-3xl flex-col gap-4 px-6 py-12">
          <h1 className="text-3xl font-semibold tracking-tight">
            Profile not found
          </h1>
          <p className="text-sm text-rose-700">
            Ensure this user has a user_profiles row with role and branch.
          </p>
          <Link
            className="inline-flex w-fit rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white shadow-sm"
            href="/login"
          >
            Back to login
          </Link>
        </div>
      </main>
    );
  }

  type SheetRow = { id: string; sheet_date: string; locked: boolean; grand_total: number | null };

  if (profile.role === "branch_user" && profile.branch_id) {
    // Branch dashboard: show submitted sheets + a button to create/open today's sheet.
    const { data: sheets, error: sheetsError } = await supabase
      .from("daily_sheets")
      .select("id, sheet_date, locked, grand_total")
      .eq("branch_id", profile.branch_id)
      .eq("locked", true)
      .order("sheet_date", { ascending: false })
      .limit(30) as { data: SheetRow[] | null; error: { message: string } | null };

    return (
      <main className="min-h-screen bg-slate-50 text-slate-900">
        <div className="mx-auto flex max-w-5xl flex-col gap-6 px-6 py-12">
          <div className="flex items-start justify-between gap-4">
            <div>
              <h1 className="text-2xl font-semibold">Branch Dashboard</h1>
              <p className="mt-1 text-sm text-slate-600">
                You can view your submitted sheets and create/open today’s sheet.
              </p>
            </div>
            <div className="flex items-center gap-2">
              <Link
                className="rounded-md border border-slate-300 bg-white px-4 py-2 text-sm font-semibold text-slate-800 shadow-sm"
                href="/login"
              >
                Switch account
              </Link>
              <Link
                className="rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white shadow-sm"
                href="/sheets"
              >
                View submitted sheets
              </Link>
            </div>
          </div>

          <div className="rounded-lg border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-700">
              Today
            </h2>
            <p className="mt-1 text-sm text-slate-600">
              Only one sheet per day. Create/open today’s sheet to enter and then
              submit it.
            </p>
            <div className="mt-4">
              <OpenTodaySheetButton branchId={profile.branch_id} />
            </div>
          </div>

          <div className="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm">
            <div className="border-b border-slate-200 bg-slate-50 px-4 py-3">
              <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-700">
                Submitted sheets
              </h2>
              <p className="mt-1 text-xs text-slate-500">
                Supervisors can only see sheets after you submit (lock) them.
              </p>
            </div>

            {sheetsError ? (
              <div className="p-4 text-sm text-rose-700">{sheetsError.message}</div>
            ) : (
              <table className="min-w-full divide-y divide-slate-200 text-sm">
                <thead className="bg-white text-xs uppercase text-slate-600">
                  <tr>
                    <th className="px-4 py-2 text-left">Date</th>
                    <th className="px-4 py-2 text-left">Status</th>
                    <th className="px-4 py-2 text-right">Grand Total</th>
                    <th className="px-4 py-2 text-left">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-200">
                  {(sheets ?? []).map((s) => (
                    <tr key={s.id}>
                      <td className="px-4 py-2">{s.sheet_date}</td>
                      <td className="px-4 py-2">
                        {s.locked ? (
                          <span className="rounded-full bg-amber-100 px-2 py-1 text-xs font-semibold text-amber-800">
                            Submitted
                          </span>
                        ) : (
                          <span className="rounded-full bg-slate-100 px-2 py-1 text-xs font-semibold text-slate-700">
                            Draft
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-2 text-right">
                        {Number(s.grand_total ?? 0).toFixed(2)}
                      </td>
                      <td className="px-4 py-2">
                        <Link
                          href={`/sheets/${s.id}`}
                          className="text-slate-900 underline"
                        >
                          Open
                        </Link>
                      </td>
                    </tr>
                  ))}
                  {!sheets?.length && (
                    <tr>
                      <td colSpan={4} className="px-4 py-4 text-center text-slate-500">
                        No submitted sheets yet.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            )}
          </div>
        </div>
      </main>
    );
  }

  // Supervisors go to the sheets list.
  return (
    <main className="min-h-screen bg-slate-50 text-slate-900">
      <div className="mx-auto flex max-w-3xl flex-col gap-4 px-6 py-12">
        <h1 className="text-2xl font-semibold">Supervisor</h1>
        <p className="text-sm text-slate-600">
          View all submitted sheets across branches.
        </p>
        <Link
          className="inline-flex w-fit rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white shadow-sm"
          href="/sheets"
        >
          Go to submitted sheets
        </Link>
      </div>
    </main>
  );
}

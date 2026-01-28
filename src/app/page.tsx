import Link from "next/link";
import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabaseServer";
import { OpenTodaySheetButton } from "@/app/components/OpenTodaySheetButton";
import { BranchSelector } from "@/app/components/BranchSelector";

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
    .single() as { data: { role: "branch_user" | "supervisor" | "field_supervisor" | "admin"; branch_id: string | null } | null; error: unknown };

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
    // Branch dashboard: show all submitted sheets (regardless of locked status)
    const { data: sheets, error: sheetsError } = await supabase
      .from("daily_sheets")
      .select("id, sheet_date, locked, grand_total")
      .eq("branch_id", profile.branch_id)
      .order("sheet_date", { ascending: false })
      .limit(30) as { data: SheetRow[] | null; error: { message: string } | null };

    return (
      <main className="min-h-screen bg-white text-slate-900">
        <div className="border-b-2 border-slate-900 bg-white">
          <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
            <div>
              <h1 className="text-2xl font-bold text-slate-900">IcyCup</h1>
              <p className="text-xs text-slate-600">Branch Dashboard</p>
            </div>
            <div className="flex items-center gap-3">
              <Link
                className="rounded-md border-2 border-slate-900 bg-white px-4 py-2 text-sm font-semibold text-slate-900 hover:bg-slate-50 transition-colors"
                href="/sheets"
              >
                All Sheets
              </Link>
              <Link
                className="rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white hover:bg-slate-800 transition-colors"
                href="/login"
              >
                Sign Out
              </Link>
            </div>
          </div>
        </div>
        <div className="mx-auto max-w-6xl px-6 py-8">
          <div className="mb-8">
            <h2 className="text-xl font-semibold text-slate-900">Welcome Back</h2>
            <p className="mt-1 text-sm text-slate-600">
              Manage your daily sales sheets and track performance
            </p>
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
                Supervisors can view all your sheets but can only edit them from the next day onwards.
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
                        {(() => {
                          const sheetDate = new Date(s.sheet_date).toISOString().split('T')[0];
                          const today = new Date().toISOString().split('T')[0];
                          const isPastDay = sheetDate < today;
                          
                          if (isPastDay) {
                            return (
                              <span className="rounded-full bg-emerald-100 px-2 py-1 text-xs font-semibold text-emerald-800">
                                Submitted
                              </span>
                            );
                          }
                          return (
                            <span className="rounded-full bg-slate-100 px-2 py-1 text-xs font-semibold text-slate-700">
                              Draft
                            </span>
                          );
                        })()}
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

  // Field supervisors - show branch selector and all sheets
  if (profile.role === "field_supervisor") {
    const { data: branches } = await supabase
      .from("branches")
      .select("id, name, code")
      .order("name", { ascending: true });

    const { data: sheets } = await supabase
      .from("daily_sheets")
      .select("id, sheet_date, locked, grand_total, branches(name)")
      .order("sheet_date", { ascending: false })
      .limit(50) as { data: any[] | null; error: any };

    return (
      <main className="min-h-screen bg-white text-slate-900">
        <div className="border-b-2 border-slate-900 bg-white">
          <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
            <div>
              <h1 className="text-2xl font-bold text-slate-900">IcyCup</h1>
              <p className="text-xs text-slate-600">Field Supervisor Dashboard</p>
            </div>
            <div className="flex items-center gap-3">
              <Link
                className="rounded-md border-2 border-slate-900 bg-white px-4 py-2 text-sm font-semibold text-slate-900 hover:bg-slate-50 transition-colors"
                href="/sheets"
              >
                All Sheets
              </Link>
              <Link
                className="rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white hover:bg-slate-800 transition-colors"
                href="/login"
              >
                Sign Out
              </Link>
            </div>
          </div>
        </div>
        <div className="mx-auto max-w-6xl px-6 py-8">
          <div className="mb-8">
            <h2 className="text-xl font-semibold text-slate-900">Select Branch to Record Sheet</h2>
            <p className="mt-1 text-sm text-slate-600">
              Choose a branch to create or view today's sheet
            </p>
          </div>
          <BranchSelector branches={branches || []} />
          <div className="mb-8">
            <h2 className="text-xl font-semibold text-slate-900">Recent Sheets</h2>
            <p className="mt-1 text-sm text-slate-600">
              View all submitted sheets across branches
            </p>
          </div>
          <div className="overflow-hidden rounded-lg border-2 border-slate-900">
            <table className="min-w-full divide-y divide-slate-200 text-sm">
              <thead className="bg-white text-xs uppercase text-slate-600">
                <tr>
                  <th className="px-4 py-2 text-left">Date</th>
                  <th className="px-4 py-2 text-left">Branch</th>
                  <th className="px-4 py-2 text-left">Status</th>
                  <th className="px-4 py-2 text-right">Grand Total</th>
                  <th className="px-4 py-2 text-left">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200">
                {(sheets ?? []).map((s) => (
                  <tr key={s.id}>
                    <td className="px-4 py-2">{s.sheet_date}</td>
                    <td className="px-4 py-2">{s.branches?.name || 'N/A'}</td>
                    <td className="px-4 py-2">
                      {(() => {
                        const sheetDate = new Date(s.sheet_date).toISOString().split('T')[0];
                        const today = new Date().toISOString().split('T')[0];
                        const isPastDay = sheetDate < today;
                        
                        if (isPastDay) {
                          return (
                            <span className="rounded-full bg-emerald-100 px-2 py-1 text-xs font-semibold text-emerald-800">
                              Submitted
                            </span>
                          );
                        }
                        return (
                          <span className="rounded-full bg-slate-100 px-2 py-1 text-xs font-semibold text-slate-700">
                            Draft
                          </span>
                        );
                      })()}
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
                    <td colSpan={5} className="px-4 py-4 text-center text-slate-500">
                      No sheets yet.
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

  // Supervisors and admins - redirect to admin dashboard
  redirect("/admin");
}

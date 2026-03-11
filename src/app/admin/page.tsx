import Link from "next/link";
import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabaseServer";
import { FieldSupervisorSheetCreator } from "@/app/components/FieldSupervisorSheetCreator";

export default async function AdminPage() {
  const supabase = createServerSupabaseClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    redirect("/login");
  }

  const { data: profile } = await supabase
    .from("user_profiles")
    .select("*")
    .eq("user_id", session.user.id)
    .single();

  if (!profile || (profile.role !== "supervisor" && profile.role !== "admin")) {
    redirect("/");
  }

  type Branch = {
    id: string;
    name: string;
    code: string;
    supervisor_id: string | null;
  };

  type User = {
    user_id: string;
    role: string;
    branch_id: string | null;
    first_name: string | null;
    last_name: string | null;
    branches: { name: string; code: string } | null;
  };

  // Fetch all branches
  const { data: branches } = await supabase
    .from("branches")
    .select("*")
    .order("name", { ascending: true }) as { data: Branch[] | null };

  // Fetch all users
  const { data: users } = await supabase
    .from("user_profiles")
    .select("*, branches(name, code)")
    .order("first_name", { ascending: true }) as { data: User[] | null };

  return (
    <main className="min-h-screen bg-white text-slate-900">
      <div className="border-b-2 border-slate-900 bg-white">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-4">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">IcyCup</h1>
            <p className="text-xs text-slate-600">Supervisor Dashboard</p>
          </div>
          <div className="flex items-center gap-3">
            <Link
              className="rounded-md border-2 border-slate-900 bg-white px-4 py-2 text-sm font-semibold text-slate-900 hover:bg-slate-50 transition-colors"
              href="/admin/items"
            >
              Items
            </Link>
            <Link
              className="rounded-md border-2 border-slate-900 bg-white px-4 py-2 text-sm font-semibold text-slate-900 hover:bg-slate-50 transition-colors"
              href="/sheets"
            >
              All Sheets
            </Link>
            <Link
              className="rounded-md border-2 border-slate-900 bg-white px-4 py-2 text-sm font-semibold text-slate-900 hover:bg-slate-50 transition-colors"
              href="/"
            >
              Dashboard
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

      <div className="mx-auto max-w-7xl px-6 py-8">
        {/* Sheet Creation Section for Supervisors */}
        {profile.role === "supervisor" && (
          <div className="mb-8">
            <div className="mb-4">
              <h2 className="text-2xl font-bold text-slate-900">Sheet Recording</h2>
              <p className="mt-1 text-sm text-slate-600">
                Create new sheets for any branch with date selection
              </p>
            </div>
            <FieldSupervisorSheetCreator />
          </div>
        )}

        <div className="mb-8">
          <h2 className="text-2xl font-bold text-slate-900">Management</h2>
          <p className="mt-1 text-sm text-slate-600">
            Manage branches and users
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Branches Section */}
          <div className="border-2 border-slate-900 rounded-lg p-6">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-semibold text-slate-900">Branches</h3>
              <Link
                href="/admin/branches/new"
                className="rounded-md bg-slate-900 px-4 py-2 text-xs font-semibold text-white hover:bg-slate-800 transition-colors"
              >
                + New Branch
              </Link>
            </div>
            <div className="space-y-2">
              {branches && branches.length > 0 ? (
                branches.map((branch) => (
                  <div
                    key={branch.id}
                    className="flex items-center justify-between border border-slate-200 rounded-md p-3 hover:bg-slate-50 transition-colors"
                  >
                    <div>
                      <p className="font-medium text-slate-900">{branch.name}</p>
                      <p className="text-xs text-slate-600">Code: {branch.code}</p>
                    </div>
                    <Link
                      href={`/admin/branches/${branch.id}`}
                      className="text-xs text-slate-900 underline hover:no-underline"
                    >
                      Edit
                    </Link>
                  </div>
                ))
              ) : (
                <p className="text-sm text-slate-500 text-center py-8">
                  No branches found
                </p>
              )}
            </div>
          </div>

          {/* Users Section */}
          <div className="border-2 border-slate-900 rounded-lg p-6">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-semibold text-slate-900">Users</h3>
              <Link
                href="/admin/users/new"
                className="rounded-md bg-slate-900 px-4 py-2 text-xs font-semibold text-white hover:bg-slate-800 transition-colors"
              >
                + New User
              </Link>
            </div>
            <div className="space-y-2 max-h-96 overflow-y-auto">
              {users && users.length > 0 ? (
                users.map((user) => (
                  <div
                    key={user.user_id}
                    className="flex items-center justify-between border border-slate-200 rounded-md p-3 hover:bg-slate-50 transition-colors"
                  >
                    <div>
                      <p className="font-medium text-slate-900 text-sm">
                        {user.first_name && user.last_name 
                          ? `${user.first_name} ${user.last_name}`
                          : "No name set"}
                      </p>
                      <p className="text-xs text-slate-600">
                        {user.role === "supervisor" ? "Supervisor (Admin)" : 
                         user.role === "field_supervisor" ? "Field Supervisor" : 
                         user.role === "admin" ? "Admin" : "Branch User"}
                        {user.branches?.name && ` • ${user.branches.name}`}
                      </p>
                    </div>
                    <Link
                      href={`/admin/users/${user.user_id}`}
                      className="text-xs text-slate-900 underline hover:no-underline"
                    >
                      Edit
                    </Link>
                  </div>
                ))
              ) : (
                <p className="text-sm text-slate-500 text-center py-8">
                  No users found
                </p>
              )}
            </div>
          </div>
        </div>
      </div>
    </main>
  );
}

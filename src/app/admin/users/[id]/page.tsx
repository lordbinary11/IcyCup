"use client";

import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { createBrowserSupabaseClient } from "@/lib/supabaseBrowser";
import Link from "next/link";

type UserRole = "branch_user" | "supervisor" | "field_supervisor" | "admin";

export default function EditUserPage() {
  const router = useRouter();
  const params = useParams();
  const userId = params.id as string;
  const supabase = createBrowserSupabaseClient();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [role, setRole] = useState<UserRole>("branch_user");
  const [branchId, setBranchId] = useState<string>("");
  const [branches, setBranches] = useState<Array<{ id: string; name: string; code: string }>>([]);

  useEffect(() => {
    async function loadData() {
      try {
        // Fetch user data
        const { data: user, error: userError } = await supabase
          .from("user_profiles")
          .select("*")
          .eq("user_id", userId)
          .single();

        if (userError) throw userError;

        setFirstName(user.first_name || "");
        setLastName(user.last_name || "");
        setRole(user.role);
        setBranchId(user.branch_id || "");

        // Fetch branches
        const { data: branchesList, error: branchesError } = await supabase
          .from("branches")
          .select("id, name, code")
          .order("name", { ascending: true });

        if (branchesError) throw branchesError;

        setBranches(branchesList || []);
      } catch (err: any) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    }

    loadData();
  }, [userId, supabase]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setSuccess(false);

    try {
      // Validate branch assignment based on role
      if (role === "branch_user" && !branchId) {
        throw new Error("Branch users must be assigned to a branch");
      }

      const { error: updateError } = await supabase
        .from("user_profiles")
        .update({
          first_name: firstName,
          last_name: lastName,
          role,
          branch_id: role === "branch_user" ? branchId : null,
        })
        .eq("user_id", userId);

      if (updateError) throw updateError;

      setSuccess(true);
      setTimeout(() => {
        router.push("/admin");
      }, 1500);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-lg">Loading user...</div>
      </div>
    );
  }

  return (
    <main className="min-h-screen bg-slate-50 p-6">
      <div className="mx-auto max-w-2xl">
        <div className="mb-6">
          <Link
            href="/admin"
            className="text-sm text-slate-900 underline hover:no-underline"
          >
            ← Back to Admin
          </Link>
        </div>

        <div className="bg-white border-2 border-slate-900 rounded-lg p-8 shadow-lg">
          <h1 className="text-2xl font-bold text-slate-900 mb-6">Edit User</h1>

          {error && (
            <div className="mb-4 rounded-md border-2 border-rose-300 bg-rose-50 px-4 py-3 text-sm text-rose-700">
              {error}
            </div>
          )}

          {success && (
            <div className="mb-4 rounded-md border-2 border-emerald-300 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
              User updated successfully! Redirecting...
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-slate-900 mb-2">
                First Name
              </label>
              <input
                type="text"
                required
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                className="w-full rounded-md border-2 border-slate-300 bg-white px-4 py-3 text-sm text-slate-900 placeholder:text-slate-400 focus:border-slate-900 focus:outline-none transition-colors"
                placeholder="John"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-900 mb-2">
                Last Name
              </label>
              <input
                type="text"
                required
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                className="w-full rounded-md border-2 border-slate-300 bg-white px-4 py-3 text-sm text-slate-900 placeholder:text-slate-400 focus:border-slate-900 focus:outline-none transition-colors"
                placeholder="Doe"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-900 mb-2">
                Role
              </label>
              <select
                value={role}
                onChange={(e) => setRole(e.target.value as UserRole)}
                className="w-full rounded-md border-2 border-slate-300 bg-white px-4 py-3 text-sm text-slate-900 focus:border-slate-900 focus:outline-none transition-colors"
              >
                <option value="branch_user">Branch User</option>
                <option value="field_supervisor">Field Supervisor</option>
                <option value="supervisor">Supervisor (Admin)</option>
                <option value="admin">Admin</option>
              </select>
            </div>

            {role === "branch_user" && (
              <div>
                <label className="block text-sm font-medium text-slate-900 mb-2">
                  Assigned Branch
                </label>
                <select
                  value={branchId}
                  onChange={(e) => setBranchId(e.target.value)}
                  required
                  className="w-full rounded-md border-2 border-slate-300 bg-white px-4 py-3 text-sm text-slate-900 focus:border-slate-900 focus:outline-none transition-colors"
                >
                  <option value="">Select a branch</option>
                  {branches.map((branch) => (
                    <option key={branch.id} value={branch.id}>
                      {branch.name} ({branch.code})
                    </option>
                  ))}
                </select>
              </div>
            )}

            {role !== "branch_user" && (
              <div className="rounded-md bg-slate-100 p-4 text-sm text-slate-700">
                <p className="font-medium mb-1">Role Information:</p>
                <ul className="list-disc list-inside space-y-1 text-xs">
                  {role === "field_supervisor" && (
                    <>
                      <li>Can create and edit sheets for any branch</li>
                      <li>Cannot access items or management features</li>
                      <li>No branch assignment required</li>
                    </>
                  )}
                  {role === "supervisor" && (
                    <>
                      <li>Full admin access to all features</li>
                      <li>Can manage branches, users, and items</li>
                      <li>Can view and edit all sheets</li>
                    </>
                  )}
                  {role === "admin" && (
                    <>
                      <li>Full system administrator access</li>
                      <li>Can manage all aspects of the system</li>
                    </>
                  )}
                </ul>
              </div>
            )}

            <div className="flex gap-3 pt-4">
              <button
                type="submit"
                disabled={saving}
                className="flex-1 rounded-md bg-slate-900 px-4 py-3 text-sm font-semibold text-white hover:bg-slate-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {saving ? "Saving..." : "Save Changes"}
              </button>
              <Link
                href="/admin"
                className="flex-1 rounded-md border-2 border-slate-300 bg-white px-4 py-3 text-sm font-semibold text-slate-900 hover:bg-slate-50 transition-colors text-center"
              >
                Cancel
              </Link>
            </div>
          </form>
        </div>
      </div>
    </main>
  );
}

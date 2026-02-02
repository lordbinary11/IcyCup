"use client";

import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { createBrowserSupabaseClient } from "@/lib/supabaseBrowser";
import Link from "next/link";

export default function EditBranchPage() {
  const router = useRouter();
  const params = useParams();
  const branchId = params.id as string;
  const supabase = createBrowserSupabaseClient();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const [name, setName] = useState("");
  const [code, setCode] = useState("");
  const [supervisorId, setSupervisorId] = useState<string>("");
  const [supervisors, setSupervisors] = useState<Array<{ user_id: string; first_name: string; last_name: string; email: string }>>([]);

  useEffect(() => {
    async function loadData() {
      try {
        // Fetch branch data
        const { data: branchData, error: branchError } = await supabase
          .from("branches")
          .select("*, supervisor:user_profiles(user_id, first_name, last_name)")
          .eq("id", params.id)
          .single();

        if (branchError || !branchData) {
          throw new Error("Failed to fetch branch data");
        }

        const branch = branchData as { name: string; code: string; supervisor_id: string | null; supervisor: { user_id: string; first_name: string; last_name: string } | null };

        setName(branch.name);
        setCode(branch.code);
        setSupervisorId(branch.supervisor_id || "");

        // Fetch supervisors
        const { data: supervisorsList, error: supervisorsError } = await supabase
          .from("user_profiles")
          .select("user_id, first_name, last_name, email")
          .eq("role", "supervisor")
          .order("first_name", { ascending: true });

        if (supervisorsError) {
          throw supervisorsError;
        }

        setSupervisors(supervisorsList || []);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load branch');
      } finally {
        setLoading(false);
      }
    }

    loadData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [branchId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setSuccess(false);

    try {
      const { error: updateError } = await supabase
        .from("branches")
        .update({
          name,
          code,
          supervisor_id: supervisorId || null,
        })
        .eq("id", branchId);

      if (updateError) throw updateError;

      setSuccess(true);
      setTimeout(() => {
        router.push("/admin");
      }, 1500);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update branch');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-lg">Loading branch...</div>
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
          <h1 className="text-2xl font-bold text-slate-900 mb-6">Edit Branch</h1>

          {error && (
            <div className="mb-4 rounded-md border-2 border-rose-300 bg-rose-50 px-4 py-3 text-sm text-rose-700">
              {error}
            </div>
          )}

          {success && (
            <div className="mb-4 rounded-md border-2 border-emerald-300 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
              Branch updated successfully! Redirecting...
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-slate-900 mb-2">
                Branch Name
              </label>
              <input
                type="text"
                required
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full rounded-md border-2 border-slate-300 bg-white px-4 py-3 text-sm text-slate-900 placeholder:text-slate-400 focus:border-slate-900 focus:outline-none transition-colors"
                placeholder="e.g., Main Campus"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-900 mb-2">
                Branch Code
              </label>
              <input
                type="text"
                required
                value={code}
                onChange={(e) => setCode(e.target.value)}
                className="w-full rounded-md border-2 border-slate-300 bg-white px-4 py-3 text-sm text-slate-900 placeholder:text-slate-400 focus:border-slate-900 focus:outline-none transition-colors"
                placeholder="e.g., MC"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-900 mb-2">
                Assigned Supervisor (Optional)
              </label>
              <select
                value={supervisorId}
                onChange={(e) => setSupervisorId(e.target.value)}
                className="w-full rounded-md border-2 border-slate-300 bg-white px-4 py-3 text-sm text-slate-900 focus:border-slate-900 focus:outline-none transition-colors"
              >
                <option value="">No supervisor assigned</option>
                {supervisors.map((sup) => (
                  <option key={sup.user_id} value={sup.user_id}>
                    {sup.first_name} {sup.last_name}
                  </option>
                ))}
              </select>
            </div>

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

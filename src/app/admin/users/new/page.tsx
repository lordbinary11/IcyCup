"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createBrowserSupabaseClient } from "@/lib/supabaseBrowser";

type Branch = {
  id: string;
  name: string;
  code: string;
};

export default function NewUserPage() {
  const router = useRouter();
  const supabase = createBrowserSupabaseClient();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [role, setRole] = useState<"branch_user" | "supervisor" | "field_supervisor">("branch_user");
  const [branchId, setBranchId] = useState("");
  const [branches, setBranches] = useState<Branch[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchBranches = async () => {
      const { data } = await supabase
        .from("branches")
        .select("id, name, code")
        .order("name", { ascending: true });
      if (data) setBranches(data);
    };
    void fetchBranches();
  }, [supabase]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      // Create auth user with auto-confirm
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: undefined,
          data: {
            email_confirm: true,
          },
        },
      });

      if (authError) throw authError;
      if (!authData.user) throw new Error("User creation failed");

      // Wait a bit for the auth user to be fully created
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Create user profile
      const { error: profileError } = await supabase
        .from("user_profiles")
        .insert({
          user_id: authData.user.id,
          role,
          branch_id: role === "branch_user" ? branchId : null,
          first_name: firstName,
          last_name: lastName,
        });

      if (profileError) {
        console.error("Profile creation error:", profileError);
        throw profileError;
      }

      router.push("/admin");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to create user");
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="min-h-screen bg-white text-slate-900">
      <div className="border-b-2 border-slate-900 bg-white">
        <div className="mx-auto flex max-w-4xl items-center justify-between px-6 py-4">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">IcyCup</h1>
            <p className="text-xs text-slate-600">Create New User</p>
          </div>
          <Link
            href="/admin"
            className="rounded-md border-2 border-slate-900 bg-white px-4 py-2 text-sm font-semibold text-slate-900 hover:bg-slate-50 transition-colors"
          >
            Back
          </Link>
        </div>
      </div>

      <div className="mx-auto max-w-2xl px-6 py-8">
        <div className="border-2 border-slate-900 rounded-lg p-8">
          <h2 className="text-xl font-semibold text-slate-900 mb-6">
            User Information
          </h2>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-slate-900 mb-2">
                  First Name
                </label>
                <input
                  type="text"
                  value={firstName}
                  onChange={(e) => setFirstName(e.target.value)}
                  className="w-full rounded-md border-2 border-slate-300 px-4 py-3 text-sm focus:border-slate-900 focus:outline-none transition-colors"
                  placeholder="John"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-900 mb-2">
                  Last Name
                </label>
                <input
                  type="text"
                  value={lastName}
                  onChange={(e) => setLastName(e.target.value)}
                  className="w-full rounded-md border-2 border-slate-300 px-4 py-3 text-sm focus:border-slate-900 focus:outline-none transition-colors"
                  placeholder="Doe"
                  required
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-900 mb-2">
                Email Address
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full rounded-md border-2 border-slate-300 px-4 py-3 text-sm focus:border-slate-900 focus:outline-none transition-colors"
                placeholder="user@example.com"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-900 mb-2">
                Password
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full rounded-md border-2 border-slate-300 px-4 py-3 text-sm focus:border-slate-900 focus:outline-none transition-colors"
                placeholder="Minimum 6 characters"
                required
                minLength={6}
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-900 mb-2">
                Role
              </label>
              <select
                value={role}
                onChange={(e) => setRole(e.target.value as "branch_user" | "supervisor" | "field_supervisor")}
                className="w-full rounded-md border-2 border-slate-300 px-4 py-3 text-sm focus:border-slate-900 focus:outline-none transition-colors"
              >
                <option value="branch_user">Branch User</option>
                <option value="field_supervisor">Field Supervisor</option>
                <option value="supervisor">Supervisor (Admin)</option>
              </select>
            </div>

            {role === "branch_user" && (
              <div>
                <label className="block text-sm font-medium text-slate-900 mb-2">
                  Assign Branch
                </label>
                <select
                  value={branchId}
                  onChange={(e) => setBranchId(e.target.value)}
                  className="w-full rounded-md border-2 border-slate-300 px-4 py-3 text-sm focus:border-slate-900 focus:outline-none transition-colors"
                  required
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

            {error && (
              <div className="rounded-md border-2 border-rose-300 bg-rose-50 px-4 py-3 text-sm text-rose-700">
                {error}
              </div>
            )}

            <div className="flex gap-3">
              <button
                type="submit"
                disabled={loading || !email || !password || !firstName || !lastName || (role === "branch_user" && !branchId)}
                className="flex-1 rounded-md bg-slate-900 px-4 py-3 text-sm font-semibold text-white hover:bg-slate-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? "Creating..." : "Create User"}
              </button>
              <Link
                href="/admin"
                className="rounded-md border-2 border-slate-900 bg-white px-4 py-3 text-sm font-semibold text-slate-900 hover:bg-slate-50 transition-colors"
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

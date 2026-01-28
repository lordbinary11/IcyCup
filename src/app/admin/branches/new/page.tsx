"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createBrowserSupabaseClient } from "@/lib/supabaseBrowser";

export default function NewBranchPage() {
  const router = useRouter();
  const supabase = createBrowserSupabaseClient();
  const [name, setName] = useState("");
  const [code, setCode] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const { error: insertError } = await supabase
        .from("branches")
        .insert({
          name,
          code,
        });

      if (insertError) throw insertError;

      router.push("/admin");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to create branch");
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
            <p className="text-xs text-slate-600">Create New Branch</p>
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
            Branch Information
          </h2>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div>
              <label className="block text-sm font-medium text-slate-900 mb-2">
                Branch Name
              </label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full rounded-md border-2 border-slate-300 px-4 py-3 text-sm focus:border-slate-900 focus:outline-none transition-colors"
                placeholder="e.g., Main Branch"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-900 mb-2">
                Branch Code
              </label>
              <input
                type="text"
                value={code}
                onChange={(e) => setCode(e.target.value.toUpperCase())}
                className="w-full rounded-md border-2 border-slate-300 px-4 py-3 text-sm focus:border-slate-900 focus:outline-none transition-colors"
                placeholder="e.g., MB001"
                required
              />
              <p className="mt-1 text-xs text-slate-500">
                A unique identifier for this branch
              </p>
            </div>

            {error && (
              <div className="rounded-md border-2 border-rose-300 bg-rose-50 px-4 py-3 text-sm text-rose-700">
                {error}
              </div>
            )}

            <div className="flex gap-3">
              <button
                type="submit"
                disabled={loading || !name || !code}
                className="flex-1 rounded-md bg-slate-900 px-4 py-3 text-sm font-semibold text-white hover:bg-slate-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? "Creating..." : "Create Branch"}
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

"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { createBrowserSupabaseClient } from "@/lib/supabaseBrowser";

export function FieldSupervisorSheetCreator() {
  const router = useRouter();
  const supabase = createBrowserSupabaseClient();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedBranchId, setSelectedBranchId] = useState<string>("");
  const [selectedDate, setSelectedDate] = useState<string>(
    new Date().toISOString().split('T')[0]
  );
  const [branches, setBranches] = useState<Array<{ id: string; name: string; code: string }>>([]);

  // Fetch branches on component mount
  useEffect(() => {
    const fetchBranches = async () => {
      const { data, error } = await supabase
        .from("branches")
        .select("id, name, code")
        .order("name");
      
      if (error) {
        console.error("Error fetching branches:", error);
      } else {
        setBranches(data || []);
      }
    };
    
    fetchBranches();
  }, [supabase]);

  const handleCreateSheet = async () => {
    if (!selectedBranchId) {
      setError("Please select a branch");
      return;
    }

    if (!selectedDate) {
      setError("Please select a date");
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const { data, error: rpcError } = await supabase.rpc(
        "get_or_create_sheet_for_date",
        { 
          p_branch_id: selectedBranchId,
          p_sheet_date: selectedDate
        }
      );
      
      if (rpcError || !data) {
        setError(rpcError?.message ?? "Could not create sheet");
        setLoading(false);
        return;
      }

      // Ensure yoghurt header exists before navigating
      await supabase
        .from("yoghurt_headers")
        .upsert({
          sheet_id: data,
          opening_stock: 0,
          stock_received: 0,
          total_stock: 0,
          closing_stock: 0,
        }, { onConflict: 'sheet_id' });

      setLoading(false);
      router.push(`/sheets/${data}`);
    } catch {
      setError("An unexpected error occurred");
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col items-start gap-4 border-2 border-slate-900 rounded-lg p-6 hover:bg-slate-50 transition-colors max-w-md">
      <h3 className="text-lg font-semibold text-slate-900">Create New Sheet</h3>
      
      <div className="w-full space-y-4">
        <div>
          <label htmlFor="branch" className="block text-sm font-medium text-slate-700 mb-1">
            Select Branch
          </label>
          <select
            id="branch"
            value={selectedBranchId}
            onChange={(e) => setSelectedBranchId(e.target.value)}
            className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-slate-900 focus:border-transparent"
            disabled={loading}
          >
            <option value="">Choose a branch...</option>
            {branches.map((branch) => (
              <option key={branch.id} value={branch.id}>
                {branch.name} {branch.code && `(${branch.code})`}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label htmlFor="date" className="block text-sm font-medium text-slate-700 mb-1">
            Sheet Date
          </label>
          <input
            id="date"
            type="date"
            value={selectedDate}
            onChange={(e) => setSelectedDate(e.target.value)}
            max={new Date().toISOString().split('T')[0]} // Prevent future dates
            className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-slate-900 focus:border-transparent"
            disabled={loading}
          />
          <p className="text-xs text-slate-500 mt-1">
            Back dating is allowed. Select the date for this sheet.
          </p>
        </div>

        <button
          className="w-full rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white shadow-sm disabled:opacity-50 hover:bg-slate-800 transition-colors"
          disabled={loading || !selectedBranchId || !selectedDate}
          onClick={handleCreateSheet}
        >
          {loading ? "Creating..." : "Create Sheet"}
        </button>
      </div>

      {error && (
        <p className="rounded-md border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700 w-full">
          {error}
        </p>
      )}

      <div className="text-xs text-slate-500 space-y-1">
        <p>• Field supervisor can create sheets for any branch</p>
        <p>• Back dating is allowed</p>
        <p>• Duplicate sheets for same branch/date are prevented</p>
        <p>• All sheets remain editable</p>
      </div>
    </div>
  );
}

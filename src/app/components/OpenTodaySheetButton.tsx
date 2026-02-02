"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createBrowserSupabaseClient } from "@/lib/supabaseBrowser";

export function OpenTodaySheetButton({
  branchId,
  branchName,
}: {
  branchId: string | null;
  branchName?: string;
}) {
  const router = useRouter();
  const supabase = createBrowserSupabaseClient();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  return (
    <div className="flex flex-col items-start gap-2 border-2 border-slate-900 rounded-lg p-4 hover:bg-slate-50 transition-colors">
      {branchName && (
        <h3 className="text-lg font-semibold text-slate-900 mb-2">{branchName}</h3>
      )}
      <button
        className="w-full rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white shadow-sm disabled:opacity-50 hover:bg-slate-800 transition-colors"
        disabled={loading || !branchId}
        onClick={async () => {
          if (!branchId) return;
          setLoading(true);
          setError(null);
          const { data, error: rpcError } = await supabase.rpc(
            "get_or_create_today_sheet",
            { p_branch_id: branchId }
          );
          
          if (rpcError || !data) {
            setLoading(false);
            setError(rpcError?.message ?? "Could not create/open today's sheet");
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
        }}
      >
        {loading ? "Opening..." : "Open Today's Sheet"}
      </button>
      {error && (
        <p className="rounded-md border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700">
          {error}
        </p>
      )}
      {!branchId && (
        <p className="text-xs text-rose-700">
          Branch ID missing on your profile.
        </p>
      )}
    </div>
  );
}


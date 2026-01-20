"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createBrowserSupabaseClient } from "@/lib/supabaseBrowser";

export function OpenTodaySheetButton({
  branchId,
}: {
  branchId: string | null;
}) {
  const router = useRouter();
  const supabase = createBrowserSupabaseClient();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  return (
    <div className="flex flex-col items-start gap-2">
      <button
        className="rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white shadow-sm disabled:opacity-50"
        disabled={loading || !branchId}
        onClick={async () => {
          if (!branchId) return;
          setLoading(true);
          setError(null);
          const { data, error: rpcError } = await supabase.rpc(
            "get_or_create_today_sheet",
            { p_branch_id: branchId }
          );
          setLoading(false);
          if (rpcError || !data) {
            setError(rpcError?.message ?? "Could not create/open today’s sheet");
            return;
          }
          router.push(`/sheets/${data}`);
        }}
      >
        {loading ? "Opening..." : "Create / Open today’s sheet"}
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


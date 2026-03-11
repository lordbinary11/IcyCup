"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { Suspense } from "react";

interface Branch {
  id: string;
  name: string;
  code: string;
}

function SheetFiltersInner({ branches }: { branches: Branch[] }) {
  const router = useRouter();
  const searchParams = useSearchParams();

  const currentBranch = searchParams.get("branch") || "";
  const currentFrom = searchParams.get("from") || "";
  const currentTo = searchParams.get("to") || "";

  const updateFilters = (updates: Record<string, string>) => {
    const params = new URLSearchParams(searchParams.toString());
    
    Object.entries(updates).forEach(([key, value]) => {
      if (value) {
        params.set(key, value);
      } else {
        params.delete(key);
      }
    });
    
    router.push(`/sheets?${params.toString()}`);
  };

  return (
    <div className="bg-white p-4 rounded-lg border border-slate-200 mb-6">
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div>
          <label className="block text-xs font-medium text-slate-700 mb-1">
            Branch
          </label>
          <select
            value={currentBranch}
            onChange={(e) => updateFilters({ branch: e.target.value })}
            className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:border-slate-500 focus:outline-none focus:ring-1 focus:ring-slate-500"
          >
            <option value="">All Branches</option>
            {branches.map((branch) => (
              <option key={branch.id} value={branch.id}>
                {branch.name} ({branch.code})
              </option>
            ))}
          </select>
        </div>
        
        <div>
          <label className="block text-xs font-medium text-slate-700 mb-1">
            From Date
          </label>
          <input
            type="date"
            value={currentFrom}
            onChange={(e) => updateFilters({ from: e.target.value })}
            className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:border-slate-500 focus:outline-none focus:ring-1 focus:ring-slate-500"
          />
        </div>
        
        <div>
          <label className="block text-xs font-medium text-slate-700 mb-1">
            To Date
          </label>
          <input
            type="date"
            value={currentTo}
            onChange={(e) => updateFilters({ to: e.target.value })}
            className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm focus:border-slate-500 focus:outline-none focus:ring-1 focus:ring-slate-500"
          />
        </div>
        
        <div className="flex items-end">
          <button
            onClick={() => updateFilters({ branch: "", from: "", to: "" })}
            className="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50 focus:border-slate-500 focus:outline-none focus:ring-1 focus:ring-slate-500"
          >
            Clear Filters
          </button>
        </div>
      </div>
    </div>
  );
}

export function SheetFilters({ branches }: { branches: Branch[] }) {
  return (
    <Suspense fallback={<div className="bg-white p-4 rounded-lg border border-slate-200 mb-6">Loading filters...</div>}>
      <SheetFiltersInner branches={branches} />
    </Suspense>
  );
}

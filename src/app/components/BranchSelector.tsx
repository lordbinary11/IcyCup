"use client";

import { useState } from "react";
import { OpenTodaySheetButton } from "./OpenTodaySheetButton";

interface Branch {
  id: string;
  name: string;
  code: string;
}

export function BranchSelector({ branches }: { branches: Branch[] }) {
  const [selectedBranchId, setSelectedBranchId] = useState<string>("");
  const selectedBranch = branches.find((b) => b.id === selectedBranchId);

  return (
    <div className="mb-12">
      <label htmlFor="branch-select" className="block text-sm font-medium text-slate-900 mb-2">
        Select Branch
      </label>
      <div className="flex gap-3 items-end max-w-2xl">
        <div className="flex-1">
          <select
            id="branch-select"
            className="w-full rounded-md border border-slate-300 bg-white px-4 py-2.5 text-slate-900 shadow-sm focus:border-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-900"
            value={selectedBranchId}
            onChange={(e) => setSelectedBranchId(e.target.value)}
          >
            <option value="">Choose a branch...</option>
            {branches.map((branch) => (
              <option key={branch.id} value={branch.id}>
                {branch.name}
              </option>
            ))}
          </select>
        </div>
        {selectedBranch && (
          <OpenTodaySheetButton 
            branchId={selectedBranch.id} 
            branchName={selectedBranch.name}
          />
        )}
      </div>
    </div>
  );
}

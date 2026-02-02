"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createBrowserSupabaseClient } from "@/lib/supabaseBrowser";
import {
  getAllItems,
  createItem,
  deleteItem,
  archiveItem,
  activateItem,
  addItemVersion,
  deleteItemVersion,
  type ItemWithVersions,
} from "@/lib/itemsApi";

const CATEGORIES = [
  { value: "pastry", label: "Pastry" },
  { value: "yoghurt_container", label: "Yoghurt Container" },
  { value: "yoghurt_non_container", label: "Yoghurt Non-Container" },
  { value: "yoghurt_refill", label: "Yoghurt Refill" },
  { value: "smoothie", label: "Smoothie" },
  { value: "water", label: "Water" },
  { value: "material", label: "Material" },
];

export default function ItemsManagementPage() {
  const router = useRouter();
  const [items, setItems] = useState<ItemWithVersions[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [showAddItem, setShowAddItem] = useState(false);
  const [showAddVersion, setShowAddVersion] = useState<string | null>(null);
  const [expandedItem, setExpandedItem] = useState<string | null>(null);

  const [newItem, setNewItem] = useState({
    code: "",
    name: "",
    category: "pastry",
    unit_price: "",
    volume_factor: "1",
    effective_from: new Date().toISOString().split("T")[0],
  });

  const [newVersion, setNewVersion] = useState({
    unit_price: "",
    volume_factor: "1",
    effective_from: new Date().toISOString().split("T")[0],
  });

  useEffect(() => {
    checkAuth();
    loadItems();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function checkAuth() {
    const client = createBrowserSupabaseClient();
    const { data: { user } } = await client.auth.getUser();
    if (!user) {
      router.push("/login");
      return;
    }

    const { data: profile } = await client
      .from("user_profiles")
      .select("role")
      .eq("user_id", user.id)
      .single();

    if (profile?.role !== "supervisor") {
      router.push("/");
    }
  }

  async function loadItems() {
    try {
      setLoading(true);
      const data = await getAllItems();
      setItems(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load items");
    } finally {
      setLoading(false);
    }
  }

  async function handleCreateItem(e: React.FormEvent) {
    e.preventDefault();
    try {
      await createItem({
        code: newItem.code,
        name: newItem.name,
        category: newItem.category,
        unit_price: parseFloat(newItem.unit_price),
        volume_factor: parseFloat(newItem.volume_factor),
        effective_from: newItem.effective_from,
      });
      setShowAddItem(false);
      setNewItem({
        code: "",
        name: "",
        category: "pastry",
        unit_price: "",
        volume_factor: "1",
        effective_from: new Date().toISOString().split("T")[0],
      });
      await loadItems();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to create item");
    }
  }

  async function handleAddVersion(itemId: string, e: React.FormEvent) {
    e.preventDefault();
    try {
      await addItemVersion({
        item_id: itemId,
        unit_price: parseFloat(newVersion.unit_price),
        volume_factor: parseFloat(newVersion.volume_factor),
        effective_from: newVersion.effective_from,
      });
      setShowAddVersion(null);
      setNewVersion({
        unit_price: "",
        volume_factor: "1",
        effective_from: new Date().toISOString().split("T")[0],
      });
      await loadItems();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to add version");
    }
  }

  async function handleDeleteItem(itemId: string) {
    if (!confirm("Are you sure you want to delete this item? This will also delete all its price history.")) {
      return;
    }
    try {
      await deleteItem(itemId);
      await loadItems();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to delete item");
    }
  }

  async function handleToggleActive(itemId: string, currentStatus: boolean) {
    const action = currentStatus ? "archive" : "activate";
    if (!confirm(`Are you sure you want to ${action} this item? ${currentStatus ? "It will no longer appear on new sheets." : "It will appear on new sheets again."}`)) {
      return;
    }
    try {
      if (currentStatus) {
        await archiveItem(itemId);
      } else {
        await activateItem(itemId);
      }
      await loadItems();
    } catch (err) {
      setError(err instanceof Error ? err.message : `Failed to ${action} item`);
    }
  }

  async function handleDeleteVersion(versionId: string) {
    if (!confirm("Are you sure you want to delete this price version?")) {
      return;
    }
    try {
      await deleteItemVersion(versionId);
      await loadItems();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to delete version");
    }
  }

  const groupedItems = items.reduce((acc, item) => {
    if (!acc[item.category]) {
      acc[item.category] = [];
    }
    acc[item.category].push(item);
    return acc;
  }, {} as Record<string, ItemWithVersions[]>);

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-lg">Loading items...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-50 p-4">
      <div className="mx-auto max-w-7xl">
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Items Management</h1>
            <p className="text-sm text-slate-600">Manage items and their pricing history</p>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => router.push("/admin")}
              className="rounded bg-slate-200 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-300"
            >
              Back to Admin
            </button>
            <button
              onClick={() => setShowAddItem(true)}
              className="rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
            >
              + Add New Item
            </button>
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded bg-red-50 p-4 text-red-800">
            {error}
            <button onClick={() => setError("")} className="ml-4 underline">
              Dismiss
            </button>
          </div>
        )}

        {showAddItem && (
          <div className="mb-6 rounded-lg bg-white p-6 shadow">
            <h2 className="mb-4 text-lg font-semibold">Add New Item</h2>
            <form onSubmit={handleCreateItem} className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-slate-900">Item Code</label>
                  <input
                    type="text"
                    required
                    value={newItem.code}
                    onChange={(e) => setNewItem({ ...newItem, code: e.target.value })}
                    className="mt-1 w-full rounded border border-slate-300 bg-white px-3 py-2 text-slate-900 placeholder:text-slate-400"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-900">Item Name</label>
                  <input
                    type="text"
                    required
                    value={newItem.name}
                    onChange={(e) => setNewItem({ ...newItem, name: e.target.value })}
                    className="mt-1 w-full rounded border border-slate-300 bg-white px-3 py-2 text-slate-900 placeholder:text-slate-400"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-900">Category</label>
                  <select
                    value={newItem.category}
                    onChange={(e) => setNewItem({ ...newItem, category: e.target.value })}
                    className="mt-1 w-full rounded border border-slate-300 bg-white px-3 py-2 text-slate-900"
                  >
                    {CATEGORIES.map((cat) => (
                      <option key={cat.value} value={cat.value}>
                        {cat.label}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-900">Unit Price (GHS)</label>
                  <input
                    type="number"
                    step="0.01"
                    required
                    value={newItem.unit_price}
                    onChange={(e) => setNewItem({ ...newItem, unit_price: e.target.value })}
                    className="mt-1 w-full rounded border border-slate-300 bg-white px-3 py-2 text-slate-900 placeholder:text-slate-400"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-900">Volume Factor</label>
                  <input
                    type="number"
                    step="0.0001"
                    value={newItem.volume_factor}
                    onChange={(e) => setNewItem({ ...newItem, volume_factor: e.target.value })}
                    className="mt-1 w-full rounded border border-slate-300 bg-white px-3 py-2 text-slate-900 placeholder:text-slate-400"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-900">Effective From</label>
                  <input
                    type="date"
                    required
                    value={newItem.effective_from}
                    onChange={(e) => setNewItem({ ...newItem, effective_from: e.target.value })}
                    className="mt-1 w-full rounded border border-slate-300 bg-white px-3 py-2 text-slate-900"
                  />
                </div>
              </div>
              <div className="flex gap-2">
                <button
                  type="submit"
                  className="rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
                >
                  Create Item
                </button>
                <button
                  type="button"
                  onClick={() => setShowAddItem(false)}
                  className="rounded bg-slate-200 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-300"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        )}

        <div className="space-y-6">
          {CATEGORIES.map((category) => {
            const categoryItems = groupedItems[category.value] || [];
            if (categoryItems.length === 0) return null;

            return (
              <div key={category.value} className="rounded-lg bg-white p-6 shadow">
                <h2 className="mb-4 text-lg font-semibold text-slate-900">{category.label}</h2>
                <div className="space-y-2">
                  {categoryItems.map((item) => (
                    <div key={item.id} className="border-b border-slate-200 pb-2 last:border-b-0">
                      <div className="flex items-center justify-between">
                        <div className="flex-1">
                          <div className="flex items-center gap-2">
                            <h3 className="font-semibold text-slate-900">
                              {item.code} - {item.name}
                            </h3>
                            <span className={`rounded px-2 py-0.5 text-xs font-medium ${
                                item.is_active 
                                  ? "bg-green-100 text-green-800" 
                                  : "bg-gray-100 text-gray-600"
                              }`}>
                              {item.is_active ? "Active" : "Archived"}
                            </span>
                          </div>
                          <p className="text-sm text-slate-600">
                            Current Price: GHS {item.current_version?.unit_price.toFixed(2) || "N/A"}
                            {item.current_version?.volume_factor !== 1 && (
                              <span> | Volume Factor: {item.current_version?.volume_factor}</span>
                            )}
                          </p>
                        </div>
                        <div className="flex gap-2">
                          <button
                            onClick={() => setShowAddVersion(showAddVersion === item.id ? null : item.id)}
                            className="text-sm text-blue-600 hover:underline"
                          >
                            + Add Price
                          </button>
                          <button
                            onClick={() => setExpandedItem(expandedItem === item.id ? null : item.id)}
                            className="text-sm text-slate-600 hover:underline"
                          >
                            {expandedItem === item.id ? "Hide" : "View"} History
                          </button>
                          <div className="flex gap-2">
                            <button
                              onClick={() => handleToggleActive(item.id, item.is_active)}
                              className={`text-sm font-medium hover:underline ${
                                item.is_active ? "text-orange-600" : "text-green-600"
                              }`}
                            >
                              {item.is_active ? "Archive" : "Activate"}
                            </button>
                            <button
                              onClick={() => handleDeleteItem(item.id)}
                              className="text-sm text-red-600 hover:underline"
                            >
                              Delete
                            </button>
                          </div>
                        </div>
                      </div>

                      {showAddVersion === item.id && (
                        <form
                          onSubmit={(e) => handleAddVersion(item.id, e)}
                          className="mt-3 rounded bg-slate-50 p-4"
                        >
                          <h3 className="mb-3 text-sm font-semibold">Add New Price Version</h3>
                          <div className="grid grid-cols-3 gap-3">
                            <div>
                              <label className="block text-xs font-medium text-slate-700">Unit Price (GHS)</label>
                              <input
                                type="number"
                                step="0.01"
                                required
                                value={newVersion.unit_price}
                                onChange={(e) => setNewVersion({ ...newVersion, unit_price: e.target.value })}
                                className="mt-1 w-full rounded border border-slate-300 px-2 py-1 text-sm"
                              />
                            </div>
                            <div>
                              <label className="block text-xs font-medium text-slate-700">Volume Factor</label>
                              <input
                                type="number"
                                step="0.0001"
                                value={newVersion.volume_factor}
                                onChange={(e) => setNewVersion({ ...newVersion, volume_factor: e.target.value })}
                                className="mt-1 w-full rounded border border-slate-300 px-2 py-1 text-sm"
                              />
                            </div>
                            <div>
                              <label className="block text-xs font-medium text-slate-700">Effective From</label>
                              <input
                                type="date"
                                required
                                value={newVersion.effective_from}
                                onChange={(e) => setNewVersion({ ...newVersion, effective_from: e.target.value })}
                                className="mt-1 w-full rounded border border-slate-300 px-2 py-1 text-sm"
                              />
                            </div>
                          </div>
                          <div className="mt-3 flex gap-2">
                            <button
                              type="submit"
                              className="rounded bg-blue-600 px-3 py-1 text-xs font-medium text-white hover:bg-blue-700"
                            >
                              Add Version
                            </button>
                            <button
                              type="button"
                              onClick={() => setShowAddVersion(null)}
                              className="rounded bg-slate-200 px-3 py-1 text-xs font-medium text-slate-700 hover:bg-slate-300"
                            >
                              Cancel
                            </button>
                          </div>
                        </form>
                      )}

                      {expandedItem === item.id && item.versions.length > 0 && (
                        <div className="mt-3 rounded bg-slate-50 p-4">
                          <h3 className="mb-2 text-sm font-semibold">Price History</h3>
                          <table className="w-full text-sm">
                            <thead>
                              <tr className="border-b border-slate-300 text-left">
                                <th className="pb-2 font-medium">Price (GHS)</th>
                                <th className="pb-2 font-medium">Volume Factor</th>
                                <th className="pb-2 font-medium">Effective From</th>
                                <th className="pb-2 font-medium">Effective To</th>
                                <th className="pb-2 font-medium">Status</th>
                                <th className="pb-2 font-medium">Actions</th>
                              </tr>
                            </thead>
                            <tbody>
                              {item.versions.map((version) => {
                                const today = new Date().toISOString().split("T")[0];
                                const isActive =
                                  version.effective_from <= today &&
                                  (version.effective_to === null || version.effective_to >= today);

                                return (
                                  <tr key={version.id} className="border-b border-slate-200">
                                    <td className="py-2">{version.unit_price.toFixed(2)}</td>
                                    <td className="py-2">{version.volume_factor}</td>
                                    <td className="py-2">{version.effective_from}</td>
                                    <td className="py-2">{version.effective_to || "—"}</td>
                                    <td className="py-2">
                                      {isActive ? (
                                        <span className="rounded bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800">
                                          Active
                                        </span>
                                      ) : (
                                        <span className="rounded bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-600">
                                          Inactive
                                        </span>
                                      )}
                                    </td>
                                    <td className="py-2">
                                      <button
                                        onClick={() => handleDeleteVersion(version.id)}
                                        className="text-xs text-red-600 hover:underline"
                                      >
                                        Delete
                                      </button>
                                    </td>
                                  </tr>
                                );
                              })}
                            </tbody>
                          </table>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

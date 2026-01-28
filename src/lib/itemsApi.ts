import { createBrowserSupabaseClient } from "@/lib/supabaseBrowser";

function createClient() {
  return createBrowserSupabaseClient();
}

export type Item = {
  id: string;
  code: string;
  name: string;
  category: string;
  is_active: boolean;
  created_at: string;
};

export type ItemVersion = {
  id: string;
  item_id: string;
  volume_factor: number;
  unit_price: number;
  effective_from: string;
  effective_to: string | null;
};

export type ItemWithVersions = Item & {
  versions: ItemVersion[];
  current_version?: ItemVersion;
};

export async function getAllItems(): Promise<ItemWithVersions[]> {
  const client = createClient();
  
  const { data: items, error: itemsError } = await client
    .from("items")
    .select("*")
    .order("category", { ascending: true })
    .order("name", { ascending: true });

  if (itemsError) throw new Error(`Failed to fetch items: ${itemsError.message}`);

  const { data: versions, error: versionsError } = await client
    .from("item_versions")
    .select("*")
    .order("effective_from", { ascending: false });

  if (versionsError) throw new Error(`Failed to fetch versions: ${versionsError.message}`);

  const today = new Date().toISOString().split("T")[0];

  return (items || []).map((item: Item) => {
    const itemVersions = (versions || [])
      .filter((v: any) => v.item_id === item.id)
      .map((v: any) => ({
        id: v.id,
        item_id: v.item_id,
        volume_factor: Number(v.volume_factor) || 1,
        unit_price: Number(v.unit_price) || 0,
        effective_from: v.effective_from,
        effective_to: v.effective_to,
      } as ItemVersion));
    
    const currentVersion = itemVersions.find(
      (v: ItemVersion) =>
        v.effective_from <= today &&
        (v.effective_to === null || v.effective_to >= today)
    );

    return {
      ...item,
      versions: itemVersions,
      current_version: currentVersion,
    };
  });
}

export async function createItem(item: {
  code: string;
  name: string;
  category: string;
  unit_price: number;
  volume_factor?: number;
  effective_from: string;
}) {
  const client = createClient();

  const { data: newItem, error: itemError } = await client
    .from("items")
    .insert({
      code: item.code,
      name: item.name,
      category: item.category,
    })
    .select()
    .single();

  if (itemError) throw new Error(`Failed to create item: ${itemError.message}`);

  const { error: versionError } = await client
    .from("item_versions")
    .insert({
      item_id: newItem.id,
      volume_factor: item.volume_factor || 1,
      unit_price: item.unit_price,
      effective_from: item.effective_from,
    });

  if (versionError) throw new Error(`Failed to create item version: ${versionError.message}`);

  return newItem;
}

export async function updateItem(itemId: string, updates: {
  code?: string;
  name?: string;
  is_active?: boolean;
}) {
  const client = createClient();

  const { error } = await client
    .from("items")
    .update(updates)
    .eq("id", itemId);

  if (error) throw new Error(`Failed to update item: ${error.message}`);
}

export async function archiveItem(itemId: string) {
  return updateItem(itemId, { is_active: false });
}

export async function activateItem(itemId: string) {
  return updateItem(itemId, { is_active: true });
}

export async function deleteItem(itemId: string) {
  const client = createClient();

  // Check if this item is being used in any sheets
  const tables = [
    'pastry_lines',
    'yoghurt_container_lines',
    'yoghurt_refill_lines',
    'yoghurt_non_container',
    'yoghurt_section_b_income'
  ];

  for (const table of tables) {
    const { data, error: checkError } = await client
      .from(table)
      .select('id')
      .eq('item_id', itemId)
      .limit(1);

    if (checkError) {
      throw new Error(`Failed to check item usage: ${checkError.message}`);
    }

    if (data && data.length > 0) {
      throw new Error(
        `Cannot delete this item because it is being used in existing sheets. ` +
        `Items can only be deleted if they haven't been used in any sheets yet.`
      );
    }
  }

  const { error } = await client
    .from("items")
    .delete()
    .eq("id", itemId);

  if (error) throw new Error(`Failed to delete item: ${error.message}`);
}

export async function addItemVersion(version: {
  item_id: string;
  unit_price: number;
  volume_factor?: number;
  effective_from: string;
}) {
  const client = createClient();

  const { data: existingVersions, error: fetchError } = await client
    .from("item_versions")
    .select("*")
    .eq("item_id", version.item_id)
    .is("effective_to", null);

  if (fetchError) throw new Error(`Failed to fetch existing versions: ${fetchError.message}`);

  if (existingVersions && existingVersions.length > 0) {
    for (const existing of existingVersions) {
      if (existing.effective_from >= version.effective_from) {
        const { error: deleteError } = await client
          .from("item_versions")
          .delete()
          .eq("id", existing.id);

        if (deleteError) throw new Error(`Failed to delete conflicting version: ${deleteError.message}`);
      } else {
        const dayBefore = new Date(version.effective_from);
        dayBefore.setDate(dayBefore.getDate() - 1);
        const effectiveTo = dayBefore.toISOString().split("T")[0];

        const { error: updateError } = await client
          .from("item_versions")
          .update({ effective_to: effectiveTo })
          .eq("id", existing.id);

        if (updateError) throw new Error(`Failed to close existing version: ${updateError.message}`);
      }
    }
  }

  const { error: insertError } = await client
    .from("item_versions")
    .insert({
      item_id: version.item_id,
      unit_price: version.unit_price,
      volume_factor: version.volume_factor || 1,
      effective_from: version.effective_from,
    });

  if (insertError) throw new Error(`Failed to add new version: ${insertError.message}`);
}

export async function deleteItemVersion(versionId: string) {
  const client = createClient();

  // Check if this version is being used in any sheets
  const tables = [
    'pastry_lines',
    'yoghurt_container_lines',
    'yoghurt_refill_lines',
    'yoghurt_non_container',
    'yoghurt_section_b_income'
  ];

  for (const table of tables) {
    const { data, error: checkError } = await client
      .from(table)
      .select('id')
      .eq('item_version_id', versionId)
      .limit(1);

    if (checkError) {
      throw new Error(`Failed to check version usage: ${checkError.message}`);
    }

    if (data && data.length > 0) {
      throw new Error(
        `Cannot delete this price version because it is being used in existing sheets. ` +
        `You can only delete versions that haven't been used yet.`
      );
    }
  }

  const { error } = await client
    .from("item_versions")
    .delete()
    .eq("id", versionId);

  if (error) throw new Error(`Failed to delete version: ${error.message}`);
}

import { cookies } from "next/headers";
import { createServerComponentClient } from "@supabase/auth-helpers-nextjs";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function createServerSupabaseClient(): any {
  return createServerComponentClient({ cookies });
}


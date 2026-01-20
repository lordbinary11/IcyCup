export type PastryLine = {
  id: string;
  item_name: string;
  qty_received: number;
  received_from_other_qty: number;
  received_from_branch_name: string | null;
  received_from_branch_id?: string | null;
  transfer_to_other_qty: number;
  transfer_to_branch_name: string | null;
  transfer_to_branch_id?: string | null;
  qty_sold: number;
  unit_price: number;
  leftovers: number;
  amount: number;
};

export type YoghurtHeader = {
  id?: string; // kept for compatibility if RPC aliases the pk
  sheet_id?: string;
  opening_stock: number;
  stock_received: number;
  total_stock: number;
  closing_stock: number;
};

export type YoghurtContainerLine = {
  id: string;
  item_name: string;
  volume_factor: number;
  qty_sold: number;
  volume_sold: number;
  unit_price: number;
  income: number;
};

export type YoghurtRefillLine = YoghurtContainerLine;

export type YoghurtNonContainer = {
  id: string;
  item_name: string;
  unit_price: number;
  volume_sold: number;
  income: number;
};

export type YoghurtSectionBIncome = {
  id: string;
  source: "pastries" | "smoothies" | "water";
  unit_price: number | null;
  qty_sold: number | null;
  income: number;
};

export type MaterialLine = {
  id: string;
  item_name: string;
  opening: number;
  received: number;
  used_normal: number;
  used_spoilt: number;
  transferred_out: number;
  transfer_to_branch_name: string | null;
  transfer_to_branch_id?: string | null;
  total_used: number;
  closing: number;
};

export type CurrencyNote = {
  id: string;
  denomination: number;
  quantity: number;
  amount: number;
};

export type StaffEntry = {
  id: string;
  staff_name: string;
};

export type ExtraExpense = {
  id: string;
  description: string;
  amount: number;
  created_at: string;
  created_by_name?: string | null;
};

export type SheetHeader = {
  id: string;
  branch_name: string;
  branch_id: string;
  supervisor_name: string | null;
  sheet_date: string;
  locked: boolean;
  total_pastries_income: number;
  yoghurt_section_a_total_volume: number;
  yoghurt_section_a_total_income: number;
  yoghurt_section_b_total: number;
  grand_total: number;
  cash_on_hand: number;
  momo_amount: number;
  cash_balance_delta: number;
  currency_total_cash?: number;
};

export type SheetPayload = {
  header: SheetHeader;
  pastries: PastryLine[];
  yoghurtHeader: YoghurtHeader | null;
  yoghurtContainers: YoghurtContainerLine[];
  yoghurtRefills: YoghurtRefillLine[];
  yoghurtNonContainer: YoghurtNonContainer | null;
  yoghurtSectionB: YoghurtSectionBIncome[];
  materials: MaterialLine[];
  currencyNotes: CurrencyNote[];
  staff: StaffEntry[];
  expenses: ExtraExpense[];
};


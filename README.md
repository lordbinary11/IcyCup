## IcyCup – Daily Sales Analysis (Digital)

A simple digital daily sales sheet application. All calculations are done in the
frontend (React). On submit, the complete sheet with calculated values is saved
to Supabase.

### Stack
- Next.js 14 (App Router, TypeScript, Tailwind)
- Supabase (Auth + Postgres + RLS)
- Client-side PDF export via html2canvas + jsPDF

### Quickstart

1) Install dependencies
```bash
npm install
```

2) Configure Supabase keys
```bash
cp env.example .env.local
# fill NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY
```

3) Apply the SQL schema to Supabase
```bash
psql $SUPABASE_DB_URL -f supabase/schema-simple.sql
# or paste into the Supabase SQL editor
```

4) Run the app
```bash
npm run dev
```
Open `http://localhost:3000`. Branch users can create/edit today's sheet.
All calculations (leftovers, totals, income, closing stock, cash delta) are
computed in the browser as you type. Click "Submit" to save the complete sheet.

### How it works
1. **Create sheet** – `get_or_create_today_sheet` RPC creates a new sheet for today
2. **Edit locally** – All field changes update React state, calculations recompute instantly
3. **Submit** – Saves all line items and totals to the database, locks the sheet

### Features
- **Pastries Record** – Track received, sold, transfers, leftovers
- **Yoghurt Record** – Section A (containers, refills, non-container) + Section B (other income)
- **Materials Used** – Opening, received, used, transferred, closing
- **Currency Notes** – Denomination × quantity breakdown
- **Staff Attendance** – Required before submission
- **Extra Expenses** – Audit-only expenses
- **PDF Export** – Client-side snapshot of the sheet

### RLS (Row Level Security)
- Branch users can only see/edit their own branch's sheets
- Supervisors can view all branches
- Sheets are locked after submission

Refer to `supabase/schema-simple.sql` for the database schema.

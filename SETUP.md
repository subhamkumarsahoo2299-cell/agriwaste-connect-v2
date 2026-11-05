# AgriWaste Connect v2 — full-stack starter

This is a deployable full-stack web application starter, not a publicly hosted site yet. It uses:
- React + Vite frontend
- Supabase Auth and PostgreSQL database
- Row Level Security policies
- User-submitted waste listings and buyer enquiries
- Published/verified price quotation board
- Browser geolocation only after the visitor presses "Find near me" and grants permission
- English / Odia interface toggle
- Supabase Edge Function for server-side AI recommendations

## What is live after setup?
After Supabase and hosting are configured, all visitors can open the public URL. Visitors can browse published listings and published price quotations without signing in. Users must create an account to publish listings or send enquiries. Listings and enquiries are stored in the shared database, not in one browser.

## 1. Create Supabase project
1. Create a project at https://supabase.com.
2. Open SQL Editor and run all of `supabase/schema.sql`.
3. In Project Settings → API, copy Project URL and the publishable/anon key.
4. Copy `.env.example` to `.env` and fill in:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
5. In Authentication → URL Configuration, set your eventual site URL and redirect URLs.
6. For a public production launch, configure email SMTP and test email confirmation/password reset.

## 2. Run locally
Requires Node.js 20 or newer.
```bash
npm install
npm run dev
```
Open the local URL printed by Vite. For a production build:
```bash
npm run build
```
The `dist` folder is the deployable frontend.

## 3. Deploy publicly
1. Push this project to a private or public GitHub repository.
2. Import it into https://vercel.com (or another static host).
3. Set build command `npm run build`, output directory `dist`.
4. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` as hosting environment variables.
5. Deploy and add the final domain to Supabase Auth redirect URLs.
6. Test signup, email confirmation, login, listing creation, public listing visibility and enquiries from two separate accounts.

## 4. Enable AI recommendations
1. Install Supabase CLI and link the project.
2. Deploy:
```bash
supabase functions deploy agriwaste-assistant
```
3. Add the provider key as a server-side secret:
```bash
supabase secrets set OPENAI_API_KEY=YOUR_KEY
```
4. Never add the AI API key to `.env` variables beginning with `VITE_`, frontend source, or GitHub.

If the Edge Function is not deployed or the secret is missing, the app displays a setup message instead of pretending AI is active.

## 5. Location and privacy
- The app does not request GPS automatically on page load.
- A visitor must press "Find near me" and approve the browser permission prompt.
- Coordinates are kept in page memory for nearby sorting and are not uploaded or displayed publicly.
- When a supplier creates a listing, the app attaches coordinates only if the user has explicitly enabled location during that session. Remove those coordinates from the listing form if you do not want to store them.
- For a real production launch, publish a privacy policy, retention policy and contact details. Do not expose a farmer's precise home location; prefer village/market-centre coordinates and share exact pickup details only after consent.

## 6. Market prices: important data rule
The app intentionally does not invent "live market prices". Price quotations are read from `price_quotes` only after an administrator publishes or verifies them. Users can submit quotations with source and observed date; pending quotations are not public. Seed the table with properly sourced, dated quotations only. AGMARKNET prices are for notified agricultural commodities and may not exist for many crop residues. A supplier's asking price is not the same as a completed transaction price.

To add a quote, a signed-in user can submit a pending quote through a future quote-submission form or an administrator can add it in Supabase. Only an admin should set status to `published` or `verified`.

## 7. Make an administrator
After creating your own account, run this in Supabase SQL Editor, replacing the email:
```sql
update public.profiles
set role = 'admin'
where id = (select id from auth.users where email = 'YOUR_ADMIN_EMAIL');
```
Do not allow public signup to assign the admin role. The signup form deliberately offers only farmer, buyer, entrepreneur and student roles.

## 8. Before real public launch
- Add a privacy policy, terms, grievance contact and moderation process.
- Add listing photo storage with Supabase Storage policies.
- Add quote submission and admin review UI.
- Add email notifications and enquiry replies.
- Add rate limiting, abuse reporting, CAPTCHA and audit logs.
- Add pagination and server-side distance search for large datasets.
- Verify Odia translations with native speakers.
- Verify each waste-processing recommendation with agricultural subject experts.
- Test RLS with separate farmer, buyer and admin accounts.
- Use HTTPS only. Do not collect exact GPS unless there is a clear need and explicit consent.

## Current scope
This package includes working Supabase-backed signup/login, public listing reads, authenticated listing publishing, buyer enquiry creation, public published quote reads, bilingual UI, consent-based geolocation sorting, and an optional server-side AI Edge Function. It is a foundation for a public service; it is not already deployed, and it needs your Supabase project credentials and hosting deployment before anyone on the internet can access it.

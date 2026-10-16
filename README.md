# Global Marketing Agency — GitHub + Supabase starter

Gold-and-black, mobile-friendly static website for Global Marketing Agency. GitHub Pages hosts the frontend; Supabase provides authentication, database and private file storage.

## Included
- Public home page, agency description and how-it-works section
- Email/password sign-up, login and password reset (Supabase Auth)
- KSh 200 registration-payment submission and admin review
- Admin account approval/suspension, campaign creation, screenshot review, withdrawal and referral review
- 20-hour campaign expiry and screenshot upload
- Referral code display and KSh 25 referral bonus workflow
- Advertiser status, campaign submissions and activity records

## Fixed project details
- Agency: Global Marketing Agency
- Registration fee: KSh 200
- KCB Paybill: `522522`
- Account number: `1343698359`
- Campaign duration: 20 hours
- Referral bonus: KSh 25, subject to the agency's published eligibility rules
- Default example rate: KSh 50 per approved view; set actual campaign terms before launch

## Deploy on GitHub Pages
1. Create a Supabase project at https://supabase.com/.
2. In Supabase **SQL Editor**, run `supabase-schema.sql`.
3. In Supabase **Authentication → URL Configuration**, add your future GitHub Pages URL to Site URL / Redirect URLs.
4. Copy `config.js.example` to a new file named `config.js`. Fill in the Supabase Project URL and public anon/publishable key from **Project Settings → API**. Never use the `service_role` key in browser code.
5. Create a GitHub repository and upload `index.html`, `styles.css`, `app.js`, `config.js`, and `README.md`. Do not upload the example file instead of your configured `config.js`.
6. In GitHub open **Settings → Pages**; choose **Deploy from a branch**, select `main` and `/(root)`, then Save.
7. Open the GitHub Pages URL and test account creation, email confirmation, payment submission, file upload and admin review before inviting anyone.

### Set up the first administrator
1. Register your own account on the website and confirm the email if confirmation is enabled.
2. In Supabase SQL Editor run the following, replacing the email with your admin email:
   `update public.profiles set role='admin', status='active' where email='YOUR_ADMIN_EMAIL';`
3. Sign out and sign back in. The admin panels should appear.

## Important before real launch
This is a functional starter, not a fully audited financial platform. Test and tighten the database rules before collecting real users' data or payments. In particular, replace the broad profile-update policy in the SQL with column-restricted RPCs so a user can never edit their own role/status. Referral creation should be handled by a trusted database function after successful payment approval, and earnings should be stored in a ledger with server-side checks against duplicate/invalid submissions. The sample UI intentionally does not automatically pay people or treat screenshots as proof of authentic views.

Supabase SQL policies are security-critical. Have the final policies reviewed and test them using separate advertiser and admin accounts. Publish terms, privacy notice, campaign conditions, withdrawal eligibility and dispute/refund policies. Verify the paybill/account ownership and payment process independently before going live.

## File layout
- `index.html` — website structure
- `styles.css` — responsive gold/black styling
- `app.js` — authentication, advertiser portal and admin UI
- `config.js.example` — safe configuration template
- `supabase-schema.sql` — database tables, access policies and storage setup

# ARTFOS GOLD — Admin Console Setup

## Included in this revision
- `admin.html`: separate admin login and management console (`/admin.html`).
- `admin.js` / `admin.css`: member approval and membership, signal CRUD/status, broker list, membership plan settings, manual news entry, site settings.
- `sql/admin-migration.sql`: additive tables for audit logs, banners, FAQ, member broker registrations, manual payments, risk notices, notifications, and RLS policies.

## Apply carefully
1. Back up the Supabase project first.
2. Open Supabase → SQL Editor.
3. If the original `sql/schema.sql` has not been run, run it first.
4. Run `sql/admin-migration.sql`.
5. Register the intended admin account through the existing website or Supabase Auth.
6. In Supabase → Authentication → Users, copy the intended admin user's UUID.
7. Run this statement after replacing the placeholder with the UUID (keep the quotes):

```sql
update public.member_profiles
set role = 'admin', approval_status = 'approved'
where user_id = 'AUTH_USER_UUID';
```

8. Visit `https://YOUR-VERCEL-DOMAIN/admin.html` and sign in with that account.
9. Configure and test Supabase Auth MFA/TOTP before using privileged operations with real member data.

## Important limits — do not treat this as production-complete
This is a static Supabase client console and uses the existing Supabase Auth session and RLS. It does **not** provide a trusted API server with HttpOnly/Secure/SameSite cookies, Argon2id password handling, custom rate limiting, a server-side 2FA gate, or automatic audit logging. Supabase Auth handles password storage and sessions. Before handling real payments or relying on strict MFA enforcement, add a server-side API/Edge Functions and enforce MFA assurance (`aal2`) for admin writes. The `admin_audit_logs` table is prepared but this UI does not yet write to it automatically.

The console only manages records stored in Supabase. It does not generate real market signals, connect TradingView, supply live news, process QRIS, or validate broker accounts automatically. Those require separate provider/backend integrations. Do not advertise those integrations as live until connected and tested.

Never put a Supabase `service_role` key in `config.js`, HTML, JavaScript, or any public repository. `config.js` must contain only the public anon/publishable key. RLS is essential.

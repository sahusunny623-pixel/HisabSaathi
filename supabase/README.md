# Supabase setup

Apply migrations to the intended Supabase project, not to the legacy SQLite
database or an unrelated Replit database:

```bash
supabase db push
```

The current workspace does not have the Supabase CLI or a connected Supabase
project, so this command is intentionally not run here. Run the RLS tests after
the migration is applied and seeded with two isolated shops.
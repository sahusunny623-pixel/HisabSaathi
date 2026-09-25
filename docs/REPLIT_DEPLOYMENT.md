# Replit deployment

## Current state

The legacy Node server can still run with `npm start`, but it is not the
production source of truth. Supabase credentials for the mobile app and future
server functions must be supplied through Replit Secrets.

## Required secrets

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` for public client configuration
- server-only Supabase service-role key only where an Edge Function/server
  process explicitly requires it
- provider credentials only when the provider is configured and tested

Never commit values for these keys. `.env.example` contains names only.

## Environment limitation

This Replit environment has Node.js and PostgreSQL client tools but does not
have Flutter, Dart, or Supabase CLI. Mobile build and Supabase local
integration tests therefore need a Flutter/Supabase-capable CI runner.

## Before publishing

- apply and verify Supabase migrations against the intended external project
- configure auth redirect URLs
- configure private storage and signed URL behavior
- run RLS and financial transaction tests
- configure a supported scheduler for notification jobs
- remove legacy routes only after replacement flows are live and reconciled
import Database from 'better-sqlite3';
import fs from 'node:fs';
import path from 'node:path';
import dotenv from 'dotenv';
dotenv.config();

const file = process.env.DATABASE_FILE || './data/hisabsaathi.db';
fs.mkdirSync(path.dirname(path.resolve(file)), { recursive: true });
export const db = new Database(file);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
CREATE TABLE IF NOT EXISTS shops (
 id TEXT PRIMARY KEY,
 name TEXT NOT NULL,
 address TEXT DEFAULT '',
 category TEXT DEFAULT '',
 owner_name TEXT DEFAULT '',
 language TEXT DEFAULT 'hi',
 subscription_status TEXT DEFAULT 'trial',
 subscription_expires_at TEXT,
 profile_id TEXT UNIQUE,
 subscription_grace_expires_at TEXT,
 access_token_hash TEXT UNIQUE,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS customers (
 id TEXT PRIMARY KEY,
 shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
 name TEXT NOT NULL,
 phone TEXT DEFAULT '',
 address TEXT DEFAULT '',
 credit_balance INTEGER NOT NULL DEFAULT 0,
 due_date TEXT,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS products (
 id TEXT PRIMARY KEY,
 shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
 name TEXT NOT NULL,
 sku TEXT DEFAULT '',
 price INTEGER NOT NULL DEFAULT 0,
 stock INTEGER NOT NULL DEFAULT 0,
 low_stock_threshold INTEGER NOT NULL DEFAULT 5,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS invoices (
 id TEXT PRIMARY KEY,
 shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
 customer_id TEXT REFERENCES customers(id) ON DELETE SET NULL,
 invoice_no TEXT NOT NULL,
 subtotal INTEGER NOT NULL DEFAULT 0,
 paid INTEGER NOT NULL DEFAULT 0,
 credit INTEGER NOT NULL DEFAULT 0,
 status TEXT NOT NULL DEFAULT 'paid',
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS invoice_items (
 id TEXT PRIMARY KEY,
 invoice_id TEXT NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
 product_id TEXT REFERENCES products(id) ON DELETE SET NULL,
 name TEXT NOT NULL,
 qty INTEGER NOT NULL,
 unit_price INTEGER NOT NULL,
 amount INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS payments (
 id TEXT PRIMARY KEY,
 shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
 customer_id TEXT REFERENCES customers(id) ON DELETE SET NULL,
 invoice_id TEXT REFERENCES invoices(id) ON DELETE SET NULL,
 amount INTEGER NOT NULL,
 method TEXT NOT NULL,
 provider_ref TEXT DEFAULT '',
 status TEXT NOT NULL DEFAULT 'pending',
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS subscription_orders (
 id TEXT PRIMARY KEY,
 shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
 provider TEXT NOT NULL,
 provider_ref TEXT DEFAULT '',
 amount INTEGER NOT NULL,
 currency TEXT NOT NULL DEFAULT 'INR',
 status TEXT NOT NULL DEFAULT 'created',
 expires_at TEXT,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS reminders (
 id TEXT PRIMARY KEY,
 shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
 customer_id TEXT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
 channel TEXT NOT NULL,
 scheduled_for TEXT NOT NULL,
 status TEXT NOT NULL DEFAULT 'queued',
 sent_at TEXT,
 provider_ref TEXT DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_customers_shop ON customers(shop_id);
CREATE INDEX IF NOT EXISTS idx_products_shop ON products(shop_id);
CREATE INDEX IF NOT EXISTS idx_invoices_shop_date ON invoices(shop_id, created_at);
CREATE INDEX IF NOT EXISTS idx_reminders_due ON reminders(status, scheduled_for);
CREATE INDEX IF NOT EXISTS idx_subscription_orders_shop ON subscription_orders(shop_id, created_at);
CREATE INDEX IF NOT EXISTS idx_shops_token ON shops(access_token_hash);
`);

const cols = db.prepare('PRAGMA table_info(subscription_orders)').all().map(x=>x.name);
if(!cols.includes('proof_path')) db.exec("ALTER TABLE subscription_orders ADD COLUMN proof_path TEXT DEFAULT ''");
const shopCols = db.prepare('PRAGMA table_info(shops)').all().map(x=>x.name);
if(!shopCols.includes('profile_id')) db.exec("ALTER TABLE shops ADD COLUMN profile_id TEXT");
if(!shopCols.includes('subscription_grace_expires_at')) db.exec("ALTER TABLE shops ADD COLUMN subscription_grace_expires_at TEXT");
const missingProfiles = db.prepare("SELECT id FROM shops WHERE profile_id IS NULL OR profile_id=''").all();
for (const row of missingProfiles) {
  let pid; do { pid = 'HS-' + Math.random().toString(36).slice(2, 10).toUpperCase(); } while (db.prepare('SELECT 1 FROM shops WHERE profile_id=?').get(pid));
  db.prepare('UPDATE shops SET profile_id=? WHERE id=?').run(pid,row.id);
}

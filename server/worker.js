import dotenv from 'dotenv';
import { db } from './db.js';
dotenv.config();
const run=()=>{const rows=db.prepare("SELECT r.id,c.name,c.phone,c.credit_balance FROM reminders r JOIN customers c ON c.id=r.customer_id WHERE r.status='queued' AND r.scheduled_for<=CURRENT_TIMESTAMP LIMIT 100").all();for(const r of rows){console.log(`[HisabSaathi reminder] ${r.name} ${r.phone} balance ₹${(r.credit_balance/100).toFixed(2)} — configure WhatsApp/SMS provider for actual delivery.`);db.prepare("UPDATE reminders SET status='prepared',sent_at=CURRENT_TIMESTAMP WHERE id=?").run(r.id);}};
run();setInterval(run,Number(process.env.WORKER_INTERVAL_MS||60000));

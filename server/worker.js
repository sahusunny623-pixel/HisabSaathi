import dotenv from 'dotenv';
import { db } from './db.js';
dotenv.config();

const sleep=ms=>new Promise(r=>setTimeout(r,ms));
function normalizePhone(raw){return String(raw||'').replace(/\D/g,'');}
async function sendWhatsApp(phone,message,customerName,shopName,amount){
  const provider=String(process.env.WHATSAPP_PROVIDER||'meta').toLowerCase();
  const destination=normalizePhone(phone);
  if(provider==='gupshup'){
    const apiKey=process.env.GUPSHUP_API_KEY;
    const source=normalizePhone(process.env.GUPSHUP_SOURCE_NUMBER);
    const appName=String(process.env.GUPSHUP_APP_NAME||'HisabSaathi');
    const templateId=String(process.env.GUPSHUP_UDHAAR_TEMPLATE_ID||'').trim();
    if(!apiKey||!source||!templateId) throw new Error('Gupshup WhatsApp provider not configured');
    const form=new URLSearchParams();
    form.set('channel','whatsapp'); form.set('source',source); form.set('destination',destination); form.set('src.name',appName);
    form.set('template',JSON.stringify({id:templateId,params:[String(customerName||''),String(amount||0),String(shopName||'HisabSaathi')]}));
    const r=await fetch('https://api.gupshup.io/wa/api/v1/template/msg',{method:'POST',headers:{apikey:apiKey,'Content-Type':'application/x-www-form-urlencoded'},body:form});
    const d=await r.json().catch(()=>({})); if(!r.ok) throw new Error(d?.message||'Gupshup WhatsApp send failed'); return d?.messageId||'';
  }
  if(!process.env.WHATSAPP_TOKEN||!process.env.WHATSAPP_PHONE_NUMBER_ID) throw new Error('Meta WhatsApp provider not configured');
  const version=process.env.WHATSAPP_API_VERSION||'v23.0';
  const r=await fetch(`https://graph.facebook.com/${version}/${process.env.WHATSAPP_PHONE_NUMBER_ID}/messages`,{method:'POST',headers:{Authorization:`Bearer ${process.env.WHATSAPP_TOKEN}`,'Content-Type':'application/json'},body:JSON.stringify({messaging_product:'whatsapp',to:destination,type:'text',text:{body:message}})});
  const d=await r.json().catch(()=>({})); if(!r.ok) throw new Error(d?.error?.message||'WhatsApp send failed'); return d?.messages?.[0]?.id||'';
}
async function sendSms(phone,message){
  if(!process.env.SMS_PROVIDER_URL||!process.env.SMS_PROVIDER_TOKEN) throw new Error('SMS provider not configured');
  const r=await fetch(process.env.SMS_PROVIDER_URL,{method:'POST',headers:{Authorization:`Bearer ${process.env.SMS_PROVIDER_TOKEN}`,'Content-Type':'application/json'},body:JSON.stringify({to:phone,message})});
  if(!r.ok) throw new Error('SMS send failed'); const d=await r.json().catch(()=>({})); return d?.request_id||'';
}
async function processBatch(){
  const rows=db.prepare(`SELECT r.*,c.name,c.phone,c.credit_balance,s.name shop_name FROM reminders r JOIN customers c ON c.id=r.customer_id JOIN shops s ON s.id=r.shop_id WHERE r.status='queued' AND datetime(r.scheduled_for)<=datetime('now') AND c.credit_balance>0 ORDER BY r.scheduled_for LIMIT 50`).all();
  for(const r of rows){
    try{
      if(r.channel==='call'){db.prepare(`UPDATE reminders SET status='manual_required' WHERE id=?`).run(r.id);continue;}
      const amount=(r.credit_balance/100).toLocaleString('en-IN');
      const message=`Namaste ${r.name}, ${r.shop_name} ki taraf se ₹${amount} ki udhaari baaki hai. Kripya payment kar dein. Dhanyavaad 🙏`;
      let ref='';
      if(r.channel==='whatsapp'){try{ref=await sendWhatsApp(r.phone,message,r.name,r.shop_name,amount);}catch{if(process.env.SMS_PROVIDER_URL) {ref=await sendSms(r.phone,message);db.prepare(`UPDATE reminders SET channel='sms' WHERE id=?`).run(r.id);}else throw new Error('WhatsApp failed and SMS fallback is not configured');}}
      else ref=await sendSms(r.phone,message);
      db.prepare(`UPDATE reminders SET status='sent',sent_at=CURRENT_TIMESTAMP,provider_ref=? WHERE id=?`).run(ref,r.id);
    }catch(e){db.prepare(`UPDATE reminders SET status='failed' WHERE id=?`).run(r.id);console.error('Reminder',r.id,e.message);}
  }
}
console.log('HisabSaathi reminder worker started');
while(true){await processBatch();await sleep(Number(process.env.WORKER_INTERVAL_MS||60000));}

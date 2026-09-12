from pathlib import Path

path = Path('server/index.js')
source = path.read_text()
start = source.find('async function notifyOwner')
if start < 0:
    raise SystemExit('notifyOwner function not found')
end = source.find("\napp.get('/api/health'", start)
if end < 0:
    raise SystemExit('health route marker not found')
replacement = r'''function waNumber(raw){return String(raw||'').replace(/\D/g,'');}
async function notifyOwner(payload,proofPath){
  const token=process.env.WHATSAPP_TOKEN;
  const phoneId=process.env.WHATSAPP_PHONE_NUMBER_ID;
  const to=waNumber(process.env.ADMIN_WHATSAPP_TO||'916206769679');
  const version=process.env.WHATSAPP_API_VERSION||'v23.0';
  if(!token||!phoneId||!to){console.warn('WhatsApp notification skipped: credentials/recipient not configured');return {sent:false,reason:'whatsapp_not_configured'};}
  try{
    const base=`https://graph.facebook.com/${version}/${phoneId}`;
    const mode=(process.env.WHATSAPP_MESSAGE_MODE||'template').toLowerCase();
    let response;
    if(mode==='template'){
      const templateName=String(process.env.WHATSAPP_TEMPLATE_NAME||'hisabsaathi_payment_claim').trim();
      const languageCode=String(process.env.WHATSAPP_TEMPLATE_LANGUAGE||'en_US').trim();
      const body={messaging_product:'whatsapp',to,type:'template',template:{name:templateName,language:{code:languageCode},components:[{type:'body',parameters:[
        {type:'text',parameter_name:'profile_id',text:String(payload.profile_id)},
        {type:'text',parameter_name:'shop_name',text:String(payload.shop_name||'-')},
        {type:'text',parameter_name:'amount',text:String(payload.amount||149)},
        {type:'text',parameter_name:'utr',text:String(payload.utr)},
        {type:'text',parameter_name:'order_id',text:String(payload.order_id)}
      ]}]}};
      response=await fetch(`${base}/messages`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify(body)});
    }else{
      const text=`HisabSaathi payment claim\nProfile: ${payload.profile_id}\nShop: ${payload.shop_name||'-'}\nAmount: ₹${payload.amount||149}\nUTR: ${payload.utr}\nOrder: ${payload.order_id}\nVerify actual payment before approval.`;
      response=await fetch(`${base}/messages`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({messaging_product:'whatsapp',to,type:'text',text:{body:text}})});
    }
    const responseJson=await response.json().catch(()=>({}));
    if(!response.ok)throw new Error(responseJson?.error?.message||`WhatsApp message failed (${response.status})`);
    let proofSent=false;
    if(proofPath&&fs.existsSync(proofPath)&&String(process.env.WHATSAPP_SEND_PROOF_IMAGE||'true').toLowerCase()==='true'){
      const form=new FormData();
      const ext=path.extname(proofPath).toLowerCase();
      const mime=ext==='.png'?'image/png':ext==='.webp'?'image/webp':'image/jpeg';
      form.append('messaging_product','whatsapp');
      form.append('file',new Blob([fs.readFileSync(proofPath)],{type:mime}),`payment-proof${ext||'.jpg'}`);
      const upload=await fetch(`${base}/media`,{method:'POST',headers:{Authorization:`Bearer ${token}`},body:form});
      const media=await upload.json().catch(()=>({}));
      if(!upload.ok||!media.id)throw new Error(media?.error?.message||`WhatsApp media upload failed (${upload.status})`);
      const image=await fetch(`${base}/messages`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({messaging_product:'whatsapp',to,type:'image',image:{id:media.id,caption:`Receipt • ${payload.profile_id} • UTR ${payload.utr}`}})});
      const imageJson=await image.json().catch(()=>({}));
      if(!image.ok)throw new Error(imageJson?.error?.message||`WhatsApp proof send failed (${image.status})`);
      proofSent=true;
    }
    return {sent:true,proof_sent:proofSent,message_id:responseJson?.messages?.[0]?.id||null};
  }catch(e){console.error('WhatsApp owner notification failed:',e.message);return {sent:false,reason:'request_failed',error:e.message};}
}
'''
path.write_text(source[:start] + replacement + source[end:])
print('WhatsApp sender patched')

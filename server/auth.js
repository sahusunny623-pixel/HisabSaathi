import crypto from 'node:crypto';
import { db } from './db.js';

export function issueAccessToken(){ return crypto.randomBytes(32).toString('base64url'); }
export function hashToken(token){ return crypto.createHash('sha256').update(token).digest('hex'); }
export function authRequired(req,res,next){
  if(req.path.startsWith('/admin/subscriptions') && process.env.ADMIN_VERIFY_SECRET && req.headers['x-admin-verify-secret']===process.env.ADMIN_VERIFY_SECRET) return next();
  if(req.path==='/webhooks/upi-verification' && process.env.UPI_WEBHOOK_SECRET && req.headers['x-upi-webhook-secret']===process.env.UPI_WEBHOOK_SECRET) return next();
  const raw=(req.headers.authorization||'').replace(/^Bearer\s+/i,'') || req.headers['x-shop-token'];
  if(!raw) return res.status(401).json({error:'Authentication required'});
  const row=db.prepare('SELECT id FROM shops WHERE access_token_hash=?').get(hashToken(String(raw)));
  if(!row) return res.status(401).json({error:'Invalid access token'});
  req.shopId=row.id; next();
}
export function sameShop(req,res,next){
  const shopId=req.params.shopId || req.body?.shop_id || req.params.customerId && db.prepare('SELECT shop_id FROM customers WHERE id=?').get(req.params.customerId)?.shop_id;
  if(shopId && shopId!==req.shopId) return res.status(403).json({error:'Forbidden'});
  next();
}

// Firestore-da istifadeci axtarir.
//   node tools/tap_hesab.mjs ehmed

import { readFileSync } from 'node:fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const account = JSON.parse(readFileSync(process.env.FIREBASE_KEY, 'utf8'));
initializeApp({ credential: cert(account), projectId: account.project_id });

const axtar = (process.argv[2] ?? '').toLowerCase();
const snap = await getFirestore().collection('users').get();

// Azerbaycan herflerini sadelesdirib muqayise edirik.
const sade = (s) => String(s ?? '').toLowerCase()
  .replace(/ə/g, 'e').replace(/ı/g, 'i').replace(/ö/g, 'o')
  .replace(/ü/g, 'u').replace(/ş/g, 's').replace(/ç/g, 'c').replace(/ğ/g, 'g');

const hedef = sade(axtar);

for (const doc of snap.docs) {
  const d = doc.data();
  const hay = sade(`${d.name} ${d.email} ${d.city}`);
  if (hedef && !hay.includes(hedef)) continue;

  console.log('---');
  console.log('uid     :', doc.id);
  console.log('ad      :', d.name ?? '');
  console.log('email   :', d.email ?? '');
  console.log('sekil   :', d.photoUrl ? 'var' : 'yox');
  console.log('coins   :', d.coins ?? 0);
  console.log('yaradib :', d.createdAt?.toDate?.()?.toISOString?.() ?? '');
}

console.log(`\ncemi ${snap.size} istifadeci`);
process.exit(0);

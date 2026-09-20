// Firestore -> Supabase köçürmə.
//
// İşə salmazdan əvvəl supabase/migrations altındakı üç SQL faylı panelə salınmalıdır.
//
// İşə salmaq:
//   cd tools
//   npm install firebase-admin @supabase/supabase-js
//   FIREBASE_KEY=C:\yol\service-account.json \
//   SUPABASE_URL=https://xxxx.supabase.co \
//   SUPABASE_SERVICE_KEY=... \
//   node migrate_firestore.mjs
//
// Açarların ikisi də gizlidir — heç kimə göndərmə, repoya qoyma.
// --dry yazsan heç nə yazılmır, yalnız say göstərilir.

import { readFileSync } from 'node:fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { createClient } from '@supabase/supabase-js';

const DRY = process.argv.includes('--dry');

const keyPath = process.env.FIREBASE_KEY;
const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_KEY;

if (!keyPath || !url || !serviceKey) {
  console.error('FIREBASE_KEY, SUPABASE_URL və SUPABASE_SERVICE_KEY lazımdır.');
  process.exit(1);
}

const account = JSON.parse(readFileSync(keyPath, 'utf8'));
initializeApp({ credential: cert(account), projectId: account.project_id });
const fs = getFirestore();
const db = createClient(url, serviceKey, { auth: { persistSession: false } });

// Firebase uid -> Supabase uuid.
const uidMap = new Map();
// Firestore sənəd id -> uuid (chats, moments, videos, rooms üçün).
const idMap = { chats: new Map(), moments: new Map(), videos: new Map(), rooms: new Map() };

const uuid = () => crypto.randomUUID();

/** Firestore Timestamp -> ISO mətn. */
function ts(v) {
  if (!v) return null;
  if (typeof v.toDate === 'function') return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'number') return new Date(v).toISOString();
  return null;
}

const str = (v) => (v === undefined || v === null ? null : String(v));

/** Yalnız tarix (YYYY-MM-DD). Timestamp, Date və ya mətn ola bilər. */
function dateOnly(v) {
  const iso = ts(v);
  if (iso) return iso.slice(0, 10);
  if (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}/.test(v)) return v.slice(0, 10);
  return null;
}
const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0);

/** Sətirləri 500-lük dəstələrlə yazır. */
async function insert(table, rows) {
  if (!rows.length) return 0;
  if (DRY) return rows.length;

  let done = 0;
  for (let i = 0; i < rows.length; i += 500) {
    const chunk = rows.slice(i, i + 500);
    const { error } = await db.from(table).upsert(chunk, { ignoreDuplicates: true });
    if (error) {
      console.error(`  ! ${table}: ${error.message}`);
      // Dəstə bütöv düşsə bir-bir yazırıq ki, bir pis sətir qalanını aparmasın.
      const reasons = new Set();
      for (const row of chunk) {
        const r = await db.from(table).upsert(row, { ignoreDuplicates: true });
        if (r.error) reasons.add(r.error.message);
        else done++;
      }
      for (const m of reasons) console.error(`    - ${m}`);
      continue;
    }
    done += chunk.length;
  }
  return done;
}

/** Kolleksiyanı səhifə-səhifə gəzir. */
async function each(ref, fn) {
  const snap = await ref.get();
  for (const doc of snap.docs) await fn(doc.id, doc.data() ?? {}, doc.ref);
  return snap.size;
}

const log = (name, n) => console.log(`${name.padEnd(22)} ${n}`);

// ─────────────────────────────  1. İSTİFADƏÇİLƏR  ─────────────────────────────
// Birinci gedir: qalan hər şey uid xəritəsinə baxır.

async function migrateUsers() {
  const rows = [];

  await each(fs.collection('users'), (uid, d) => {
    const id = uuid();
    uidMap.set(uid, id);

    rows.push({
      id,
      firebase_uid: uid,
      name: str(d.name) ?? '',
      email: str(d.email),
      phone: str(d.phone),
      photo_url: str(d.photoUrl ?? d.photo),
      about: str(d.about) ?? '',
      city: str(d.city) ?? '',
      country: str(d.country) ?? '',
      country_code: str(d.countryCode) ?? '',
      gender: str(d.gender),
      age: d.age ? num(d.age) : null,
      birth_date: dateOnly(d.birthDate),
      interests: Array.isArray(d.interests) ? d.interests.map(String) : [],
      tags: Array.isArray(d.tags) ? d.tags.map(String) : [],
      level: num(d.level) || 1,
      coins: num(d.coins),
      gift_sent: num(d.giftSent),
      gift_received: num(d.giftReceived),
      online: false,
      last_seen: ts(d.lastSeen),
      status: d.status ?? null,
      streak: num(d.streak),
      last_reward_at: ts(d.lastRewardAt),
      suspended: d.suspended === true,
      suspended_reason: str(d.suspendedReason),
      onboarded_at: ts(d.onboardedAt),
      created_at: ts(d.createdAt) ?? new Date().toISOString(),
    });
  });

  log('profiles', await insert('profiles', rows));

  if (DRY) return;

  // Yazılmayan profil qalıbsa, ona bağlı hər şey xarici açar xətası verər.
  // Ona görə xəritədən yalnız bazada həqiqətən olanları saxlayırıq.
  const { data } = await db.from('profiles').select('id, firebase_uid');
  const live = new Set((data ?? []).map((r) => r.id));

  let dropped = 0;
  for (const [uid, id] of [...uidMap]) {
    if (!live.has(id)) {
      uidMap.delete(uid);
      dropped++;
    }
  }
  if (dropped) console.error(`  ! ${dropped} profil yazilmadi, onlara bagli melumat atlanir`);
}

// ─────────────────────────  2. İSTİFADƏÇİ ALT KOLLEKSİYALARI  ─────────────────

async function migrateUserSubcollections() {
  const follows = [];
  const blocks = [];
  const notifications = [];
  const tokens = [];
  const wallet = [];
  const gallery = [];

  for (const [uid, id] of uidMap) {
    const user = fs.collection('users').doc(uid);

    await each(user.collection('following'), (other) => {
      const to = uidMap.get(other);
      if (to && to !== id) follows.push({ follower_id: id, followee_id: to });
    });

    await each(user.collection('blocked'), (other) => {
      const to = uidMap.get(other);
      if (to) blocks.push({ blocker_id: id, blocked_id: to });
    });

    await each(user.collection('notifications'), (_, d) => {
      notifications.push({
        profile_id: id,
        type: str(d.type) ?? 'info',
        title: str(d.title),
        body: str(d.body ?? d.text),
        from_id: uidMap.get(d.fromUid ?? d.from) ?? null,
        data: d.data ?? {},
        read: d.read === true,
        created_at: ts(d.createdAt) ?? new Date().toISOString(),
      });
    });

    await each(user.collection('tokens'), (token, d) => {
      tokens.push({
        token,
        profile_id: id,
        platform: str(d.platform),
        created_at: ts(d.createdAt) ?? new Date().toISOString(),
      });
    });

    await each(user.collection('wallet'), (_, d) => {
      wallet.push({
        profile_id: id,
        amount: num(d.amount),
        reason: str(d.reason) ?? 'other',
        balance: d.balance != null ? num(d.balance) : null,
        created_at: ts(d.createdAt) ?? new Date().toISOString(),
      });
    });

    await each(user.collection('gallery'), (_, d) => {
      const url = str(d.url ?? d.photo);
      if (url) gallery.push({ profile_id: id, url, created_at: ts(d.createdAt) });
    });
  }

  log('follows', await insert('follows', follows));
  log('blocks', await insert('blocks', blocks));
  log('notifications', await insert('notifications', notifications));
  log('push_tokens', await insert('push_tokens', tokens));
  log('wallet_tx', await insert('wallet_tx', wallet));
  log('gallery', await insert('gallery', gallery));
}

// ─────────────────────────────  3. SÖHBƏTLƏR  ─────────────────────────────

async function migrateChats() {
  const chats = [];
  const members = [];
  const messages = [];
  const media = [];

  await each(fs.collection('chats'), async (chatId, d, ref) => {
    const id = uuid();
    idMap.chats.set(chatId, id);

    chats.push({
      id,
      firebase_id: chatId,
      last_message: str(d.lastMessage),
      last_sender_id: uidMap.get(d.lastSenderId) ?? null,
      created_at: ts(d.createdAt) ?? new Date().toISOString(),
      updated_at: ts(d.updatedAt) ?? ts(d.createdAt) ?? new Date().toISOString(),
    });

    for (const uid of d.members ?? []) {
      const pid = uidMap.get(uid);
      if (pid) members.push({ chat_id: id, profile_id: pid });
    }

    await each(ref.collection('messages'), async (msgId, m, msgRef) => {
      const mid = uuid();

      messages.push({
        id: mid,
        chat_id: id,
        sender_id: uidMap.get(m.senderId) ?? null,
        type: str(m.type) ?? 'text',
        text: str(m.text),
        read: m.read === true,
        deleted_at: m.deleted === true ? (ts(m.updatedAt) ?? new Date().toISOString()) : null,
        created_at: ts(m.createdAt) ?? ts(m.clientCreatedAt) ?? new Date().toISOString(),
      });

      // Şəkil/video ya mesajın içindədir, ya da media alt kolleksiyasında.
      for (const url of m.urls ?? (m.url ? [m.url] : [])) {
        media.push({ message_id: mid, chat_id: id, url: String(url), kind: str(m.type) ?? 'photo' });
      }

      await each(msgRef.collection('media'), (_, x) => {
        const url = str(x.url);
        if (url) media.push({ message_id: mid, chat_id: id, url, kind: str(x.kind) ?? 'photo' });
      });
    });
  });

  log('chats', await insert('chats', chats));
  log('chat_members', await insert('chat_members', members));
  log('messages', await insert('messages', messages));
  log('message_media', await insert('message_media', media));
}

// ─────────────────────────────  4. ANLAR  ─────────────────────────────

async function migrateMoments() {
  const moments = [];
  const likes = [];
  const comments = [];

  await each(fs.collection('moments'), async (momentId, d, ref) => {
    const author = uidMap.get(d.uid ?? d.authorId);
    if (!author) return;

    const id = uuid();
    idMap.moments.set(momentId, id);

    const urls = d.media ?? d.urls ?? (d.photo ? [d.photo] : []);

    moments.push({
      id,
      firebase_id: momentId,
      author_id: author,
      caption: str(d.caption ?? d.text) ?? '',
      media: urls.map((u) => (typeof u === 'string' ? { url: u, kind: 'photo' } : u)),
      visibility: str(d.visibility) ?? 'public',
      gift_total: num(d.giftTotal),
      created_at: ts(d.createdAt) ?? new Date().toISOString(),
    });

    await each(ref.collection('likes'), (uid) => {
      const pid = uidMap.get(uid);
      if (pid) likes.push({ moment_id: id, profile_id: pid });
    });

    await each(ref.collection('comments'), (_, c) => {
      const cauthor = uidMap.get(c.uid ?? c.authorId);
      if (!cauthor) return;
      comments.push({
        moment_id: id,
        author_id: cauthor,
        text: str(c.text) ?? '',
        created_at: ts(c.createdAt) ?? new Date().toISOString(),
      });
    });
  });

  log('moments', await insert('moments', moments));
  log('moment_likes', await insert('moment_likes', likes));
  log('moment_comments', await insert('moment_comments', comments));
}

// ─────────────────────────────  5. VİDEOLAR  ─────────────────────────────

async function migrateVideos() {
  const videos = [];
  const likes = [];
  const reposts = [];
  const comments = [];

  await each(fs.collection('videos'), async (videoId, d, ref) => {
    const author = uidMap.get(d.uid ?? d.authorId ?? d.ownerUid);
    if (!author) return;

    const id = uuid();
    idMap.videos.set(videoId, id);

    videos.push({
      id,
      firebase_id: videoId,
      author_id: author,
      video_url: str(d.videoUrl ?? d.url) ?? '',
      thumb_url: str(d.thumbUrl ?? d.thumb),
      caption: str(d.caption ?? d.title) ?? '',
      hashtags: Array.isArray(d.hashtags) ? d.hashtags.map(String) : [],
      duration: d.duration ? num(d.duration) : null,
      views: num(d.views),
      share_count: num(d.shares),
      visibility: str(d.visibility) ?? 'public',
      created_at: ts(d.createdAt) ?? new Date().toISOString(),
    });

    await each(ref.collection('likes'), (uid) => {
      const pid = uidMap.get(uid);
      if (pid) likes.push({ video_id: id, profile_id: pid });
    });

    await each(ref.collection('reposts'), (uid) => {
      const pid = uidMap.get(uid);
      if (pid) reposts.push({ video_id: id, profile_id: pid });
    });

    await each(ref.collection('comments'), (_, c) => {
      const cauthor = uidMap.get(c.uid ?? c.authorId);
      if (!cauthor) return;
      comments.push({
        video_id: id,
        author_id: cauthor,
        text: str(c.text) ?? '',
        created_at: ts(c.createdAt) ?? new Date().toISOString(),
      });
    });
  });

  log('videos', await insert('videos', videos));
  log('video_likes', await insert('video_likes', likes));
  log('video_reposts', await insert('video_reposts', reposts));
  log('video_comments', await insert('video_comments', comments));
}

// ─────────────────────────────  6. OTAQLAR  ─────────────────────────────
// Canlı siqnallaşma (rtc) köçürülmür — o məlumat bir neçə saniyəlikdir.

async function migrateRooms() {
  const rooms = [];
  const seats = [];
  const members = [];
  const messages = [];
  const gifts = [];

  await each(fs.collection('partyRooms'), async (roomId, d, ref) => {
    const host = uidMap.get(d.hostId ?? d.ownerUid);
    if (!host) return;

    const id = uuid();
    idMap.rooms.set(roomId, id);

    rooms.push({
      id,
      firebase_id: roomId,
      host_id: host,
      title: str(d.title) ?? '',
      topic: str(d.topic) ?? '',
      theme: str(d.theme) ?? 'default',
      video: d.video === true,
      locked: d.locked === true,
      password: str(d.password),
      seat_count: num(d.seatCount) || 8,
      gift_total: num(d.giftTotal),
      moderators: (d.moderators ?? []).map((u) => uidMap.get(u)).filter(Boolean),
      music: d.music ?? null,
      live: d.live !== false,
      created_at: ts(d.createdAt) ?? new Date().toISOString(),
    });

    // seats Firestore-da xəritə idi: {"0": {...}, "1": {...}}
    const seatMap = d.seats ?? {};
    const count = num(d.seatCount) || Object.keys(seatMap).length || 8;

    for (let i = 0; i < count; i++) {
      const seat = seatMap[String(i)] ?? {};
      seats.push({
        room_id: id,
        idx: i,
        profile_id: uidMap.get(seat.uid) ?? null,
        muted: seat.muted === true,
        locked: seat.locked === true,
      });
    }

    await each(ref.collection('members'), (uid, m) => {
      const pid = uidMap.get(uid);
      if (pid) members.push({
        room_id: id,
        profile_id: pid,
        joined_at: ts(m.at) ?? new Date().toISOString(),
      });
    });

    await each(ref.collection('messages'), (_, m) => {
      messages.push({
        room_id: id,
        sender_id: uidMap.get(m.senderId ?? m.uid) ?? null,
        text: str(m.text) ?? '',
        type: str(m.type) ?? 'text',
        created_at: ts(m.createdAt) ?? new Date().toISOString(),
      });
    });

    await each(ref.collection('gifts'), (_, g) => {
      const from = uidMap.get(g.fromUid ?? g.from);
      const to = uidMap.get(g.toUid ?? g.to);
      if (!from || !to) return;
      gifts.push({
        from_id: from,
        to_id: to,
        gift_id: str(g.gift ?? g.giftId) ?? 'gift',
        emoji: str(g.emoji),
        quantity: num(g.quantity) || 1,
        total: num(g.total),
        room_id: id,
        created_at: ts(g.createdAt ?? g.at) ?? new Date().toISOString(),
      });
    });
  });

  log('rooms', await insert('rooms', rooms));
  log('room_seats', await insert('room_seats', seats));
  log('room_members', await insert('room_members', members));
  log('room_messages', await insert('room_messages', messages));
  log('gifts_sent', await insert('gifts_sent', gifts));
}

// ─────────────────────────────  7. ŞİKAYƏTLƏR  ─────────────────────────────

async function migrateReports() {
  const rows = [];

  await each(fs.collection('reports'), (_, d) => {
    rows.push({
      reporter_id: uidMap.get(d.reporterUid) ?? null,
      target_id: uidMap.get(d.targetUid ?? d.target) ?? null,
      target_type: str(d.targetType) ?? 'user',
      target_ref: str(d.videoId ?? d.momentId ?? d.room),
      reason: str(d.reason) ?? '',
      note: str(d.note ?? d.text),
      handled: d.handled === true,
      created_at: ts(d.createdAt) ?? new Date().toISOString(),
    });
  });

  log('reports', await insert('reports', rows));
}

// ─────────────────────────────  İŞƏ SAL  ─────────────────────────────

console.log(DRY ? '— sınaq rejimi, heç nə yazılmır —\n' : '— köçürmə başlayır —\n');

await migrateUsers();
await migrateUserSubcollections();
await migrateChats();
await migrateMoments();
await migrateVideos();
await migrateRooms();
await migrateReports();

console.log('\nBitdi.');

// Sayğaclar tətiklə deyil, hazır məlumatla gəldiyi üçün burada bir dəfə düzəldilir.
if (!DRY) {
  const { error } = await db.rpc('recount_all');
  if (error) console.log('Sayğac yeniləməsi: ' + error.message);
  else console.log('Sayğaclar yeniləndi.');
}

process.exit(0);

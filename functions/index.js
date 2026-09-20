/**
 * VIBE — push bildiriş göndərən Cloud Functions.
 *
 * Deploy:
 *   cd functions && npm install
 *   firebase deploy --only functions
 *
 * Qeyd: Cloud Functions üçün Firebase "Blaze" planı tələb olunur.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/** İstifadəçinin bütün cihaz tokenlərini gətirir. */
async function tokensFor(uid) {
  const snap = await db.collection("users").doc(uid).collection("tokens").get();
  return snap.docs.map((doc) => doc.id).filter(Boolean);
}

/** İşləməyən tokenləri təmizləyir. */
async function cleanUp(uid, tokens, response) {
  const dead = [];
  response.responses.forEach((result, index) => {
    if (result.success) return;
    const code = result.error && result.error.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      dead.push(tokens[index]);
    }
  });

  await Promise.all(
    dead.map((token) =>
      db.collection("users").doc(uid).collection("tokens").doc(token).delete()
    )
  );
}

/** Bildirişi göndərir; token yoxdursa sakitcə çıxır. */
async function push(uid, { title, body, data }) {
  const tokens = await tokensFor(uid);
  if (tokens.length === 0) return;

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data || {}).map(([k, v]) => [k, String(v)])
    ),
    android: {
      priority: "high",
      notification: { channelId: "vibe_messages", sound: "default" },
    },
    apns: {
      payload: { aps: { sound: "default", badge: 1 } },
    },
  });

  await cleanUp(uid, tokens, response);
}

/** Bloklanma və ya söhbətin bağlı olması. */
async function isBlocked(chat, senderId, receiverId) {
  if (Array.isArray(chat.blockedBy) && chat.blockedBy.length > 0) return true;

  const doc = await db
    .collection("users")
    .doc(receiverId)
    .collection("blocked")
    .doc(senderId)
    .get();

  return doc.exists;
}

/** Mesajın qısa mətni. */
function preview(data) {
  const type = data.type || "text";
  if (type === "audio") return "🎤 Səsli mesaj";
  if (type === "sticker") return `${data.text || ""} Stiker`;
  const text = String(data.text || "");
  return text.length > 90 ? `${text.slice(0, 90)}…` : text;
}

// ============================================================
// YENİ ŞƏXSİ MESAJ
// ============================================================

exports.onNewMessage = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data && event.data.data();
    if (!message) return;

    const senderId = message.senderId;
    if (!senderId) return;

    const chatSnap = await db.collection("chats").doc(event.params.chatId).get();
    const chat = chatSnap.data() || {};
    const members = chat.members || [];

    const receiverId = members.find((uid) => uid !== senderId);
    if (!receiverId) return;

    if (await isBlocked(chat, senderId, receiverId)) return;

    const names = chat.memberNames || {};
    const senderName = names[senderId] || "VIBE";

    await push(receiverId, {
      title: senderName,
      body: preview(message),
      data: {
        type: "message",
        chatId: event.params.chatId,
        fromUid: senderId,
        fromName: senderName,
      },
    });
  }
);

// ============================================================
// DİGƏR BİLDİRİŞLƏR (izləmə, bəyənmə, hədiyyə)
// ============================================================

exports.onNewNotification = onDocumentCreated(
  "users/{uid}/notifications/{notificationId}",
  async (event) => {
    const note = event.data && event.data.data();
    if (!note) return;

    // Mesaj bildirişi onNewMessage tərəfindən göndərilir — təkrar olmasın.
    if (note.type === "message") return;

    await push(event.params.uid, {
      title: note.title || "VIBE",
      body: note.body || "",
      data: {
        type: note.type || "info",
        fromUid: note.fromUid || "",
        fromName: note.title || "",
      },
    });
  }
);

// ============================================================
// OTAQDA HƏDİYYƏ — otaq sahibinə bildiriş
// ============================================================

exports.onRoomGift = onDocumentCreated(
  "partyRooms/{roomId}/gifts/{giftId}",
  async (event) => {
    const gift = event.data && event.data.data();
    if (!gift) return;

    const roomSnap = await db
      .collection("partyRooms")
      .doc(event.params.roomId)
      .get();
    const room = roomSnap.data() || {};
    const hostId = room.hostId;

    if (!hostId || hostId === gift.fromUid) return;

    await push(hostId, {
      title: `${gift.fromName || "Kimsə"} hədiyyə göndərdi`,
      body: `${gift.emoji || "🎁"} ${gift.title || "Hədiyyə"} · ${
        gift.price || 0
      } coin`,
      data: {
        type: "gift",
        roomId: event.params.roomId,
        fromUid: gift.fromUid || "",
        fromName: gift.fromName || "",
      },
    });

    // Otaq sahibinin bildiriş mərkəzinə də düşsün.
    await db
      .collection("users")
      .doc(hostId)
      .collection("notifications")
      .add({
        type: "gift",
        title: `${gift.fromName || "Kimsə"} hədiyyə göndərdi`,
        body: `${gift.emoji || "🎁"} ${gift.title || ""}`,
        fromUid: gift.fromUid || "",
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
  }
);

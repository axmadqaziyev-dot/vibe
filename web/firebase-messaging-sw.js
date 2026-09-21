// VIBE — arxa plan bildirişləri.
//
// Firebase veb push-u MƏHZ bu adda faylı axtarır: /firebase-messaging-sw.js.
// Fayl olmasa `getToken()` xəta verir və bildiriş ümumiyyətlə qurulmur.
//
// Buradakı açarlar gizli deyil — onsuz da tətbiqin içində, hər cihazdadır.

importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBZPUVj_wUL59djtE2iLTVNXG9ZRK09ISk',
  authDomain: 'vibe-f9d13.web.app',
  projectId: 'vibe-f9d13',
  messagingSenderId: '719591915896',
  appId: '1:719591915896:web:d54dd234b4e12de006888d',
});

const messaging = firebase.messaging();

// Tətbiq bağlı olanda gələn bildiriş.
messaging.onBackgroundMessage(function (payload) {
  const data = payload.data || {};
  const note = payload.notification || {};

  const title = note.title || data.title || 'VIBE';
  const body = note.body || data.body || '';

  self.registration.showNotification(title, {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    // Eyni adamdan gələn mesajlar bir-birini əvəz etsin,
    // yoxsa bildiriş mərkəzi dolur.
    tag: data.fromUid || 'vibe',
    renotify: true,
    data: data,
  });
});

// Bildirişə basanda tətbiqi açır; açıqdırsa ona keçir.
self.addEventListener('notificationclick', function (event) {
  event.notification.close();

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
      for (const client of list) {
        if ('focus' in client) return client.focus();
      }
      if (clients.openWindow) return clients.openWindow('/');
    })
  );
});

// VIBE — minimal service worker.
//
// Yeganə vəzifəsi brauzerə tətbiqin quraşdırıla bilən (PWA) olduğunu
// bildirməkdir. Heç nə keşləmir: bütün sorğular birbaşa şəbəkəyə gedir,
// beləliklə yeni versiya yayımlananda istifadəçi köhnə faylları görmür.

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', function () {
  // Müdaxilə etmirik — brauzer sorğunu adi qaydada aparır.
});

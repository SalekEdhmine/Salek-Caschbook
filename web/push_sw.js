// Eigener, kleiner Service Worker nur fuer Web Push - laeuft parallel zu
// Flutters eigenem flutter_service_worker.js (anderer Scope: /push/), fasst
// diesen also nicht an und wird bei jedem "flutter build web" unveraendert
// mitkopiert (kein von Flutter generierter Dateiname).
self.addEventListener('push', function (event) {
  var data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {}

  var title = data.title || 'CashBook';
  var options = {
    body: data.body || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    data: { transactionId: data.transactionId || null, bookId: data.bookId || null },
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var txId = event.notification.data && event.notification.data.transactionId;
  var url = txId ? ('/?openTx=' + encodeURIComponent(txId)) : '/';

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
      for (var i = 0; i < list.length; i++) {
        var client = list[i];
        if ('focus' in client) {
          if ('navigate' in client) client.navigate(url);
          return client.focus();
        }
      }
      if (self.clients.openWindow) return self.clients.openWindow(url);
    })
  );
});

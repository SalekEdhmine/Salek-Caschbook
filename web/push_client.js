// Vanilla-JS-Bruecke fuer Web Push, absichtlich außerhalb von Dart/Flutter
// (dart:js_interop ruft diese Funktionen nur auf) - so kann sich hier nie ein
// Dart-Compile-Fehler einschleichen, und es bleibt unabhaengig von wechselnden
// Flutter-Web-Interop-APIs stabil.

function urlBase64ToUint8Array(base64String) {
  var padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  var base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  var rawData = atob(base64);
  var outputArray = new Uint8Array(rawData.length);
  for (var i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

window.getNotificationPermission = function () {
  if (typeof Notification === 'undefined') return 'unsupported';
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) return 'unsupported';
  return Notification.permission;
};

window.subscribeToPush = async function (token, apiBase) {
  if (typeof Notification === 'undefined' || !('serviceWorker' in navigator) || !('PushManager' in window)) {
    return 'unsupported';
  }
  try {
    var permission = await Notification.requestPermission();
    if (permission !== 'granted') return permission;

    var reg = await navigator.serviceWorker.register('/push_sw.js', { scope: '/push/' });
    await navigator.serviceWorker.ready;

    var keyRes = await fetch(apiBase + '/api/push/vapid-public-key');
    var keyData = await keyRes.json();
    var applicationServerKey = urlBase64ToUint8Array(keyData.key);

    var sub = await reg.pushManager.getSubscription();
    if (!sub) {
      sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: applicationServerKey,
      });
    }

    await fetch(apiBase + '/api/push/subscribe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': token },
      body: JSON.stringify(sub.toJSON()),
    });
    return 'granted';
  } catch (e) {
    console.error('Push-Abo fehlgeschlagen:', e);
    return 'error';
  }
};

window.unsubscribeFromPush = async function (token, apiBase) {
  if (!('serviceWorker' in navigator)) return;
  try {
    var reg = await navigator.serviceWorker.getRegistration('/push/');
    if (!reg) return;
    var sub = await reg.pushManager.getSubscription();
    if (!sub) return;
    var endpoint = sub.endpoint;
    await sub.unsubscribe();
    await fetch(apiBase + '/api/push/unsubscribe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': token },
      body: JSON.stringify({ endpoint: endpoint }),
    });
  } catch (e) {
    console.error('Push-Abmeldung fehlgeschlagen:', e);
  }
};

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

// Wartet, bis GENAU DIESE Registrierung (nicht irgendeine fuer die Seite
// zustaendige - "/push/" hat einen anderen Scope als die App selbst, daher
// ist navigator.serviceWorker.ready hier NICHT das Richtige und kann haengen
// bleiben) einen aktiven Worker hat.
function waitForActive(reg) {
  if (reg.active) return Promise.resolve();
  var worker = reg.installing || reg.waiting;
  if (!worker) return Promise.resolve();
  return new Promise(function (resolve) {
    worker.addEventListener('statechange', function onChange() {
      if (worker.state === 'activated' || worker.state === 'redundant') {
        worker.removeEventListener('statechange', onChange);
        resolve();
      }
    });
  });
}

function withTimeout(promise, ms, timeoutValue) {
  return Promise.race([
    promise,
    new Promise(function (resolve) { setTimeout(function () { resolve(timeoutValue); }, ms); }),
  ]);
}

// Gibt bei Erfolg 'granted' zurueck, sonst einen sprechenden Fehlercode
// (wird in der App als SnackBar angezeigt - ohne das koennten wir aus der
// Ferne nie sehen, an welcher Stelle es auf einem Geraet hakt). Die gesamte
// Funktion hat ein Zeitlimit, damit der "Aktivieren"-Button nie fuer immer
// haengen bleibt, egal was schiefgeht.
window.subscribeToPush = function (token, apiBase) {
  return withTimeout(_doSubscribe(token, apiBase), 15000, 'timeout: hat zu lange gedauert');
};

async function _doSubscribe(token, apiBase) {
  if (typeof Notification === 'undefined' || !('serviceWorker' in navigator) || !('PushManager' in window)) {
    return 'unsupported';
  }
  var permission;
  try {
    permission = await Notification.requestPermission();
  } catch (e) {
    return 'permission-request-failed: ' + e.message;
  }
  if (permission !== 'granted') return permission;

  var reg;
  try {
    reg = await navigator.serviceWorker.register('/push_sw.js', { scope: '/push/' });
    await waitForActive(reg);
  } catch (e) {
    return 'sw-register-failed: ' + e.message;
  }

  var applicationServerKey;
  try {
    var keyRes = await fetch(apiBase + '/api/push/vapid-public-key');
    if (!keyRes.ok) return 'vapid-fetch-failed: HTTP ' + keyRes.status;
    var keyData = await keyRes.json();
    if (!keyData.key) return 'vapid-fetch-failed: kein Schluessel in Antwort';
    applicationServerKey = urlBase64ToUint8Array(keyData.key);
  } catch (e) {
    return 'vapid-fetch-failed: ' + e.message;
  }

  var sub;
  try {
    sub = await reg.pushManager.getSubscription();
    if (!sub) {
      sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: applicationServerKey,
      });
    }
  } catch (e) {
    return 'subscribe-failed: ' + e.message;
  }

  try {
    var postRes = await fetch(apiBase + '/api/push/subscribe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': token },
      body: JSON.stringify(sub.toJSON()),
    });
    if (!postRes.ok) return 'server-save-failed: HTTP ' + postRes.status;
  } catch (e) {
    return 'server-save-failed: ' + e.message;
  }

  return 'granted';
}

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

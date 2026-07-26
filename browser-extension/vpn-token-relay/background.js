// Watches for the Cisco SAML session cookie and hands it to openconnect-saml's
// callback server, which is listening on loopback inside the Lima VM (Lima forwards
// the guest's 127.0.0.1:29786 to the Mac's, so "localhost" here really is the VM).
//
// Why this exists: an ASA in *embedded* SAML mode never redirects back to that
// callback. It finishes on its own page and leaves the token sitting in a cookie,
// so something has to carry it across. That something used to be you, pasting.
//
// Nothing is stored, logged, or sent anywhere except to loopback.

// Keep in sync with options.js (a service worker and an options page cannot share a
// plain script, and making both ES modules is not worth the load-order risk here).
const DEFAULTS = {
  host: "vpn.unisg.ch",
  cookieName: "acSamlv2Token",
  port: 29786,
  // openconnect-saml walks upward if 29786 is taken, so try a few above it.
  portRange: 8,
};

// Same token twice in a row means the cookie was merely re-read, not re-issued —
// relaying it again would hit a callback server that has already gone away.
let lastRelayed = null;

// get(DEFAULTS) already substitutes a default for every missing key.
const config = () => chrome.storage.sync.get(DEFAULTS);

function flash(text, color) {
  chrome.action.setBadgeText({ text });
  chrome.action.setBadgeBackgroundColor({ color });
  setTimeout(() => chrome.action.setBadgeText({ text: "" }), 8000);
}

function notify(title, message) {
  chrome.notifications.create({
    type: "basic",
    iconUrl: "icon128.png",
    title,
    message,
  });
}

async function relay(token, cfg) {
  if (!token || token === lastRelayed) return false;
  const ports = [];
  for (let i = 0; i < cfg.portRange; i++) ports.push(Number(cfg.port) + i);

  for (const port of ports) {
    const url =
      `http://127.0.0.1:${port}/callback?` +
      `${encodeURIComponent(cfg.cookieName)}=${encodeURIComponent(token)}`;
    try {
      // A callback server that is not the one we want simply is not there; a
      // connection refusal throws, so we just move to the next port.
      const res = await fetch(url, { method: "GET", cache: "no-store" });
      if (!res.ok) continue;
      lastRelayed = token;
      flash("ok", "#1a7f37");
      notify("VPN token relayed", `Sent to the VM on port ${port} — the tunnel should come up.`);
      return true;
    } catch (_) {
      /* nothing listening on this port */
    }
  }
  flash("!", "#b42318");
  notify(
    "VPN token not relayed",
    `Nothing answered on ports ${ports[0]}-${ports[ports.length - 1]}. ` +
      `Is 'cisco-vpn sso' still waiting in the VM?`,
  );
  return false;
}

async function readCookie(cfg) {
  const cookies = await chrome.cookies.getAll({
    domain: cfg.host,
    name: cfg.cookieName,
  });
  return cookies.length ? cookies[cookies.length - 1].value : null;
}

// The moment the ASA sets the token — this is what makes the login hands-free.
chrome.cookies.onChanged.addListener(async ({ cookie, removed }) => {
  if (removed) return;
  const cfg = await config();
  if (cookie.name !== cfg.cookieName) return;
  if (!cookie.domain.replace(/^\./, "").endsWith(cfg.host)) return;
  await relay(cookie.value, cfg);
});

// Manual fallback: click the toolbar icon while the "you may close this tab" page is
// open. Useful if the cookie was already set before the VM started listening.
chrome.action.onClicked.addListener(async () => {
  const cfg = await config();
  const token = await readCookie(cfg);
  if (!token) {
    notify("No token found", `No ${cfg.cookieName} cookie for ${cfg.host}. Sign in first.`);
    return;
  }
  lastRelayed = null; // an explicit click means "send it again, I meant it"
  await relay(token, cfg);
});

// Keep in sync with background.js (portRange is not exposed here).
const DEFAULTS = { host: "vpn.unisg.ch", cookieName: "acSamlv2Token", port: 29786 };
const $ = (id) => document.getElementById(id);

chrome.storage.sync.get(DEFAULTS).then((cfg) => {
  for (const k of Object.keys(DEFAULTS)) $(k).value = cfg[k];
});

$("save").addEventListener("click", async () => {
  const host = $("host").value.trim().replace(/^https?:\/\//, "").replace(/\/.*$/, "");
  const cfg = {
    host,
    cookieName: $("cookieName").value.trim() || DEFAULTS.cookieName,
    port: Number($("port").value) || DEFAULTS.port,
  };
  if (!cfg.host) {
    $("status").textContent = "gateway host is required";
    return;
  }

  // Only vpn.unisg.ch is granted at install time. Any other gateway needs its own
  // host permission before chrome.cookies will return anything for it — asking here
  // keeps the extension from holding blanket access to every site you visit.
  const origin = `https://${cfg.host}/*`;
  const granted =
    (await chrome.permissions.contains({ origins: [origin] })) ||
    (await chrome.permissions.request({ origins: [origin] }));
  if (!granted) {
    $("status").textContent = "cookie access for that host was declined";
    return;
  }

  await chrome.storage.sync.set(cfg);
  $("status").textContent = "saved";
  setTimeout(() => ($("status").textContent = ""), 2000);
});

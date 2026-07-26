# Cisco VPN token relay

Makes `cisco-vpn sso` hands-free: sign in to Entra ID in your normal browser, and the
session token reaches openconnect in the VM on its own — no bookmarklet, no pasting.

## Why it is needed

`vpn.unisg.ch` runs SAML in **embedded** mode. It never advertises
`sso-v2-browser-mode`, so it never redirects back to the `localhost:29786` callback
that `openconnect --external-browser` (and `openconnect-saml --headless`) waits on.
It just ends on a "you may now close this tab" page with the session token sitting in
a cookie named `acSamlv2Token`. Something has to carry that cookie the last inch.
This extension is that something.

The cookie is not `HttpOnly`, which is also why the bookmarklet in `cisco-vpn --help`
works — this is the same trick with the click removed.

## Install (Chrome / Edge / Brave, on the Mac)

1. `chrome://extensions` → enable **Developer mode**
2. **Load unpacked** → select this directory
   (`~/.local/share/chezmoi/browser-extension/vpn-token-relay`)
3. Optional: **Details → Extension options** to change gateway, cookie name, or port.

Firefox needs one change — swap `"service_worker": "background.js"` for
`"scripts": ["background.js"]` in `manifest.json`, then load it via
`about:debugging` → *This Firefox* → *Load Temporary Add-on*.

## Use

```sh
vm shell hsg                        # in the VM
cisco-vpn sso vpn.unisg.ch/priv     # prints the login URL, copies it to your Mac clipboard
```

Open the URL on the Mac, sign in. The moment Entra hands you back to the gateway, the
extension sees the cookie appear, POSTs it to the VM, and the tunnel comes up. A green
`ok` badge means it landed; a red `!` means nothing was listening (check that
`cisco-vpn sso` is still waiting, and that the port matches).

Click the toolbar icon to relay by hand — useful when the cookie was already set
before the VM started listening, e.g. because you were signed in from earlier.

## What it can reach

- Reads cookies for the configured gateway only (`https://vpn.unisg.ch/*` at install;
  any other host must be granted from the options page).
- Sends to `127.0.0.1` / `localhost` only. Lima forwards the guest's loopback to the
  Mac's, which is the only reason "localhost" reaches into the VM at all.
- Stores nothing but those three settings. The token is never persisted or logged.

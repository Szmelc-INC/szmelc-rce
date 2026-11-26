# Security Policy

## Reporting a vulnerability

Szmelc-RCE is a browser remote-control extension: a successful attacker can
read pages, click, type, and exfiltrate data. Please report vulnerabilities
privately via [GitHub Security Advisories](https://github.com/Szmelc-INC/szmelc-rce/security/advisories/new)
instead of opening a public issue.

## Known incident: CRX signing key committed to git history

The initial fork commits (≤ `ace249b`, 2026-11) contained
`key.local.crx.pem` — the private key used by `scripts/crx3.mjs` to sign
`dist/szmelc-rce.crx`. The repository is public, so the key was readable from
git history.

Impact: anyone with the old key could build CRX packages that Chrome
attributes to the key-derived extension id `jjkjjnpppmdojnfhlaeabnegfmpohbpd`.
This mattered only for drag-and-drop CRX installs signed with that key.
Unpacked (`Load unpacked`) installs and the manifest-pinned id
`fcoeoabgfenejglbffodgkkbkcdhcgfn` were **not** affected.

**Remediation — executed 2026-11-13 (commit after `cc77b68`):**

- The leaked key was deleted; a fresh 2048-bit signing key was generated
  (`npm run crx`) and is git-ignored — it will never be committed.
- CRX installs signed with the **new** key resolve to the extension id
  **`aikmpdfmhcddahdfoeiooaihhdcfmjak`**; the old id
  `jjkjjnpppmdojnfhlaeabnegfmpohbpd` is retired.
- `native-host/manifest.json` `allowed_origins` pins the *unpacked* id
  (`fcoeo…`) — no change was needed. If you pinned the retired CRX id in your
  own native-host manifest, update it to the new id.
- The old key's blob remains in git history but is dead: it signs nothing
  current, and new CRX builds are verifiable against the new key only.
  (History rewrite via `git filter-repo` remains optional for cloning hygiene.)

`npm run validate` fails while any `*.pem`/`.key` file is git-tracked, and
`npm run build` hard-fails if key-like files end up in `dist/`.

## Deployment guidance

- The extension grants the bridge full browser-control capability. Only point
  `bridgeUrl` at servers you control; prefer `wss://` for anything non-local.
- `bridgeAnonymous` (default on) sends a random device UUID as the identity
  token — it authenticates nothing. Use your own OAuth (`authorizeUrl` /
  `tokenUrl` / `oauthClientId`) or a bridge-side secret check for real auth.
- Managed org policy (`forceLoginOrgUUID` via `managed_schema.json`) always
  overrides the anonymous fallback.

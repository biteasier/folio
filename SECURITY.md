# Security policy

Markdown files can come from anywhere, so Folio treats every document as untrusted:

- The page runs under a strict Content-Security-Policy. Only Folio's own bundled scripts run:
  no `<script>` from a document, no inline event handlers, no `javascript:` links.
- No network access from documents except loading images. No frames, forms or plugins.
- Links never navigate the viewer. Web links open in your browser, other files in their own app.
- Folio has no analytics, no telemetry and no update checks. It never sends anything anywhere.

## Reporting a vulnerability

Please **don't open a public issue** for security problems. Use GitHub's private reporting:
**Security → Report a vulnerability** on this repository. Include your macOS version, the
Markdown file (or a minimal part of it) and what happened.

You should get a reply within a week. Fixes ship as a new release.

## Verifying a download

Each release lists the SHA-256 of its zip. Check it with:

```bash
shasum -a 256 Folio-*-arm64.zip
```

## Supported versions

Only the latest release gets security fixes.

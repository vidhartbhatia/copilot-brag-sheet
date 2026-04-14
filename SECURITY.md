# Security Policy

## Data Privacy

**All data stays on your machine.** Copilot Brag Sheet:

- Stores session records as local JSON files in your OS app-data directory
- Never transmits data to any external service, API, or telemetry endpoint
- Never sends data to Microsoft, GitHub, or any third party
- Has zero runtime dependencies — no hidden network calls
- Works entirely offline after installation

Your work log is yours. Period.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | ✅        |
| < 1.0   | ❌        |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT open a public issue**
2. Go to [Security Advisories](https://github.com/vidhartbhatia/copilot-brag-sheet/security/advisories/new)
3. Click **"Report a vulnerability"**
4. Provide details about the issue

I'll respond within 7 days and work with you on a fix before any public disclosure.

## Scope

Since this extension runs locally with no network access, the primary security concerns are:

- **Path traversal** — prevented via session ID validation (`/^[\w-]+$/`)
- **File injection** — prevented via atomic writes and input sanitization
- **Sensitive data in logs** — user controls what summaries they write; session data is auto-captured from the working directory only

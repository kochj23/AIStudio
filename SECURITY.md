# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in AI Studio, please report it responsibly:

1. **Do not** open a public GitHub issue
2. Email: [Create a private security advisory](https://github.com/kochj23/AIStudio/security/advisories/new)
3. Include: description, steps to reproduce, potential impact

## Security Features

- No app sandbox (direct distribution via DMG)
- Network client entitlement for localhost backend communication
- SecureLogger sanitizes all log output (redacts API keys, tokens, PII)
- Input validation via SecurityUtils (file paths, URLs, prompts)
- Base64 image validation (PNG/JPEG magic byte checking)
- File size caps (50MB images, 100MB audio)
- No third-party Swift dependencies

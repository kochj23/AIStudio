# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 2.3.x   | Yes       |
| < 2.0   | No        |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT open a public GitHub issue**
2. Email: kochj23 (via GitHub)
3. Include: description, steps to reproduce, potential impact

We aim to respond within 48 hours and provide a fix within 7 days for critical issues.

## Security Features

- **Local Generation**: All image/media generation runs locally via connected backends
- **No Cloud Upload**: Generated media and prompts never leave your machine
- **No Telemetry**: Zero analytics, crash reporting, or usage tracking
- **Backend Isolation**: Each backend connection is independently managed
- **Auto-Save Security**: Generated files saved only to user-specified directories

## Best Practices

- Never hardcode credentials or API keys
- Report suspicious behavior immediately
- Keep dependencies updated
- Review all code changes for security implications

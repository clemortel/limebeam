# Inter font

Drop the Inter family `.ttf` files here, then uncomment the `fonts:` block in
`iptv_ui/pubspec.yaml`:

- `Inter-Regular.ttf` (400)
- `Inter-SemiBold.ttf` (600)
- `Inter-Bold.ttf` (700)

Download: https://rsms.me/inter/ (OFL licensed).

Until then the app uses the system fallback (SF Pro on iOS) — see
`AppType.fontFamilyFallback`. No code change is needed to ship without Inter.

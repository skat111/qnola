# Qnola Liquid Glass Customization

Checked against Apple Developer documentation on 2026-06-03.

## Official API Surface

Use Apple's native SwiftUI Liquid Glass APIs:

- `glassEffect(_:in:)`
- `GlassEffectContainer`
- `Glass.tint(_:)`
- `Glass.interactive(_:)`
- `.buttonStyle(.glass)`
- `.buttonStyle(.glassProminent)`

The official documentation describes Liquid Glass as a SwiftUI material for
custom views that reflects and blurs content behind it, reacts to touch and
pointer interaction, and should be combined through `GlassEffectContainer` for
groups of related glass elements.

## Qnola Message Texture Modes

Qnola exposes these message texture presets:

- `system`: keep Telegram's current bubble rendering.
- `liquidGlass`: official SwiftUI Liquid Glass on iOS 26+ with fallback material.
- `liquidGlassTinted`: Liquid Glass with user-selected tint.
- `liquidGlassMono`: black-and-white Qnola style.
- `liquidGlassProminent`: stronger visual treatment for outgoing messages.

## Guardrails

- Gate all Liquid Glass symbols with `#if compiler(>=6.2)` and `#available(iOS 26.0, *)`.
- Do not mention `.glassEffect`, `.glass`, or `.glassProminent` in code compiled with older SDKs unless guarded.
- Use fallback material on earlier iOS versions.
- Do not fake Liquid Glass with arbitrary dark blur and call it official.
- Keep grouped glass bubbles inside `GlassEffectContainer` where possible.
- Avoid applying Liquid Glass to every onscreen cell without profiling; message lists can contain many visible nodes.


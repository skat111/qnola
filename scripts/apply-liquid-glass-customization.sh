#!/usr/bin/env bash
set -euo pipefail

echo "Applying Qnola Liquid Glass customization pack."

mkdir -p Qnola/LiquidGlass

cat > Qnola/LiquidGlass/QnolaLiquidGlassConfig.json <<'JSON'
{
  "messageTexture": {
    "defaultPreset": "liquidGlassMono",
    "availablePresets": [
      "system",
      "liquidGlass",
      "liquidGlassTinted",
      "liquidGlassMono",
      "liquidGlassProminent"
    ],
    "cornerRadius": 18,
    "containerSpacing": 14,
    "interactiveIncoming": false,
    "interactiveOutgoing": true,
    "fallbackMaterial": "ultraThinMaterial"
  },
  "composerTexture": {
    "enabled": true,
    "preset": "liquidGlass",
    "interactive": true
  },
  "settingsTexture": {
    "enabled": true,
    "preset": "liquidGlassTinted"
  }
}
JSON

cat > Qnola/LiquidGlass/QnolaLiquidGlassSurface.swift <<'SWIFT'
import SwiftUI

public enum QnolaLiquidGlassPreset: String, Codable, CaseIterable, Sendable {
    case system
    case liquidGlass
    case liquidGlassTinted
    case liquidGlassMono
    case liquidGlassProminent
}

public struct QnolaLiquidGlassStyle: Codable, Equatable, Sendable {
    public var preset: QnolaLiquidGlassPreset
    public var cornerRadius: CGFloat
    public var tintRed: Double
    public var tintGreen: Double
    public var tintBlue: Double
    public var tintOpacity: Double
    public var interactive: Bool

    public init(
        preset: QnolaLiquidGlassPreset = .liquidGlassMono,
        cornerRadius: CGFloat = 18,
        tintRed: Double = 1,
        tintGreen: Double = 1,
        tintBlue: Double = 1,
        tintOpacity: Double = 0.18,
        interactive: Bool = false
    ) {
        self.preset = preset
        self.cornerRadius = cornerRadius
        self.tintRed = tintRed
        self.tintGreen = tintGreen
        self.tintBlue = tintBlue
        self.tintOpacity = tintOpacity
        self.interactive = interactive
    }
}

public struct QnolaLiquidGlassSurface<Content: View>: View {
    private let style: QnolaLiquidGlassStyle
    private let content: Content

    public init(style: QnolaLiquidGlassStyle, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .modifier(QnolaLiquidGlassModifier(style: style))
    }
}

private struct QnolaLiquidGlassModifier: ViewModifier {
    let style: QnolaLiquidGlassStyle

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            official(content: content)
        } else {
            fallback(content: content)
        }
        #else
        fallback(content: content)
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private func official(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
        switch style.preset {
        case .system:
            content
        case .liquidGlass:
            content.glassEffect(style.interactive ? .regular.interactive() : .regular, in: shape)
        case .liquidGlassTinted:
            content.glassEffect(configuredGlass(tint: tintColor), in: shape)
        case .liquidGlassMono:
            content.glassEffect(configuredGlass(tint: Color.white.opacity(0.16)), in: shape)
        case .liquidGlassProminent:
            content.glassEffect(configuredGlass(tint: Color.white.opacity(0.28)), in: shape)
        }
    }

    @available(iOS 26.0, *)
    private func configuredGlass(tint: Color) -> Glass {
        var glass = Glass.regular.tint(tint)
        if style.interactive {
            glass = glass.interactive()
        }
        return glass
    }
    #endif

    private func fallback(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
        return content
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var tintColor: Color {
        Color(
            red: style.tintRed,
            green: style.tintGreen,
            blue: style.tintBlue
        ).opacity(style.tintOpacity)
    }
}
SWIFT

cat > Qnola/LiquidGlass/README.txt <<'TEXT'
Qnola Liquid Glass customization pack.

This pack defines official SwiftUI Liquid Glass surfaces for iOS 26+ and a
fallback material for earlier systems. Telegram iOS chat cells are UIKit/Texture,
so integration into message bubbles must be done by a dedicated patch that bridges
or hosts this SwiftUI surface in the bubble renderer.
TEXT

echo "Qnola Liquid Glass customization pack applied."


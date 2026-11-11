# Bathys Design System

Source of truth in code: `app/Sources/Bathys/DesignSystem.swift` (tokens and shared controls) and `app/Sources/Bathys/FlatArt.swift` (illustrations). Every screen uses these; no stock SwiftUI control appears unstyled.

## World

A calm, deep-navy working surface beside a playful flat-illustrated ocean. The right side is a precise tool (Apple / CleanMyMac quality bar); the left pane carries the character: yellow submarine mascot, fish, corals and seabed drawn as flat vectors, animated only when the window is visible and active. The ocean reflects real state: the submarine dives with scan progress, debris appears with junk found.

## Color

Restrained strategy: tinted neutrals plus one accent per module, used for actions, selection and state only.

| Token | Value | Use |
|---|---|---|
| `DS.Ink.ground` | `#0A1220` | Workspace top |
| `DS.Ink.groundDeep` | `#070D17` | Workspace bottom, sheets |
| `DS.Ink.primary` | white 96% | Titles, values |
| `DS.Ink.secondary` | white 70% | Body, descriptions |
| `DS.Ink.tertiary` | white 50% | Captions, paths (AA on ground) |
| `DS.Ink.surface` / `surfaceHover` / `surfaceRaised` | white 4.5% / 7.5% / 6.5% | Rows, cards, controls |
| `DS.Ink.hairline` / `hairlineStrong` | white 7.5% / 14% | 1px borders, separators |
| `DS.Ink.onAccent` | `#08121F` | Text on filled accent |

Module accents (`BathysPalette`): Deep Clean `sky #3DADF0`, Sonar `amber #F0AD42`, Uninstaller `coral #E6735C`, Performance `emerald #3DC287`. Category tints: teal, steel, yellow, slate. Semantic: emerald = safe/done, amber = attention/needs access, coral = destructive/permanent.

## Typography

SF Pro for interface text; SF Rounded only for display titles and large numbers (echoes the rounded illustrations).

| Token | Spec | Use |
|---|---|---|
| `display` | 30 semibold rounded | Screen titles |
| `bigNumber` | 44 semibold rounded, tabular | Bytes found / items scanned |
| `title` | 20 semibold rounded | Card titles, app name, sheet titles |
| `headline` | 14 semibold | Row titles |
| `body` / `bodyEmphasis` | 13 regular / medium | Descriptions, list names |
| `caption` / `captionEmphasis` | 11.5 regular / semibold | Paths, metadata, badges |
| `control` | 13 medium | Buttons, segments |
| `value` | 13 medium tabular | Sizes in lists |

Sentence case everywhere; no eyebrows, no gradient text, no emoji as icons (SF Symbols only).

## Space and shape

Base-4 scale: 4, 8, 12, 16, 20, 24, 32, 40. Workspace gutter 40, top 28. Radii: controls 9, rows 14, cards 20, sheets 24; capsules only for primary buttons and badges. Depth comes from surface tint and hairlines, not shadows; the only shadow is the soft accent glow under the primary round action.

## Components

- `DSButtonStyle` (`.ds(kind, size, tint)`): primary (filled accent capsule, dark label), secondary (surface + hairline), quiet (accent text), destructive. Heights 28 / 32 / 40. Hover lightens, press scales 0.97 and darkens, disabled 40%.
- `CircularActionOrbButton`: the one primary action per module, 104pt accent disc with soft glow, centered at the bottom of the workspace.
- `BathysRoundIconButton`: 26–32pt rounded-square icon button; reveal-in-Finder and trash actions appear on row hover.
- `BathysRoundCheckButton`: 18pt rounded-square checkbox, filled accent when on.
- `DSToggleStyle`, `DSSegmented`, `DSSearchField`: custom switch, segmented control and search field.
- `DSBadge`: 22pt capsule, accent text on 13% accent fill.
- `DSProgressBar`, `DSMeter`: thin bars for scan depth, disk and RAM.
- `dsSurface(radius:isHovered:isSelected:tint:)`: the shared row/card surface.
- Lists scroll inside a fade mask so no row is ever cut hard; long text wraps or moves to a tooltip instead of truncating important words.

## Motion

Transitions 160–280 ms (`DS.Motion.quick`, `DS.Motion.standard`), conveying state only. The ocean scene runs at 30 fps (60 during operations), pauses when the window is hidden or inactive, and respects Reduce Motion.

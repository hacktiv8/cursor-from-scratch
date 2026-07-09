---
name: Waktu
description: Glanceable realtime date and time for wall displays
colors:
  field-lime: "#b8f000"
  lime-bright: "#c8f520"
  lime-deep: "#9ad400"
  grove-mid: "#7a9e00"
  mist-green: "#f4ffe8"
  field-ink: "#14200a"
  field-soft: "#2a3d14"
typography:
  display:
    fontFamily: "Fraunces, Georgia, serif"
    fontSize: "clamp(2.75rem, 9vw, 5rem)"
    fontWeight: 500
    lineHeight: 1
    letterSpacing: "-0.03em"
  headline:
    fontFamily: "Fraunces, Georgia, serif"
    fontSize: "clamp(1.75rem, 4vw, 2.25rem)"
    fontWeight: 600
    lineHeight: 1
    letterSpacing: "-0.02em"
  title:
    fontFamily: "Fraunces, Georgia, serif"
    fontSize: "clamp(1.5rem, 3.5vw, 2rem)"
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: "-0.02em"
  body:
    fontFamily: "Sora, Segoe UI, sans-serif"
    fontSize: "clamp(1rem, 2.2vw, 1.2rem)"
    fontWeight: 500
    lineHeight: 1.2
    letterSpacing: "0.01em"
  clock:
    fontFamily: "Sora, Segoe UI, sans-serif"
    fontSize: "clamp(2.75rem, 10vw, 4.5rem)"
    fontWeight: 600
    lineHeight: 1
    letterSpacing: "-0.04em"
    fontFeature: "tabular-nums"
spacing:
  xs: "0.4rem"
  sm: "0.85rem"
  md: "1.75rem"
  lg: "2.5rem"
  xl: "3.5rem"
  stage: "2rem"
components:
  brand-wordmark:
    textColor: "{colors.field-ink}"
    typography: "{typography.display}"
  zone-clock:
    textColor: "{colors.field-ink}"
    typography: "{typography.clock}"
  zone-clock-local:
    textColor: "{colors.field-ink}"
    typography: "{typography.clock}"
  world-clock:
    textColor: "{colors.field-ink}"
    typography: "{typography.clock}"
---

# Design System: Waktu

## 1. Overview

**Creative North Star: "The Lime Field Clock"**

Waktu is a wall-facing time surface: one composition, one job, no chrome. The entire viewport is a lime field; dark leaf ink sits on it so time reads at a glance from across a room. Personality is calm, clear, and steady — a quiet fixture, not a product tour.

Density is low and hierarchy is typographic. Fraunces carries place names and the brand; Sora carries the ticking digits. Atmosphere (soft radial light, slow drift, light grain) supports presence without competing with the clock. Local Indonesian zone is scaled up and neighbors dim; world cities sit quieter below.

This system explicitly rejects SaaS marketing pages — hero stacks, feature grids, CTAs, and card chrome that compete with the clock. If a new element would belong on a landing page, it does not belong here.

**Key Characteristics:**
- Drenched Field Lime surface; ink on lime, never lime-on-white cards
- Typographic and ambient — type is the UI; no buttons, cards, or nav chrome
- Glance hierarchy: brand → local Indonesia zone → other WIB/WITA/WIT → world cities
- Flat / tonal depth only — scale, opacity, atmosphere; never drop shadows
- Motion is slow and optional; `prefers-reduced-motion` removes all of it

## 2. Colors

A single saturated lime carries the surface; deep green-black ink carries every readable mark.

### Primary
- **Field Lime** (#b8f000): The body and brand field. The surface *is* this color. Atmosphere gradients orbit it (`#c8f520` bright, `#9ad400` deep, `#7a9e00` mid grove, `#f4ffe8` mist).

### Neutral
- **Field Ink** (#14200a): Primary text — brand, zone labels, clocks, local-zone emphasis. Always on Field Lime.
- **Field Soft** (#2a3d14): Secondary text — zone names, dates, non-local soft labels. Same hue family as ink; never gray.

### Named Rules
**The Drenched Field Rule.** Field Lime owns 30–100% of the viewport. Never invert to a white/cream page with lime accents.

**The Ink-On-Lime Rule.** All readable text uses Field Ink or Field Soft on Field Lime. Never light text on lime, never gray text on lime.

## 3. Typography

**Display Font:** Fraunces (with Georgia)
**Body Font:** Sora (with Segoe UI, sans-serif)

**Character:** Soft optical serif for place and brand; geometric sans with tabular numerals for time. The pairing is typographic and ambient — monumental at wall scale, never UI-chrome.

### Hierarchy
- **Display** (500, `clamp(2.75rem, 9vw, 5rem)`, line-height 1, tracking `-0.03em`): Brand wordmark "Waktu" only.
- **Headline** (600, `clamp(1.75rem, 4vw, 2.25rem)` / local `clamp(2.25rem, 5.5vw, 3rem)`, line-height 1): Indonesia zone labels (WIB / WITA / WIT).
- **Title** (600, `clamp(1.5rem, 3.5vw, 2rem)` section; `clamp(1.25rem, 3vw, 1.5rem)` city): "Kota dunia" and world city names.
- **Body** (500, `clamp(1rem, 2.2vw, 1.2rem)` names; dates slightly larger on local): Zone full names and dates in Field Soft (ink when local).
- **Clock** (600, Indonesia `clamp(2.75rem, 10vw, 4.5rem)` / local up to `6rem`; world smaller clamps; tracking `-0.04em` floor; `font-variant-numeric: tabular-nums`): The glance target. Letter-spacing must never go tighter than `-0.04em`.

### Named Rules
**The Glance Type Rule.** Clock digits are the largest continuous text on screen after (or with) the brand. If a decoration out-sizes the clock, delete the decoration.

**The Tabular Time Rule.** Every clock uses tabular numerals so digits do not jump as seconds tick.

## 4. Elevation

Flat and tonal. No `box-shadow` vocabulary. Depth comes from the lime atmosphere field, local-zone scale (`1.08`), and non-local opacity (`0.55`). Surfaces do not lift; hierarchy does.

### Named Rules
**The No-Shadow Rule.** Drop shadows are forbidden. If depth is needed, use scale, opacity, or atmosphere — never a card shadow.

## 5. Components

Components are typographic blocks, not chrome. Feel: **typographic and ambient**.

### Brand Wordmark
- **Shape:** No box, no radius, no border
- **Type:** Display Fraunces, Field Ink
- **Role:** Hero-level brand signal above the clocks

### Indonesia Zone Clock
- **Shape:** Bare `<article>` — text only, centered
- **Label:** Headline Fraunces; name + date Field Soft (ink when local)
- **Clock:** Sora tabular, Field Ink
- **Local state:** `zone--local` — larger type, `aria-current="true"`; siblings at `opacity: 0.55`; scale `1.08` from `800px` up (no scale in stacked mobile column)
- **Motion:** Staggered settle (transform only, `backwards` fill) on load so opacity stays free for local dimming; opacity/transform transition `0.35s ease` for local highlight. Content is visible by default — never gate on opacity.

### World City Clock
- **Shape:** Bare grid cell — text only
- **Hierarchy:** Quieter than Indonesia zones; six cities, responsive columns (2 → 3 → 6)
- **Clock:** Smaller Sora tabular clamps; never compete with local Indonesia time

### Buttons / Cards / Inputs / Navigation
Not used. Do not introduce SaaS chrome. If interaction is ever required, invent the minimum typographic control — never a marketing CTA card.

## 6. Do's and Don'ts

### Do:
- **Do** keep Field Lime as the full-bleed body background and Field Ink / Field Soft as the only text colors.
- **Do** make the local Indonesia zone the clearest glance target via scale and sibling dimming.
- **Do** use Fraunces for brand and place labels; Sora + tabular nums for every clock.
- **Do** honor `prefers-reduced-motion: reduce` by removing atmosphere drift, rise, settle, and local scale.
- **Do** keep letter-spacing on display/clock type at or above `-0.04em`.

### Don't:
- **Don't** build SaaS marketing pages — hero stacks, feature grids, CTAs, and card chrome that compete with the clock.
- **Don't** use drop shadows, glass cards, or bordered card grids.
- **Don't** put gray body text on lime; Field Soft is the only muted text.
- **Don't** add tiny uppercase tracked eyebrows, numbered section markers, or gradient text.
- **Don't** invent buttons or nav for a glance-only wall display.

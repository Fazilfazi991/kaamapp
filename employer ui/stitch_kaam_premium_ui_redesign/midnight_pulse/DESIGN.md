---
name: Midnight Pulse
colors:
  surface: '#0f1322'
  surface-dim: '#0f1322'
  surface-bright: '#353849'
  surface-container-lowest: '#090d1c'
  surface-container-low: '#171b2a'
  surface-container: '#1b1f2f'
  surface-container-high: '#252939'
  surface-container-highest: '#303445'
  on-surface: '#dfe1f7'
  on-surface-variant: '#ddbfc7'
  inverse-surface: '#dfe1f7'
  inverse-on-surface: '#2c3040'
  outline: '#a58a91'
  outline-variant: '#574147'
  surface-tint: '#ffb0c9'
  primary: '#ffb0c9'
  on-primary: '#640035'
  primary-container: '#f65f9d'
  on-primary-container: '#600032'
  inverse-primary: '#ae2565'
  secondary: '#c9bfff'
  on-secondary: '#2f009c'
  secondary-container: '#470cd9'
  on-secondary-container: '#baaeff'
  tertiary: '#ffb0cd'
  on-tertiary: '#571936'
  tertiary-container: '#cf7d9d'
  on-tertiary-container: '#541734'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffd9e3'
  primary-fixed-dim: '#ffb0c9'
  on-primary-fixed: '#3e001e'
  on-primary-fixed-variant: '#8d004d'
  secondary-fixed: '#e5deff'
  secondary-fixed-dim: '#c9bfff'
  on-secondary-fixed: '#1a0063'
  on-secondary-fixed-variant: '#4503d7'
  tertiary-fixed: '#ffd9e4'
  tertiary-fixed-dim: '#ffb0cd'
  on-tertiary-fixed: '#3c0321'
  on-tertiary-fixed-variant: '#72304d'
  background: '#0f1322'
  on-background: '#dfe1f7'
  surface-variant: '#303445'
typography:
  display-lg:
    fontFamily: Manrope
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Manrope
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
  headline-md:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Manrope
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Manrope
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 8px
  sm: 16px
  md: 24px
  lg: 40px
  xl: 64px
  container-margin-mobile: 20px
  container-margin-desktop: 80px
  gutter: 24px
---

## Brand & Style

The design system embodies a "Midnight Pulse" aesthetic—a sophisticated blend of high-end corporate professionalism and modern tech-driven matchmaking. It is designed for the privacy-conscious professional in the UAE/GCC market, where status, security, and elegance are paramount.

The style is **Corporate Modern with Glassmorphic accents**. It leverages deep navy depths to provide a sense of stability and security, while vibrant pink and purple accents inject energy and "the spark" of a perfect career match. The visual language is clean, spacious, and premium, avoiding the cluttered "job board" feel in favor of a curated, high-touch platform experience.

Key attributes:
- **Privacy-First:** Secure, dark, and protective.
- **Matchmaking-Inspired:** Warm accents that highlight human connection.
- **Elite:** Polished finishes and generous spacing reflecting a high-tier service.

## Colors

The palette is built on a "Deep Midnight" foundation, ensuring that the dark mode is comfortable for prolonged use while providing high contrast for pink highlights.

- **Primary Pink (#F65F9D):** Used for primary calls to action, brand-defining moments, and successful "matches."
- **Accent Purple (#6E4CFF):** Used for secondary interactions, categories, and to distinguish recruiter-facing features from candidate-facing ones.
- **The Surface Scale:** We use a four-tier elevation system. From the deepest `#090B1A` background to the `#202542` elevated surface, these layers create physical depth without needing heavy shadows.
- **Semantic Colors:** Success green (`#45D6A3`) and Warning orange (`#FFC46B`) are used sparingly for status indicators to maintain the premium dark aesthetic.

## Typography

**Manrope** is the exclusive typeface for this design system. It was selected for its modern, geometric construction that remains highly legible in dark interfaces. 

- **Headlines:** Use Bold and ExtraBold weights to create a strong hierarchy against the dark background.
- **Body Text:** Primarily uses the Regular weight. Secondary text should utilize the `#B8BBD0` color rather than a lighter font weight to maintain readability.
- **Arabic Support:** Manrope provides excellent character balance for English/Arabic bilingual interfaces, essential for the UAE/GCC market. 
- **Readability:** On mobile, prioritize `body-md` for all descriptions to ensure comfort in low-light environments.

## Layout & Spacing

This design system uses a **Fluid Grid** model with a mobile-first philosophy.

- **Mobile (Up to 768px):** A 4-column grid with 20px side margins. Cards are typically full-width or 2-column.
- **Tablet (768px - 1024px):** An 8-column grid with 40px margins.
- **Desktop (1024px+):** A 12-column grid with a max-width of 1280px, centered with 80px margins.

**The 8px Rhythm:** All spacing (padding, margins, gap) must be a multiple of 8px. Use 24px (`md`) as the default padding for cards and sections to create the "premium" airy feel.

## Elevation & Depth

Hierarchy is established through **Tonal Layering** and **Glassmorphism**, rather than traditional heavy shadows.

1.  **Base Layer:** `#090B1A` (Canvas background).
2.  **Surface Layer:** `#11142A` (Sidebars, navigation rails).
3.  **Card Layer:** `#181C35` (Main content containers).
4.  **Interactive/Elevated Layer:** `#202542` (Hover states and modals).

**Glassmorphism:** Headers and floating navigation bars use a background blur (20px) and 60% opacity of the `Surface` color. A subtle 1px border (`#2A2E4A`) should be applied to all cards and glass elements to define edges against the dark background. 

**Shadows:** When used for top-level modals, use a large, soft, 25% opacity black shadow with no spread to create a gentle lift.

## Shapes

The shape language is defined by **significant roundedness**, evoking friendliness and modern technology.

- **Primary Cards:** Always use a **24px** corner radius. This is a signature element of the design system.
- **Buttons and Inputs:** Use a **12px** radius. This differentiates interactive elements from structural containers.
- **Avatars:** Use a **squircle** or full circle to keep the look organic.
- **Chips/Badges:** Use a pill shape (full round) for status indicators and job tags.

## Components

### Buttons
- **Primary:** Background `#F65F9D`, text `#FFFFFF`. High-gloss finish or subtle gradient from Primary Pink to a slightly darker shade.
- **Secondary:** Transparent background with a 1.5px border of `#6E4CFF`.
- **Ghost:** No background, `#B8BBD0` text, turns `#FFFFFF` on hover.

### Cards
Cards are the heart of the "matchmaking" experience.
- Background: `#181C35`.
- Border: 1px solid `#2A2E4A`.
- Padding: 24px.
- Hover State: Background shifts to `#202542` with a subtle Primary Pink glow (2px outer blur).

### Input Fields
- Background: `#11142A`.
- Border: 1px solid `#2A2E4A`.
- Focus State: Border color becomes `#F65F9D` with a subtle glow.
- Placeholder Text: `#7E829F`.

### Glass Headers
- Background: `#090B1A` at 70% opacity.
- Backdrop Filter: blur(20px).
- Border-bottom: 1px solid `#2A2E4A`.

### Chips & Tags
- Used for skills and job categories.
- Style: Pill-shaped, `#202542` background, `#B8BBD0` text. If "selected" or "matched," the background becomes a 15% opacity Primary Pink with Primary Pink text.

### Icons
- Use clean, thin line icons (2px stroke).
- Primary icons should use `#B8BBD0`, switching to `#F65F9D` for active states.
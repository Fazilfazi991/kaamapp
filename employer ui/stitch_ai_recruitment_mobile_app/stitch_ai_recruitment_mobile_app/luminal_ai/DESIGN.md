---
name: Luminal AI
colors:
  surface: '#141218'
  surface-dim: '#141218'
  surface-bright: '#3b383e'
  surface-container-lowest: '#0f0d13'
  surface-container-low: '#1d1b20'
  surface-container: '#211f24'
  surface-container-high: '#2b292f'
  surface-container-highest: '#36343a'
  on-surface: '#e6e0e9'
  on-surface-variant: '#cbc4d2'
  inverse-surface: '#e6e0e9'
  inverse-on-surface: '#322f35'
  outline: '#948e9c'
  outline-variant: '#494551'
  surface-tint: '#cfbcff'
  primary: '#cfbcff'
  on-primary: '#381e72'
  primary-container: '#6750a4'
  on-primary-container: '#e0d2ff'
  inverse-primary: '#6750a4'
  secondary: '#cdc0e9'
  on-secondary: '#342b4b'
  secondary-container: '#4d4465'
  on-secondary-container: '#bfb2da'
  tertiary: '#e7c365'
  on-tertiary: '#3e2e00'
  tertiary-container: '#c9a74d'
  on-tertiary-container: '#503d00'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e9ddff'
  primary-fixed-dim: '#cfbcff'
  on-primary-fixed: '#22005d'
  on-primary-fixed-variant: '#4f378a'
  secondary-fixed: '#e9ddff'
  secondary-fixed-dim: '#cdc0e9'
  on-secondary-fixed: '#1f1635'
  on-secondary-fixed-variant: '#4b4263'
  tertiary-fixed: '#ffdf93'
  tertiary-fixed-dim: '#e7c365'
  on-tertiary-fixed: '#241a00'
  on-tertiary-fixed-variant: '#594400'
  background: '#141218'
  on-background: '#e6e0e9'
  surface-variant: '#36343a'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  display-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  container-padding: 1.5rem
  stack-gap: 1rem
  section-gap: 2rem
  element-gap: 0.5rem
  safe-area-bottom: 2.5rem
---

## Brand & Style

The design system is engineered for a premium AI-driven recruitment experience. It targets high-tier professionals and tech-forward recruiters, evoking feelings of innovation, exclusivity, and precision. 

The visual language is a blend of **Glassmorphism** and **Corporate Modern**. It utilizes deep space-inspired backgrounds paired with translucent frosted layers to create depth. Neon accents and soft glows represent the "intelligence" of the AI matching engine, while thin, elegant outlines maintain a high-end iOS-quality feel. The overall aesthetic is clean and focused, yet high-energy and modern.

## Colors

The palette is rooted in a "Deep Night" spectrum to minimize eye strain and maximize the vibrancy of the AI accents.

- **Backgrounds:** Use the primary background for the main canvas. The surface and secondary variants are used for section grouping and structural depth.
- **Glassmorphism:** Interactive cards must use the glass surface hexes with a `backdrop-filter: blur(20px)` and a thin `1px` border using a semi-transparent version of the highlight color (10-15% opacity).
- **Accents:** The Purple-to-Pink gradient is reserved for primary actions, success states, and "AI-powered" features.
- **Highlights:** Use the highlight pink for critical micro-interactions, active indicators, and notifications.

## Typography

This design system uses **Inter** for its systematic clarity and modern geometric profile. 

- **Hierarchy:** Use `Display-LG` for impactful welcome screens and matching results. `Headline-MD` is the standard for card titles and section headers.
- **Weight:** Headings should leverage Bold (700) or SemiBold (600) to stand out against the dark background. Body text remains Regular (400) for legibility, while labels use Medium (500) for a sharper definition.
- **Color Contrast:** Use `text_primary` for all headings and `text_secondary` for body descriptions. `text_muted` is strictly for captions, timestamps, and placeholder text.

## Layout & Spacing

The layout follows a **Fluid Grid** approach optimized for mobile viewports, emphasizing generous negative space to maintain a "premium" feel.

- **Margins:** A strict 24px (1.5rem) horizontal padding is applied to all main screen containers.
- **Rhythm:** An 8px base grid drives all spacing. Use 16px (1rem) for vertical stacking of related elements and 32px (2rem) to separate distinct functional sections.
- **Matching Interface:** The primary AI matching interface uses a centered stack model (Tinder-style) with 24px of bottom clearance to ensure the action buttons are easily reachable.

## Elevation & Depth

Visual hierarchy is achieved through **Tonal Layering** and **Glassmorphic Stacking** rather than traditional heavy shadows.

- **Level 0:** Primary Background (#0B0E1C).
- **Level 1:** Surface/Secondary containers for grouping content.
- **Level 2 (Glass):** Floating cards and modal sheets. These use a 1px border stroke with a subtle top-down gradient to simulate a light source from above.
- **Glows:** Primary buttons and "AI Match" indicators use a soft background glow (blur: 40px) matching the accent color at 20% opacity to suggest a light-emitting source.
- **Overlays:** Use a 60% black tint behind modal sheets to maintain focus on the glass content.

## Shapes

The shape language is sophisticated and friendly. 

- **Cards:** Use a large radius of 24px to 28px for main matching cards to create a modern, tactile feel.
- **Buttons:** Primary action buttons use a fully rounded (pill) shape. Secondary buttons and input fields use a consistent 12px or 16px radius.
- **Selection Chips:** Use pill shapes to differentiate them from functional data cards.

## Components

### Buttons
- **Primary:** Full gradient background with white text. Apply a subtle outer glow for "AI Start" actions.
- **Secondary:** Transparent with a 1px white or secondary text-colored border.
- **Icon Buttons:** Circular glassmorphic backgrounds with thin-line icons (1.5pt stroke).

### Cards
- **Job/Profile Card:** Glassmorphic background (#1A1F35) with a 24px radius. Content inside should be padded by 20px. 
- **Match Indicator:** A pill-shaped badge within cards using the purple-to-pink gradient to highlight the percentage match.

### Inputs & Search
- **Search Bar:** Secondary background color (#151A2E) with 12px radius. Use `text_muted` for placeholder text and thin-line magnifying glass icons.
- **Filter Chips:** Deep surface color (#101426) when inactive, gradient border or background when active.

### Lists & Navigation
- **Bottom Nav:** A solid or slightly translucent #0B0E1C bar with active icons highlighted in the primary purple.
- **Lists:** Clean separation using the surface color as a background for the entire row, rather than dividers.

### Feedback Elements
- **Success States:** Use the Success green (#3DDC84) for "Applied" or "Match Confirmed" messages.
- **Empty States:** Use muted text and thin-line illustrations to maintain a minimal aesthetic.
---
name: Midnight Velocity
colors:
  surface: '#131316'
  surface-dim: '#131316'
  surface-bright: '#39393c'
  surface-container-lowest: '#0e0e11'
  surface-container-low: '#1b1b1e'
  surface-container: '#1f1f22'
  surface-container-high: '#2a2a2d'
  surface-container-highest: '#353438'
  on-surface: '#e4e1e6'
  on-surface-variant: '#e0bec6'
  inverse-surface: '#e4e1e6'
  inverse-on-surface: '#303033'
  outline: '#a78991'
  outline-variant: '#594047'
  surface-tint: '#ffb1c8'
  primary: '#ffb1c8'
  on-primary: '#650033'
  primary-container: '#ff4d97'
  on-primary-container: '#5b002d'
  inverse-primary: '#b80662'
  secondary: '#d0bcff'
  on-secondary: '#3b0091'
  secondary-container: '#5417be'
  on-secondary-container: '#c0a7ff'
  tertiary: '#4ae176'
  on-tertiary: '#003915'
  tertiary-container: '#00a94c'
  on-tertiary-container: '#003312'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffd9e2'
  primary-fixed-dim: '#ffb1c8'
  on-primary-fixed: '#3e001d'
  on-primary-fixed-variant: '#8e004a'
  secondary-fixed: '#e9ddff'
  secondary-fixed-dim: '#d0bcff'
  on-secondary-fixed: '#23005c'
  on-secondary-fixed-variant: '#5417be'
  tertiary-fixed: '#6bff8f'
  tertiary-fixed-dim: '#4ae176'
  on-tertiary-fixed: '#002109'
  on-tertiary-fixed-variant: '#005321'
  background: '#131316'
  on-background: '#e4e1e6'
  surface-variant: '#353438'
typography:
  display:
    fontFamily: Hanken Grotesk
    fontSize: 40px
    fontWeight: '800'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
  label-md:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '500'
    lineHeight: '1.2'
    letterSpacing: 0.05em
  headline-lg-mobile:
    fontFamily: Hanken Grotesk
    fontSize: 28px
    fontWeight: '700'
    lineHeight: '1.2'
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
  container-max: 1200px
  gutter: 20px
---

## Brand & Style

This design system is built for a premium, high-octane job marketplace. It avoids the clinical, dry aesthetic of traditional recruitment platforms in favor of a **Dark Mode Premium** experience that feels more like a high-end fintech or social discovery app. 

The visual language balances **Minimalism** with **Glassmorphism**. Surfaces are deep and immersive, using layered translucency to create a sense of physical space. The emotional response is one of exclusivity, speed, and modern professionalism. High-contrast typography and vibrant neon accents ensure that critical actions—like applying for a job or contacting a candidate—feel impactful and rewarding.

## Colors

The palette is anchored in a true-black canvas to maximize OLED efficiency and depth. 

- **Primary & Secondary:** A vibrant pink-to-purple gradient represents action and energy. It is used sparingly for primary buttons, active states, and "hot" job opportunities.
- **Neutrals:** We use a range of "Rich Blacks" and "Deep Charcoals" (Zinc/Slate scales) to create hierarchy without using distracting lines.
- **Accents:** Green is reserved strictly for "Success" states or "Hiring Now" indicators.
- **Glassmorphism:** Surface containers utilize a subtle 4-6% white overlay with a 20px background blur to separate content from the background canvas.

## Typography

This design system utilizes **Hanken Grotesk** as the primary typeface for its sharp, contemporary geometry that resonates with tech-forward audiences. 

- **Hierarchy:** Dramatic contrast between headlines (ExtraBold) and body text (Regular).
- **Functional Accents:** **JetBrains Mono** is used for metadata, such as salary ranges, timestamps, and tags, to provide a technical, precise feel that aids in scannability.
- **Scalability:** Large display headers on desktop scale down by 15-20% on mobile to maintain vertical density.

## Layout & Spacing

The system follows a strict **8pt Grid** logic to maintain mathematical balance.

- **Fluidity:** On mobile, we use a 4-column grid with 20px side margins. On desktop, a 12-column grid is centered with a max-width of 1200px.
- **Rhythm:** Vertical rhythm is maintained by using the `md` (24px) unit for spacing between distinct content sections.
- **Density:** Job listings and candidate cards use tight internal padding (`sm`) to maximize information density, while marketing or profile headers use generous `lg` padding to feel "premium."

## Elevation & Depth

Hierarchy is established through **Tonal Layering** rather than heavy shadows.

1.  **Level 0 (Base):** Pure `#09090B` background.
2.  **Level 1 (Cards):** Subsurface glass (`4% White` overlay + `20px Blur`) with a `1px` subtle stroke (border-opacity 10%).
3.  **Level 2 (Modals/Popovers):** Higher contrast glass (`8% White` overlay) with a soft, diffused ambient shadow (Color: `#000000`, Blur: `40px`, Opacity: `50%`).
4.  **Interaction:** When a card is hovered or pressed, the 1px border brightness increases, and the background blur intensity doubles to create a sense of "lifting" off the page.

## Shapes

The shape language is consistently **Rounded (0.5rem / 8px)**. 

This level of rounding provides a professional yet approachable feel. 
- **Buttons and Chips:** Use `rounded-xl` or full pill-shapes to distinguish interactive triggers from structural containers.
- **Cards and Containers:** Use the standard 8px-16px radius.
- **Avatar Frames:** Avatars are always circular to contrast against the predominantly rectangular grid.

## Components

### Buttons
- **Primary:** Background uses the `accent_gradient`. Text is white/bold.
- **Secondary:** Transparent background with a `1px` gradient border.
- **Ghost:** No background or border; uses the primary pink color for text.

### Cards (Job/Profile)
- Constructed with `surface_glass`. 
- Features a subtle `1px` top-light stroke to simulate a glass edge.
- Primary information (Job Title/Name) is always at the highest typographic weight.

### Chips & Tags
- Used for skills or job categories. 
- Low-contrast background (`white opacity 10%`) with `label-md` mono-type.

### Input Fields
- Dark, recessed backgrounds (`black 100%`).
- Bottom-border only or very subtle full-stroke that glows with the `secondary_color` when focused.

### Navigation
- **Mobile Bottom Bar:** High-blur glassmorphism. Active icons use the gradient treatment or a vibrant glow effect beneath the icon.
- **Desktop Sidebar:** Minimalist, using icon-only or icon+label with high vertical spacing.
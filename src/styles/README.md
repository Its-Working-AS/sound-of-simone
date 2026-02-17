# Design System Documentation

This directory contains the design system foundation for the Sound of Simone project.

## Overview

The design system provides a centralized set of design tokens, global styles, and utility classes to ensure consistency across the application and facilitate rapid UI development.

## Files

### `design-tokens.css`
Contains all CSS custom properties (CSS variables) that define the design system:
- **Colors**: Primary, neutral, semantic, text, background, and border colors
- **Typography**: Font families, sizes, weights, line heights, and letter spacing
- **Spacing**: Standardized spacing scale
- **Sizing**: Width and height values
- **Borders**: Border widths and radius values
- **Shadows**: Box shadow definitions
- **Transitions**: Timing and easing functions
- **Z-Index**: Layering scale

### `global.css`
Base global styles and resets:
- Modern CSS reset
- Base element styling (headings, paragraphs, links, etc.)
- Focus states for accessibility
- Reduced motion support

### `utilities.css`
Common utility classes for rapid development:
- Container classes
- Display utilities (flex, grid, etc.)
- Spacing utilities (margin, padding)
- Typography utilities
- Color utilities
- Border and shadow utilities
- Button styles
- Card components
- Responsive utilities

### `design-system.ts`
TypeScript configuration for programmatic access to design tokens. Use this when you need to reference design values in TypeScript/JavaScript code.

## Usage

### In Astro Components

The design system is automatically imported via the `Layout.astro` component. All design tokens and utilities are available throughout your application.

#### Using CSS Custom Properties

```astro
<style>
  .my-component {
    color: var(--color-primary);
    padding: var(--space-4);
    border-radius: var(--border-radius-lg);
    font-size: var(--font-size-lg);
  }
</style>
```

#### Using Utility Classes

```astro
<div class="container flex flex-col items-center gap-4 py-8">
  <h1 class="text-4xl font-bold text-primary">Hello World</h1>
  <p class="text-lg text-secondary">This is a paragraph with utility classes.</p>
  <button class="btn btn-primary">Click me</button>
</div>
```

### In TypeScript/JavaScript

```typescript
import { designSystem } from './styles/design-system';

// Access design tokens programmatically
const primaryColor = designSystem.colors.primary[600];
const spacing = designSystem.spacing[4];
```

## Design Tokens

### Color Palette

The color system uses a scale from 50 (lightest) to 900 (darkest) for primary and neutral colors.

- **Primary Colors**: Used for brand colors, CTAs, and interactive elements
- **Neutral Colors**: Used for text, backgrounds, and borders
- **Semantic Colors**: Success, warning, error, and info states

### Typography

- **Font Families**: Base, heading, and monospace fonts
- **Font Sizes**: From xs (12px) to 6xl (60px)
- **Font Weights**: Light to extrabold
- **Line Heights**: Tight to loose

### Spacing

Consistent spacing scale from 0 to 32 (0px to 128px) based on 4px increments.

### Responsive Design

Breakpoints:
- **sm**: 640px
- **md**: 768px
- **lg**: 1024px
- **xl**: 1280px
- **2xl**: 1536px

## Customization

To customize the design system for your brand:

1. **Update `design-tokens.css`**: Modify CSS custom properties to match your brand colors, typography, etc.
2. **Update `design-system.ts`**: Keep the TypeScript configuration in sync with CSS tokens
3. **Extend `utilities.css`**: Add custom utility classes as needed

## Best Practices

1. **Use Design Tokens**: Always use CSS custom properties instead of hard-coded values
2. **Utility-First Approach**: Use utility classes for common patterns, custom CSS for unique designs
3. **Semantic Naming**: Use semantic color names (e.g., `--color-text-primary`) rather than generic names
4. **Accessibility**: Ensure sufficient color contrast and include focus states
5. **Performance**: Utility classes are lightweight and can be shared across components

## Accessibility

The design system includes:
- Focus-visible states for keyboard navigation
- Proper color contrast ratios
- Reduced motion support via `prefers-reduced-motion`
- Semantic HTML encouragement

## Integration with Decap CMS

The design system is compatible with Decap CMS. Content editors can use standard markdown, which will be styled appropriately through the global styles.

## Cloudflare Pages Compatibility

All styles are pure CSS with no build-time dependencies, ensuring full compatibility with Cloudflare Pages deployment.

## Future Enhancements

Consider adding:
- Dark mode support with alternate color schemes
- Additional component libraries
- Animation utilities
- Grid system utilities
- Print styles

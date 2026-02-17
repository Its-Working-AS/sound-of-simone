# UI Components

This directory contains reusable UI components built with the design system.

## Available Components

### Button
A flexible button component with multiple variants and sizes.

**Props:**
- `variant`: 'primary' | 'secondary' | 'outline' (default: 'primary')
- `size`: 'sm' | 'base' | 'lg' (default: 'base')
- `type`: 'button' | 'submit' | 'reset' (default: 'button')
- `href`: Optional URL for link-style buttons
- `class`: Additional CSS classes

**Usage:**
```astro
---
import Button from '@/components/ui/Button.astro';
---

<Button variant="primary">Click me</Button>
<Button variant="outline" size="lg">Large button</Button>
<Button href="/about">Link button</Button>
```

### Card
A container component for grouping content with consistent styling.

**Props:**
- `padding`: 'sm' | 'base' | 'lg' (default: 'base')
- `shadow`: 'none' | 'sm' | 'base' | 'md' | 'lg' (default: 'sm')
- `class`: Additional CSS classes

**Usage:**
```astro
---
import Card from '@/components/ui/Card.astro';
---

<Card>
  <h2>Card Title</h2>
  <p>Card content goes here.</p>
</Card>

<Card padding="lg" shadow="md">
  <p>Larger card with more shadow.</p>
</Card>
```

### Container
A responsive container for page content with max-width constraints.

**Props:**
- `size`: 'sm' | 'md' | 'lg' (default: 'lg')
- `class`: Additional CSS classes

**Usage:**
```astro
---
import Container from '@/components/ui/Container.astro';
---

<Container>
  <h1>Page content</h1>
  <p>Automatically centered and constrained to max-width.</p>
</Container>

<Container size="sm">
  <p>Narrower container for focused content.</p>
</Container>
```

## Creating New Components

When creating new UI components:

1. Use design system tokens from `/src/styles/design-tokens.css`
2. Accept a `class` prop for extensibility
3. Document props and usage in this README
4. Export from `index.ts` for easy imports
5. Follow the naming convention: PascalCase for component names

## Component Guidelines

- **Single Responsibility**: Each component should have one clear purpose
- **Composability**: Components should work well together
- **Accessibility**: Include proper ARIA labels and keyboard navigation
- **Responsive**: Components should work on all screen sizes
- **Design System**: Use design tokens for consistency

## Future Components

Consider adding:
- Navigation components (Header, Nav, Menu)
- Form components (Input, Textarea, Select)
- Layout components (Grid, Stack, Spacer)
- Feedback components (Alert, Toast, Modal)
- Typography components (Heading, Text, Link)

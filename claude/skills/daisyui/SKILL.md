---
name: daisyui
description: Use when writing UI components with Tailwind and Daisy UI
---

## Instruction

Use if daisyUI is installed alongside Tailwind.

## Core Principles

1. Apply styles by adding component class names to HTML elements
2. Customize using Tailwind utilities when daisyUI classes are insufficient
3. Use `!` prefix for utility classes to override specificity conflicts
4. Combine daisyUI classes with responsive prefixes for layouts
5. Only use existing daisyUI or Tailwind CSS class names
6. Avoid custom CSS; prefer utility-first approach

## Color System

**Semantic Colors:**

- `primary`, `secondary`, `accent`, `neutral` - brand colors
- `base-100`, `base-200`, `base-300` - surface colors
- `info`, `success`, `warning`, `error` - semantic states
- Each has a `-content` variant for text contrast (e.g., `primary-content`)

**Usage:**

```html
<div class="bg-primary text-primary-content">Primary background</div>
<div class="bg-base-200">Surface background</div>
<span class="text-error">Error text</span>
```

**Rules:**

- Use `base-*` colors for page majority, `primary` for important elements
- Avoid hardcoded Tailwind colors (e.g., `text-gray-800`) for dark mode
  compatibility
- Use semantic names for automatic theme consistency

## Components

### Layout

**navbar** - Top navigation

```html
<div class="navbar bg-base-100">
  <div class="navbar-start">Logo</div>
  <div class="navbar-center">Title</div>
  <div class="navbar-end">Actions</div>
</div>
```

**footer** - Multi-column footer

```html
<footer class="footer bg-base-200 p-10">
  <nav><h6 class="footer-title">Services</h6><a class="link link-hover">Link</a></nav>
</footer>
```

**drawer** - Responsive sidebar

```html
<div class="drawer lg:drawer-open">
  <input id="drawer" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content">Main content</div>
  <div class="drawer-side">
    <label for="drawer" class="drawer-overlay"></label>
    <ul class="menu bg-base-200 w-80">Sidebar</ul>
  </div>
</div>
```

**dock** - Bottom navigation

```html
<div class="dock">
  <button class="dock-active">Home</button>
  <button>Search</button>
</div>
```

**hero** - Large banner

```html
<div class="hero min-h-screen bg-base-200">
  <div class="hero-content text-center">
    <h1 class="text-5xl font-bold">Title</h1>
  </div>
</div>
```

### Data Display

**card** - Content container

```html
<div class="card bg-base-100 shadow-xl">
  <figure><img src="image.jpg" alt="Image" /></figure>
  <div class="card-body">
    <h2 class="card-title">Title</h2>
    <p>Description</p>
    <div class="card-actions justify-end">
      <button class="btn btn-primary">Action</button>
    </div>
  </div>
</div>
```

**table** - Data grid

```html
<table class="table table-zebra">
  <thead><tr><th>Name</th><th>Value</th></tr></thead>
  <tbody><tr><td>Item</td><td>123</td></tr></tbody>
</table>
```

**stat** - Numeric display

```html
<div class="stats shadow">
  <div class="stat">
    <div class="stat-title">Total Users</div>
    <div class="stat-value">89,400</div>
    <div class="stat-desc">21% more than last month</div>
  </div>
</div>
```

**badge** - Status label

```html
<span class="badge">default</span>
<span class="badge badge-primary">primary</span>
<span class="badge badge-lg">large</span>
```

**avatar** - Profile image

```html
<div class="avatar">
  <div class="w-24 rounded-full">
    <img src="avatar.jpg" />
  </div>
</div>
```

**timeline** - Chronological events

```html
<ul class="timeline">
  <li><div class="timeline-start">Start</div><div class="timeline-middle">●</div><div class="timeline-end">End</div></li>
</ul>
```

**steps** - Process indicator

```html
<ul class="steps">
  <li class="step step-primary">Register</li>
  <li class="step step-primary">Choose plan</li>
  <li class="step">Purchase</li>
</ul>
```

### Forms & Inputs

**input** - Text field

```html
<input type="text" class="input input-bordered w-full max-w-xs" placeholder="Type here" />
<input type="text" class="input input-primary" />
<input type="text" class="input input-ghost" />
```

**textarea** - Multi-line

```html
<textarea class="textarea textarea-bordered" placeholder="Bio"></textarea>
```

**select** - Dropdown

```html
<select class="select select-bordered w-full max-w-xs">
  <option disabled selected>Pick one</option>
  <option>Option 1</option>
</select>
```

**checkbox** - Binary selection

```html
<input type="checkbox" class="checkbox checkbox-primary" />
```

**radio** - Option group

```html
<input type="radio" name="radio-1" class="radio radio-primary" />
```

**toggle** - Switch

```html
<input type="checkbox" class="toggle toggle-primary" />
```

**range** - Slider

```html
<input type="range" min="0" max="100" class="range range-primary" />
```

**file-input** - File upload

```html
<input type="file" class="file-input file-input-bordered w-full max-w-xs" />
```

**rating** - Star rating

```html
<div class="rating">
  <input type="radio" name="rating-1" class="mask mask-star" />
  <input type="radio" name="rating-1" class="mask mask-star" checked />
</div>
```

**fieldset** - Grouped controls

```html
<fieldset class="fieldset">
  <legend class="fieldset-legend">Settings</legend>
  <input type="text" class="input" />
</fieldset>
```

**label** - Form labeling

```html
<label class="label"><span class="label-text">Email</span></label>
```

### Buttons & Actions

**btn** - Button

```html
<button class="btn">Default</button>
<button class="btn btn-primary">Primary</button>
<button class="btn btn-secondary">Secondary</button>
<button class="btn btn-accent">Accent</button>
<button class="btn btn-ghost">Ghost</button>
<button class="btn btn-link">Link</button>
<button class="btn btn-outline">Outline</button>
<button class="btn btn-outline btn-primary">Outline Primary</button>

<!-- Sizes -->
<button class="btn btn-lg">Large</button>
<button class="btn btn-md">Medium</button>
<button class="btn btn-sm">Small</button>
<button class="btn btn-xs">Tiny</button>

<!-- States -->
<button class="btn btn-active">Active</button>
<button class="btn btn-disabled">Disabled</button>
<button class="btn btn-wide">Wide</button>
<button class="btn btn-circle">●</button>
<button class="btn btn-square">■</button>
```

**link** - Styled hyperlink

```html
<a class="link link-primary">Primary link</a>
<a class="link link-hover">Hover underline</a>
```

### Feedback & Indicators

**alert** - Notifications

```html
<div class="alert">Default alert</div>
<div class="alert alert-info">Info</div>
<div class="alert alert-success">Success</div>
<div class="alert alert-warning">Warning</div>
<div class="alert alert-error">Error</div>
```

**loading** - Animated states

```html
<span class="loading loading-spinner"></span>
<span class="loading loading-dots"></span>
<span class="loading loading-ring"></span>
<span class="loading loading-ball"></span>
<span class="loading loading-bars"></span>
<span class="loading loading-infinity"></span>
```

**progress** - Linear bar

```html
<progress class="progress w-56" value="70" max="100"></progress>
<progress class="progress progress-primary w-56" value="70" max="100"></progress>
```

**radial-progress** - Circular

```html
<div class="radial-progress" style="--value:70;">70%</div>
```

**toast** - Corner notifications

```html
<div class="toast toast-end">
  <div class="alert alert-info">New message</div>
</div>
```

**modal** - Dialog

```html
<button class="btn" onclick="my_modal.showModal()">Open</button>
<dialog id="my_modal" class="modal">
  <div class="modal-box">
    <h3 class="text-lg font-bold">Title</h3>
    <p>Content</p>
    <div class="modal-action">
      <form method="dialog"><button class="btn">Close</button></form>
    </div>
  </div>
</dialog>
```

**dropdown** - Context menu

```html
<div class="dropdown">
  <div tabindex="0" class="btn m-1">Click</div>
  <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box w-52 p-2 shadow">
    <li><a>Item 1</a></li>
    <li><a>Item 2</a></li>
  </ul>
</div>
```

### Structural

**accordion** - Collapsible groups

```html
<div class="collapse collapse-arrow bg-base-200">
  <input type="radio" name="accordion" checked />
  <div class="collapse-title text-xl font-medium">Title</div>
  <div class="collapse-content"><p>Content</p></div>
</div>
```

**tabs** - Tabbed content

```html
<div class="tabs tabs-bordered">
  <a class="tab">Tab 1</a>
  <a class="tab tab-active">Tab 2</a>
  <a class="tab">Tab 3</a>
</div>
```

**menu** - Link list

```html
<ul class="menu bg-base-200 w-56 rounded-box">
  <li><a>Item 1</a></li>
  <li><a class="active">Active</a></li>
  <li><details><summary>Submenu</summary><ul><li><a>Sub</a></li></ul></details></li>
</ul>
```

**breadcrumbs** - Navigation path

```html
<div class="breadcrumbs text-sm">
  <ul>
    <li><a>Home</a></li>
    <li><a>Docs</a></li>
    <li>Current</li>
  </ul>
</div>
```

**pagination** - Page navigation

```html
<div class="join">
  <button class="join-item btn">1</button>
  <button class="join-item btn btn-active">2</button>
  <button class="join-item btn">3</button>
</div>
```

**join** - Grouped items

```html
<div class="join">
  <input class="input input-bordered join-item" placeholder="Email"/>
  <button class="btn join-item">Subscribe</button>
</div>
```

**divider** - Content separator

```html
<div class="divider">OR</div>
<div class="divider divider-horizontal"></div>
```

### Content & Media

**carousel** - Scrollable gallery

```html
<div class="carousel w-full">
  <div id="slide1" class="carousel-item relative w-full">
    <img src="img1.jpg" class="w-full" />
    <div class="absolute left-5 right-5 top-1/2 flex -translate-y-1/2 justify-between">
      <a href="#slide4" class="btn btn-circle">❮</a>
      <a href="#slide2" class="btn btn-circle">❯</a>
    </div>
  </div>
</div>
```

**diff** - Side-by-side comparison

```html
<div class="diff aspect-16/9">
  <div class="diff-item-1"><img src="before.jpg" /></div>
  <div class="diff-item-2"><img src="after.jpg" /></div>
  <div class="diff-resizer"></div>
</div>
```

**skeleton** - Loading placeholder

```html
<div class="skeleton h-32 w-32"></div>
<div class="skeleton h-4 w-28"></div>
```

**kbd** - Keyboard shortcut

```html
<kbd class="kbd">Ctrl</kbd>+<kbd class="kbd">C</kbd>
```

**mask** - Image shapes

```html
<img class="mask mask-squircle" src="image.jpg" />
<img class="mask mask-hexagon" src="image.jpg" />
<img class="mask mask-star" src="image.jpg" />
```

### Mockups

**mockup-browser** - Browser frame

```html
<div class="mockup-browser bg-base-300 border">
  <div class="mockup-browser-toolbar"><div class="input">https://daisyui.com</div></div>
  <div class="bg-base-200 px-4 py-16">Content</div>
</div>
```

**mockup-phone** - Phone frame

```html
<div class="mockup-phone">
  <div class="camera"></div>
  <div class="display"><div class="artboard phone-1">Content</div></div>
</div>
```

**mockup-code** - Code editor

```html
<div class="mockup-code">
  <pre data-prefix="$"><code>npm i daisyui</code></pre>
</div>
```

## Configuration

```css
@plugin "daisyui" {
  themes: light --default, dark --prefersdark;
  root: ":root";
  include: ;
  exclude: ;
  prefix: ;
  logs: true;
}
```

## Themes

Apply via `data-theme` attribute:

```html
<html data-theme="dark">
```

Built-in themes: `light`, `dark`, `cupcake`, `bumblebee`, `emerald`, `corporate`,
`synthwave`, `retro`, `cyberpunk`, `valentine`, `halloween`, `garden`, `forest`,
`aqua`, `lofi`, `pastel`, `fantasy`, `wireframe`, `black`, `luxury`, `dracula`,
`cmyk`, `autumn`, `business`, `acid`, `lemonade`, `night`, `coffee`, `winter`,
`dim`, `nord`, `sunset`

## Class Name Syntax

- **component** - Required main class: `btn`, `card`
- **part** - Child elements: `card-body`, `navbar-start`
- **style** - Visual variations: `btn-outline`, `btn-ghost`
- **color** - Color modifiers: `btn-primary`, `alert-error`
- **size** - Dimensions: `btn-lg`, `btn-sm`, `btn-xs`
- **behavior** - States: `btn-active`, `tab-active`
- **modifier** - Special: `btn-wide`, `btn-circle`
- **placement** - Position: `dropdown-end`, `toast-top`

## Best Practices

1. Use semantic colors for theme compatibility
2. Leverage responsive prefixes (`sm:`, `lg:`, etc.)
3. Use placeholder images from `https://picsum.photos/{width}/{height}`
4. Combine daisyUI with Tailwind utilities freely
5. Use `!` prefix to override specificity when needed

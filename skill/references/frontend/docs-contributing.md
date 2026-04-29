---
title: Contributing to docs.sei.io
description: How to author or update pages on docs.sei.io. Repo layout, Nextra MDX conventions, _meta.js navigation config, frontmatter requirements, build commands, and PR workflow.
---

# Contributing to docs.sei.io

The Sei docs are published from https://github.com/sei-protocol/sei-docs (despite the `-old` suffix in some tooling, this is the live source). Built with Nextra + Bun. This file is the contributor cheat sheet.

## Repo at a glance

| Item | Value |
|---|---|
| Repo | https://github.com/sei-protocol/sei-docs |
| Framework | Nextra (Next.js docs theme) |
| Package manager / runtime | Bun |
| Page format | `.mdx` (Markdown + JSX) |
| Content root | `/content/` |
| Style guide | `/STYLE_GUIDE.mdx` |

## Directory layout

```
content/
├── _meta.js            # root nav config (top-level sections in display order)
├── index.mdx           # docs.sei.io home
├── learn/
│   ├── _meta.js        # nav config for /learn
│   ├── index.mdx       # /learn landing
│   └── ...mdx          # individual pages
├── evm/
│   ├── _meta.js
│   ├── precompiles/
│   │   ├── _meta.js
│   │   └── ...mdx
│   └── ...
├── cosmos-sdk/         # deprecated; new content goes elsewhere
├── node/
│   └── ...
└── STYLE_GUIDE.mdx
```

## Authoring a page

1. **Pick the right section** — `learn/` for concepts, `evm/` for EVM dev, `node/` for node ops. Don't put new content in `cosmos-sdk/` (deprecated per SIP-03).
2. **Filename**: kebab-case (`my-new-page.mdx`).
3. **MDX with frontmatter** at the top:

```mdx
---
title: "My Page Title"
description: "One-sentence description used for SEO and OG cards."
keywords: ["sei", "evm", "..."]
---

# My Page Title

Intro paragraph that re-states the H1 in conversational form...

## First section

Content here. Code blocks use triple-backtick fences with language hints:

```solidity
pragma solidity ^0.8.28;
contract Foo { /* ... */ }
```

Tables, callouts, JSX components from Nextra (e.g., `<Callout>`) all work.
```

4. **Update the section's `_meta.js`** to add the new page to the nav.

## `_meta.js` navigation config

Each directory has a `_meta.js` that controls sidebar order and display titles.

```js
// content/evm/_meta.js (excerpt)
export default {
  index: { title: 'Home' },
  '-- Essentials': { type: 'separator' },
  networks: 'Network Information',
  'evm-hardhat': 'EVM with Hardhat',
  'evm-foundry': 'EVM with Foundry',
  'evm-verification': 'Contract Verification',
  '-- Precompiles': { type: 'separator' },
  precompiles: 'Precompiles',
  // ...
}
```

Keys are the slugs of files (without `.mdx`) or subdirectory names. Values are either:
- A string (display title in the sidebar)
- An object (`{ title, type, display, theme }`) for advanced control
- A separator (`{ type: 'separator' }`) for visual groupings in the sidebar

To add a page named `my-new-page.mdx`, add `'my-new-page': 'My New Page'` in the right position in the parent `_meta.js`.

## Style guide essentials

From `STYLE_GUIDE.mdx`:

1. **Beginner-friendly** — explain Web3 jargon; spell out acronyms on first use ("Ethereum Virtual Machine (EVM)").
2. **Simple sentences** — short, direct, avoid passive voice.
3. **Self-explanatory** — provide context; show code over describing it.
4. **Use code snippets, tables, and callouts** liberally.
5. **Cross-link** to other docs pages where useful — Nextra resolves relative `.mdx` paths.
6. **Diagrams** — Mermaid is supported in code fences with `mermaid` language hint.

## Local development

```bash
bun install
bun dev
# → http://localhost:3000
```

Navigate to your new page and verify rendering. Hot reload picks up MDX changes.

## Build validation (run before PR)

```bash
bun run build
```

Build runs:
- Next.js production build
- Pagefind search index generation
- Sitemap generation
- HTML scraping for downstream tools (`llms.txt`)

If any step fails, fix locally before opening a PR.

## PR workflow

1. **Fork** https://github.com/sei-protocol/sei-docs.
2. **Branch** from `main` with a descriptive name (`docs/add-account-abstraction-page`).
3. **Edit** files; run `bun dev` to preview.
4. **Build** with `bun run build` to catch errors.
5. **Commit** with a clear message ("Add account abstraction guide to /evm").
6. **Push** to your fork.
7. **Open a PR** against `sei-protocol/sei-docs:main` using the PR template.
8. **Address review feedback** — maintainers may request structural or wording changes.

## Common pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| Page doesn't appear in sidebar | Missing entry in `_meta.js` | Add the slug to the parent `_meta.js` |
| Build fails on broken link | Internal link to non-existent page | Fix or use `<a href>` for external |
| Code block doesn't highlight | Missing language hint after backticks | Add ` ```solidity ` etc. |
| MDX import error | JSX component not imported at top of file | `import { Callout } from 'nextra/components'` |
| Incorrect ordering | `_meta.js` keys are out of intended order | Reorder keys; the JS object preserves insertion order |
| Two pages with the same `title` frontmatter | Duplicate keys collide in nav | Use unique slugs and titles |

## Adding a new top-level section

Rare; usually contributing means adding pages within an existing section. If you must add a new top-level dir:

1. Create `/content/<new-section>/`.
2. Add `_meta.js` and `index.mdx` (the section landing page).
3. Update `/content/_meta.js` to register the new section in nav order.
4. Coordinate with maintainers — top-level sections are an information-architecture decision, not a content one.

## Specific page types

### Tutorials / how-tos
- Start with prerequisites and goals.
- Code-first: paste the working snippet immediately, then explain.
- End with verification: how does the user know it worked?

### Reference pages
- Tables of values (addresses, RPC endpoints, chain IDs) belong here.
- Always include "verify against [authoritative source]" notes.
- Date or version-stamp things that drift.

### Concept pages
- Lead with a one-sentence definition.
- Use diagrams (Mermaid) for protocol flows.
- Cross-link to deeper-dive references.

## Where to put what

| Content type | Section |
|---|---|
| New EVM dev guide | `/evm` |
| Precompile reference | `/evm/precompiles` |
| Wallet integration | `/evm/wallet-integrations` |
| Architecture explainer | `/learn` |
| Node setup tutorial | `/node` |
| Cosmos-SDK reference | **don't** — section deprecated |

## Sei-specific notes

- **CosmWasm and Cosmos-SDK content** is being phased out per SIP-03 — confirm with maintainers before contributing legacy CosmWasm content.
- **EVM-first** is the current direction — most new pages should land in `/evm/`.
- **Brand kit** lives at https://docs.sei.io/learn/general-brand-kit. Updates to logos/visual identity should also be coordinated with sei.io/media.
- **The repo name `sei-docs-old`** in some references is a historical artifact — the same repo is the active source.

---
title: Contributing to docs.sei.io
description: How to author or update pages on docs.sei.io. Mintlify repo layout, docs.json navigation, MDX frontmatter and components, snippets, local preview, CI checks, and PR workflow.
---

# Contributing to docs.sei.io

The Sei docs are published from https://github.com/sei-protocol/sei-docs and auto-deploy from `main`. The site is built with **Mintlify** (the repo was migrated off Nextra). This file is the contributor cheat sheet.

## Repo at a glance

| Item | Value |
|---|---|
| Repo | https://github.com/sei-protocol/sei-docs |
| Platform | Mintlify (auto-deploys from `main`) |
| Config | `docs.json` (navigation, redirects, theme, search) |
| Page format | `.mdx` (Markdown + JSX components) |
| Content root | repo root — pages live in top-level section dirs (`evm/`, `learn/`, `node/`, `ai/`) |
| Reusable components | `/snippets/` (`.mdx` partials and `.jsx` custom React) |
| Style guide | `STYLE_GUIDE.md` (enforced by Vale) |
| Contributor rules | `AGENTS.md`, `CODEOWNERS`, PR template |

There is **no `_meta.js`, no Bun, no `/content/` root** — those were the old Nextra setup. Navigation lives entirely in `docs.json`.

## Directory layout

```
sei-docs/
├── docs.json            # navigation, redirects, theme — the single nav source of truth
├── index.mdx            # docs.sei.io home
├── evm/                 # EVM developer docs
│   ├── evm-general.mdx
│   ├── precompiles/
│   │   └── ...mdx
│   └── sei-js/
│       └── ...mdx
├── learn/               # concepts, accounts, architecture
├── node/                # node + validator operations
├── ai/                  # AI tooling, skills, MCP, x402
├── snippets/            # reusable .jsx custom components (Mintlify also supports .mdx partials)
├── images/              # static assets
├── skill.md             # root agent-skill override (served at /.well-known/skills/)
└── STYLE_GUIDE.md
```

## Authoring a page

1. **Pick the right section** — `learn/` for concepts, `evm/` for EVM dev, `node/` for node ops, `ai/` for AI tooling. Don't add new Cosmos-SDK/CosmWasm content (deprecated per SIP-3).
2. **Filename**: kebab-case (`my-new-page.mdx`).
3. **MDX with frontmatter** at the top:

```mdx
---
title: 'My Page Title'
sidebarTitle: 'Short Nav Title'
description: 'One-sentence description used for SEO and the page subtitle.'
keywords: ['sei', 'evm', '...']
---

Intro paragraph. (Mintlify renders `title` as the H1 automatically — do not add your own `# H1`.)

## First section

Content here. Code blocks use triple-backtick fences with language hints:

```solidity
pragma solidity ^0.8.28;
contract Foo { /* ... */ }
```
```

4. **Register the page in `docs.json`** — add its path (without `.mdx`) to the correct group's `pages` array. A page that isn't in `docs.json` won't appear in the nav.

## `docs.json` navigation

Navigation is a nested structure of tabs → groups → pages. Page entries are file paths **relative to the repo root, without the `.mdx` extension**.

```jsonc
// docs.json (excerpt)
{
  "navigation": {
    "tabs": [
      {
        "tab": "EVM",
        "groups": [
          {
            "group": "Sei-JS",
            "pages": [
              "evm/sei-js/index",
              "evm/sei-js/create-sei",
              "evm/templates"        // <- add your new page here, in display order
            ]
          }
        ]
      }
    ]
  },
  "redirects": [
    { "source": "/old-path", "destination": "/new-path", "permanent": true }
  ]
}
```

- **Order** in the `pages` array = sidebar order.
- **Nested groups** are objects with their own `group` + `pages`.
- **Moved or renamed a page?** Add a `redirects` entry so old URLs keep working (CI link-checks both internal links and the redirect set).

## Mintlify components

Common components available in any `.mdx` page (no import needed): `<Card>`, `<CardGroup>`, `<Columns>`, `<Steps>`, `<CodeGroup>`, `<Tabs>`, `<Accordion>`/`<AccordionGroup>`, `<Info>`, `<Note>`, `<Warning>`, `<Tip>`, `<Check>`, `<Frame>`. Use `<CodeGroup>` for multi-language tabs (they auto-sync across a page) and `<Steps>` for sequential instructions.

### Snippets and custom React

Reusable content lives in `/snippets/`. Mintlify supports two kinds; Sei's repo currently uses only the second:
- **`.mdx` partials** — import and render shared prose/components (a Mintlify capability; the Sei repo has none today).
- **`.jsx` custom components** — interactive widgets. Mintlify's React runtime has strict rules (per Mintlify's custom-React docs):
  - **Arrow-function component, exported as a named `export const` — no `export default`.**
  - **No `import` statements** and **no npm packages** — React hooks (`useState`, `useEffect`, …) are pre-injected; use them without importing.
  - **No dynamic `import()`** / `React.lazy`.
  - Practical convention (not in Mintlify's published rules): keep declarations inside the component body and stick to plain Tailwind utility classes — use inline `style` for anything they can't express.
  - Client-rendered — gate heavy widgets behind click-to-load.

```mdx
import { MyWidget } from '/snippets/my-widget.jsx';

<MyWidget />
```

## Style guide essentials

From `STYLE_GUIDE.md` (Vale enforces much of this in CI):

1. **Beginner-friendly** — explain Web3 jargon; spell out acronyms on first use ("Ethereum Virtual Machine (EVM)").
2. **Simple, direct sentences** — avoid passive voice.
3. **Show code over describing it** — paste the working snippet, then explain.
4. **Use code blocks, tables, and callouts** liberally.
5. **Cross-link** with root-relative paths (`/evm/precompiles/example-usage`).
6. **Diagrams** — Mermaid is supported in ` ```mermaid ` code fences.
7. **Date/version-stamp** anything that drifts (addresses, gas values, version requirements); prefer linking the live value over hardcoding.

## Local development

Install the Mintlify CLI and run the dev server from the repo root:

```bash
npm i -g mint        # or: npx mint dev
mint dev             # → http://localhost:3000 (hot-reloads on save)
```

`mint dev` validates `docs.json` and renders pages exactly as production. Check links before opening a PR:

```bash
mint broken-links
```

## CI checks (run before / expect on PR)

The repo has best-in-class docs CI. Expect these to run on your PR:

- **Vale** (`.vale.ini`) — prose linting against the Sei style rules.
- **typos** — spell-check.
- **lychee** (`lychee.toml`) + **`mint broken-links`** — internal and external link validation (including the `redirects` set).
- **SEO audit** and weekly **`llms.txt`** regeneration.

Fix Vale/link failures locally before requesting review.

## PR workflow

1. **Fork** https://github.com/sei-protocol/sei-docs (or branch if you have write access).
2. **Branch** from `main` with a descriptive name (`docs/add-account-abstraction-page`).
3. **Edit** pages; run `mint dev` to preview and `mint broken-links` to validate.
4. **Update `docs.json`** to register new pages and add redirects for any moves.
5. **Commit** with a clear message; **open a PR** against `sei-protocol/sei-docs:main` using the PR template.
6. **Address review** — `CODEOWNERS` routes the right reviewers; CI must pass.

## Common pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| Page doesn't appear in sidebar | Path not added to `docs.json` | Add `"<dir>/<slug>"` (no `.mdx`) to the right group's `pages` |
| Duplicate H1 on the page | Added `# Title` on top of frontmatter `title` | Remove the manual `# H1` — Mintlify renders `title` as the H1 |
| Custom `.jsx` snippet throws at runtime | Declared something at module scope, used `export default`, or `import`ed a package | Move all decls inside the arrow-fn component; named `export const`; no imports |
| Broken-link CI fails | Internal link to a non-existent path, or a renamed page with no redirect | Fix the path or add a `redirects` entry in `docs.json` |
| Old URL 404s after a rename | Missing redirect | Add `{ source, destination, permanent: true }` to `docs.json` |
| Code block doesn't highlight | Missing language hint | Add ` ```solidity ` / ` ```ts ` etc. |

## Where to put what

| Content type | Section |
|---|---|
| New EVM dev guide | `/evm` |
| Precompile reference | `/evm/precompiles` |
| Wallet integration | `/evm/wallet-integrations` |
| Architecture / accounts explainer | `/learn` |
| Node / validator setup | `/node` |
| AI tooling, skills, MCP, x402 | `/ai` |
| Agent skill (hosted) | root `skill.md` (override mode); Mintlify also supports `.mintlify/skills/<name>/SKILL.md` for multiple skills |
| Cosmos-SDK / CosmWasm | **don't** — deprecated per SIP-3 |

## Sei-specific notes

- **EVM-first** is the current direction — most new pages land in `/evm/`.
- **CosmWasm and Cosmos-SDK content** is being phased out per SIP-3; confirm with maintainers before adding legacy content.
- **Hosted agent skill**: Sei publishes one via a **root `skill.md`** (Mintlify "override" mode — `name: sei-docs`, `intended-host: docs.sei.io`), served at `docs.sei.io/.well-known/skills/` and installable via `npx skills add https://docs.sei.io`. (Mintlify also supports a `.mintlify/skills/<name>/SKILL.md` layout for *multiple* skills, but Sei doesn't use it — `.gitignore` excludes all of `.mintlify/`.)
- **Brand kit** lives at https://docs.sei.io/learn/general-brand-kit; coordinate visual-identity changes with sei.io/media.

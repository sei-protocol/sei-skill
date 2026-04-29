---
title: Sei Brand Assets and Media Kit
description: Where to find official Sei logos, wordmarks, color palette, typography, and press materials. Plus the canonical contacts for press, partnerships, and media inquiries.
---

# Sei Brand Assets and Media

Where to source official Sei brand materials when building dApps, writing posts, designing dashboards, or creating media coverage.

## Official sources (in priority order)

| Resource | URL | Contents |
|---|---|---|
| **Sei Brand Kit (docs)** | https://docs.sei.io/learn/general-brand-kit | Authoritative brand kit — logos, usage guidelines |
| **Sei Media / Press** | https://www.sei.io/media | Press kit, downloadable assets, news |
| **Brandfolder** | https://brandfolder.com/sei-0 | High-res SVG, PNG, vector logos |
| **Brandfetch** | https://brandfetch.com/sei.io | Programmatic logo + asset access |

> If brand kit URLs differ from those above, defer to https://www.sei.io/media as the entry point — it links to the current canonical assets.

## Logo variants

Sei provides logos in multiple variants for different contexts:

- **Primary logo** — full wordmark + symbol; use on light or dark backgrounds with appropriate contrast variants.
- **Symbol only** — for favicons, app icons, small contexts.
- **Wordmark only** — when the symbol would be redundant.
- **Color variants** — solid, monochrome (light/dark), reversed.

Always download the latest from official sources. Do **not** reuse logos found on third-party sites — they may be outdated.

## Color palette

Verify current values against the brand kit. Historically Sei has used a distinct red as the primary brand color paired with neutrals; the brand kit page (https://docs.sei.io/learn/general-brand-kit) is the source of truth for hex values, gradients, and accessibility-compliant pairings.

## Typography

Specified in the brand kit. Use Sei's specified fonts for marketing-adjacent surfaces; for product UI, system fonts are fine if the brand kit allows.

## Usage rules (typical, verify in brand kit)

Common rules across Sei brand guidelines (verify the current version):

- **Don't recolor** the logo outside approved variants.
- **Don't distort** proportions or stretch.
- **Maintain clear space** around the logo equivalent to the symbol height.
- **Don't combine** Sei logo with other logos as a single composite mark — adjacency in a "supported by" or partnership row is fine.
- **Don't use** the logo to imply Sei Foundation endorsement of unaffiliated projects.

## Press and media inquiries

Where to send specific kinds of requests:

| Inquiry type | Send to |
|---|---|
| Press / media coverage | Contact via https://www.sei.io/media or Foundation contact form |
| Partnerships / business development | Sei Foundation — https://www.seifdn.org |
| Ecosystem grant applications | https://www.sei.io/grants-and-funding |
| Validator / institutional staking | https://www.sei.io/institutions |
| General developer support | https://docs.sei.io + Discord (linked from sei.io footer) |
| Security disclosures | Foundation security contact (verify via official Discord or sei.io footer) |

## Common asks

### "I'm building a dApp on Sei. Can I use the Sei logo?"
Yes, with the brand kit's usage rules. Typical pattern: "Built on Sei" with the symbol or wordmark in your footer or splash. Don't use it in a way that implies official partnership unless you have one.

### "Can I name my project 'SeiSwap' / 'SeiLend' / etc.?"
Generally, descriptive names that include "Sei" as a prefix are common in the ecosystem. Trademark considerations are independent of the technical chain — consult the Sei Foundation if you want endorsement or have concerns.

### "Where can I get a high-res logo for a presentation?"
https://brandfolder.com/sei-0 has SVG/PNG/EPS for print and screen.

### "Is there a Figma file?"
Not officially advertised as of latest research. Contact the Foundation if you need source design files.

### "Can I create swag / merch with the Sei logo?"
For commercial use beyond your own dApp branding, contact the Foundation. Hackathon prizes, validator merch, and similar usage typically have informal allowance.

## Social and community channels

Source the current canonical handles from sei.io's footer (handles can change). Major channels typically include:

- Twitter/X
- Discord (link via sei.io footer)
- Telegram
- YouTube
- LinkedIn (institutional)

Always pull these from sei.io directly rather than trusting cached lists — phishing/impersonation is a real risk.

## "Built on Sei" patterns

For dApps showing Sei integration:

```html
<a href="https://www.sei.io" target="_blank" rel="noopener noreferrer">
  <img src="/assets/sei-logo.svg" alt="Built on Sei" height="32" />
</a>
```

Place in the footer or in an "integrations" section. Use the symbol-only variant if space is tight.

## Sei-specific notes

- **The brand kit may evolve** as Sei goes through the Sei Giga upgrade and SIP-03 transitions — re-fetch periodically.
- **Sei Foundation** (https://www.seifdn.org) is the legal entity behind funding and partnership programs; sei.io is the marketing/community face. They share branding but operate as distinct entities.
- **For agent-driven asset use**, prefer fetching the SVG directly from brandfolder.com/sei-0 over caching a copy that may go stale.

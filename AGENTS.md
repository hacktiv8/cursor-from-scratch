## Development

When starting the dev server, use background mode:

```
astro dev --background
```

Manage the background server with `astro dev stop`, `astro dev status`, and `astro dev logs`.

## Documentation

Full documentation: https://docs.astro.build

Consult these guides before working on related tasks:

- [Adding pages, dynamic routes, or middleware](https://docs.astro.build/en/guides/routing/)
- [Working with Astro components](https://docs.astro.build/en/basics/astro-components/)
- [Using React, Vue, Svelte, or other framework components](https://docs.astro.build/en/guides/framework-components/)
- [Adding or managing content](https://docs.astro.build/en/guides/content-collections/)
- [Adding styles or using Tailwind](https://docs.astro.build/en/guides/styling/)
- [Supporting multiple languages](https://docs.astro.build/en/guides/internationalization/)

## Design Context

See [PRODUCT.md](./PRODUCT.md) for full product and design strategy.

- **Register:** product (utility UI; design serves the task)
- **Users:** wall-display glance — distance, ambient, no interaction
- **Purpose:** instant, glanceable realtime date/time
- **Personality:** calm, clear, steady
- **Anti-references:** SaaS marketing pages
- **Principles:** glance first · calm over spectacle · one job · hierarchy over clutter · restraint
- **A11y:** big text, clear contrast, distance-readable type; honor `prefers-reduced-motion`

## Learned User Preferences

- Prefers Indonesian for product-facing UI copy and feature discussion
- Prefers TDD (red → green → refactor) with tidy-first separation of structural vs behavioral commits
- Prefers project-scoped Cursor agents and skills (`.cursor/`) over user-level for this repo
- When offered MVP vs flagship polish, prefers the flagship-quality pass
- Monetization evaluation should run only when explicitly requested; deliver a ranked list with effort/impact, starting from low-hanging fruit
- Keep the wall-clock surface free of ads, CTAs, and paywalls; monetize off-display

## Learned Workspace Facts

- Product is Waktu ("The Lime Field Clock"): a glanceable realtime date/time wall display
- Indonesian zones shown side by side: WIB (`Asia/Jakarta`), WITA (`Asia/Makassar`), WIT (`Asia/Jayapura`); the user's local Indonesian zone is highlighted larger when detected
- World comparison cities: London, New York, Tokyo, Dubai, Singapore, Sydney
- Visual system is documented in `PRODUCT.md` and `DESIGN.md` (Field Lime `#b8f000`, Fraunces + Sora)
- Project monetization-officer subagent lives at `.cursor/agents/monetization-officer.md`

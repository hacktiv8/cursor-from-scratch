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

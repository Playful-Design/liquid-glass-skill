# GLSL Glass Types: shortcuts

The kinds of glass (shard, prism, crystal) now live inside the [`liquid-glass`](../liquid-glass/) entry skill, in `liquid-glass/materials/`. That skill recognizes the glass automatically from the user's words or image, for any shape (background, lettering or card), and always delivers GLSL code.

This folder only holds three one-line **shortcuts**, for applying a glass to a shader you already have:

| Shortcut | What it does |
|---|---|
| `/shard` | Real broken window glass: clear faces, light shows at the edges, no rainbow |
| `/prism` | Optical-glass dispersion: clear body, color where the split light lands |
| `/crystal` | Cut-crystal optics: white sparkle, color only as small flecks |

Each saves `<name>.<glass>.glsl` next to the original and leaves the original unchanged. The physics is written once, in `liquid-glass/materials/<glass>.md`; the shortcuts only point to it.

Like every glass type, they **optimize, never create**: only index, dispersion, Fresnel, absorption and thin-film change. No lights, lines, shapes or effects are added. `glsl-liquid-glass` itself is never modified.

## Install

Install them **next to** `liquid-glass` (the shortcuts read `../liquid-glass/materials/`):

```bash
npx skills add ./liquid-glass --agent claude-code --global
npx skills add ./glsl-glass-types --skill '*' --agent claude-code --global
```

`examples/` holds the test results from tuning the types.

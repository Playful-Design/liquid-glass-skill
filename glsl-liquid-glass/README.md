# GLSL Liquid Glass

An Agent Skill that teaches an AI coding agent to write a complete, executable GLSL shader (`mainImage`) rendering an illuminated, viscid, and iridescent **"Liquid Glass"** surface, built from an explicit optical and physical specification.

> The agent reads [`SKILL.md`](./SKILL.md). This README is for humans.

---

## What it does

When triggered, the skill tells the agent to write the shader itself, not to summarize the spec, following a fixed architecture:

| Stage | What the spec defines |
| --- | --- |
| `thinFilmPalette(phase)` | Cyclical thin-film interference spectrum (Inigo Quilez cosine palette) |
| `sampleEnv(R, shift)` | Procedural studio HDR environment with two softbox bands, no external textures |
| Normals | Finite-difference normals from the height field (`eps = 0.006`, `bumpStrength = 0.55`) |
| Fresnel | Schlick approximation, `F0 = 0.12`, power `4.5` |
| Dispersion | Three refracted rays with IOR Red `1.48`, Green `1.52`, Blue `1.56` |
| Absorption | Beer-Lambert attenuation with extinction coefficients `[0.75, 0.35, 0.18]` |
| Lighting | Iridescent reflections plus dual Blinn-Phong specular (key and fill lights) |
| Post-processing | Radial vignette, exposure `1.15`, ACES filmic tone mapping, gamma `1/2.2` |

Every constant and formula is listed in [`SKILL.md`](./SKILL.md).

## What problems it solves

- **Inconsistent results.** Without a spec, "make a glass shader" yields a different, often flat, look every time. This skill pins down the exact functions, constants, and pipeline order.
- **Missing physics.** It makes the agent implement Fresnel, chromatic dispersion, volumetric absorption, and thin-film iridescence instead of faking glass with a transparent tint.
- **Agents that explain instead of code.** The skill tells the agent to produce working GLSL directly.

## When to use it

Use it when you want an agent to write GLSL for:

- a glass, crystal, or optical liquid shader
- a "liquid glass" surface with iridescence and refraction
- a prism-like effect with chromatic separation along edges

Skip it for non-GLSL rendering work or for materials unrelated to glass and optics.

## Package contents

```
glsl-liquid-glass/
├── SKILL.md    # The skill: frontmatter + full technical specification
└── README.md   # This file
```

There are no scripts, dependencies, or assets. The environment is procedural, so the shader needs no texture files.

---

## Installation

### Option A: Vercel Skills CLI (recommended)

The [Skills CLI](https://github.com/vercel-labs/skills) copies or links the skill into the folder your agent reads from.

**From a local folder** (run from the directory that contains `glsl-liquid-glass/`):

```bash
# Preview what will be installed (installs nothing)
npx skills add ./glsl-liquid-glass --list

# Install for Claude Code, in the current project only
npx skills add ./glsl-liquid-glass --agent claude-code

# Or install for Claude Code globally (every project)
npx skills add ./glsl-liquid-glass --agent claude-code --global
```

**From GitHub** (after you push this folder to a repository):

```bash
npx skills add Playful-Design/liquid-glass-skill --skill glsl-liquid-glass --agent claude-code
```

Manage it later with:

```bash
npx skills list                       # see installed skills
npx skills remove glsl-liquid-glass   # uninstall
```

### Option B: Manual copy

Copy the `glsl-liquid-glass/` folder into one of these:

- `~/.claude/skills/` to make it available in every project
- `.claude/skills/` inside a project to make it available in that project only

## Using it with Claude Code

1. Install the skill (see above), then start Claude Code in your project:
   ```bash
   claude
   ```
2. Ask for a glass shader in plain language. Claude matches your request against the skill's `description` and loads it automatically.
3. You can also invoke it directly by typing:
   ```
   /glsl-liquid-glass
   ```

## Example prompts

- "Write me a liquid glass GLSL shader."
- "Code an iridescent crystal shader with chromatic dispersion in GLSL."
- "/glsl-liquid-glass Make the surface animate slowly over time."
- "Create an optical liquid glass shader and put it in `liquid-glass.frag`."
- "I need a glass shader with a prism effect on the edges and deep blue valleys."

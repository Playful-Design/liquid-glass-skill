---
name: polished
description: Gives an existing GLSL glass shader a crisp, mirror-polished finish with tight bright highlights and sharp reflections by adjusting only its existing specular, reflection, Fresnel-weighting and iridescence parameters. Use when the user runs /polished or asks for polished, glossy, mirror-like, shiny, crisp, lacquered or high-gloss glass.
---

# /polished: crisp, mirror-finish glass

**Design intent:** this skill is about the **finish** of the surface, not its shape. The microsurface is perfectly polished: highlights become small, tight and intense; reflections of the studio softboxes are crisp and high-contrast; edges catch a clean bright rim. The body of the glass (color, density, transparency) and the surface shape stay the same. Polished does not mean blown-out or glaring.

This skill builds on the pipeline described in the `/glsl-liquid-glass` skill and only adjusts what that pipeline already contains.

## 1. Inspect first
Read the whole shader before editing. Map each parameter to its role from the code:
- Blinn-Phong specular exponents and intensities (key, fill)
- rim term exponent and intensity
- reflection sampling (`sampleEnv(R, …)`) and any blur, tap loop or roughness already applied to it
- iridescence blend on reflections
- Fresnel form and `F0`

If a blur / roughness / multi-tap loop exists (e.g. from `/frost`), reduce its radius toward zero rather than deleting code. **Never add new functions or uniforms.**

## 2. Levers (priority order)
| Lever | Direction | Kind |
|---|---|---|
| Specular exponents | raise (e.g. key 180 → 300–400, fill 90 → 150–200) | Artistic approximation of a smoother microsurface |
| Specular intensities | raise in proportion to `(n + 8)`, so total highlight energy stays similar (narrower lobe → higher peak) | Physically motivated (energy conservation) |
| Existing reflection/refraction blur | reduce radius toward 0 if present | Approximation: polished surfaces don't scatter |
| Rim exponent | raise moderately so the halo tightens; lower its intensity slightly | Artistic: cleaner edge, less haze |
| Iridescence blend on reflections | keep or lower slightly, so reflections read as clean mirror images | Artistic |

## 3. Do not touch
- Height field, `bumpStrength`, `eps` (that is `/smooth` or `/textured`).
- `F0` and the Fresnel exponent: polish changes lobe sharpness, not base reflectance.
- IOR values, dispersion order and shifts.
- Absorption, thickness, valley shading.
- Environment, lights' directions, camera, vignette, exposure, tone mapping, gamma.

## 4. Keep it physically coherent
- Keep reflection and refraction blended by Fresnel; keep the pipeline order.
- Check that the tightest highlight still isn't a single-pixel sparkle that aliases: if it shimmers under animation, back the exponent off.
- Deterministic output, no noise.

## 5. Output
- Unless told otherwise, save a new file next to the original (`<name>.polished.glsl`); leave the original unchanged.
- Add a short header comment listing the changes.
- Report a table: **parameter | before | after | physical or artistic | why**, plus anything skipped because it didn't exist.

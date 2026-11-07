---
name: textured
description: Gives an existing GLSL glass shader visible surface relief, like hammered, rippled or cast glass, by enriching only its existing smooth height field and normal strength, with no noise or grain. Use when the user runs /textured or asks for textured, hammered, rippled, wavy, embossed, cast or patterned glass.
---

# /textured: hammered / rippled relief glass

**Design intent:** this skill is about the **shape** of the surface at a finer scale. The glass shows clear, readable relief (dimples, ripples, waves) that breaks up refraction and reflection into many small distorted images, while each facet stays polished and sharp. Textured does not mean frosted, noisy or grainy: every bump is smooth and deterministic.

This skill builds on the pipeline described in the `/glsl-liquid-glass` skill and only adjusts what that pipeline already contains.

## 1. Inspect first
Read the whole shader before editing. Map each parameter to its role from the code:
- height field: wave terms (amplitude, frequency, phase, speed), domain-warp terms
- `bumpStrength`, finite-difference `eps`
- downstream uses of `h` (surface `z`, `thickness`, `baseShift`, `filmPhase`, valley shading)

**Never add new functions, uniforms or noise.** Extra relief must come from the existing `sin`/`cos`/`length` terms.

## 2. Levers (priority order)
| Lever | Direction | Kind |
|---|---|---|
| Frequency of the finer height terms | raise (≈ 1.5–2.5×) | Geometric: smaller, more numerous ripples |
| Amplitude of the finer height terms | raise relative to the broad term | Geometric: makes the relief readable |
| `bumpStrength` | raise moderately (≈ 0.55 → 0.75–0.9) | Geometric: steeper facets, stronger refraction break-up |
| Domain-warp amplitude/frequency | raise a little for organic, hammered irregularity | Geometric |
| Finite-difference `eps` | lower if needed (e.g. 0.006 → 0.004) so the finer relief is resolved | Numerical |

Keep the total height range roughly the same (rebalance weights) so `thickness`, absorption tint, dispersion shift and iridescence phase keep their character. Extend an existing term rather than adding a new one; if you must add a term, add it as one more line inside the existing `heightField` using the same `sin`/`cos` style.

## 3. Do not touch
- Specular exponents and intensities, rim terms (highlights stay sharp; that is `/polished` or `/frost`).
- IOR values, dispersion order and shifts, Fresnel form and `F0`.
- Absorption coefficients, thickness formula, valley shading.
- Environment, lights, camera, vignette, exposure, tone mapping, gamma.

## 4. Keep it physically coherent
- The height field must stay continuous and smooth (no `fract`, `floor`, `step` or hash).
- Watch for aliasing: if the finest frequency shimmers at the shader's resolution, lower it.
- Keep the pipeline order and function structure; deterministic output.

## 5. Output
- Unless told otherwise, save a new file next to the original (`<name>.textured.glsl`); leave the original unchanged.
- Add a short header comment listing the changes.
- Report a table: **parameter | before | after | physical or artistic | why**, plus anything skipped because it didn't exist.

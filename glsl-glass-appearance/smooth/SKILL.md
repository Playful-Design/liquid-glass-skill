---
name: smooth
description: Makes the surface of an existing GLSL glass shader calmer, softer and more rounded, with gentle undulations and no ripples or creases, by adjusting only its existing height field and normal parameters. Use when the user runs /smooth or asks for smoother, calmer, gentler, softer-shaped, rounder or less wavy glass.
---

# /smooth: calm, gently rounded glass surface

**Design intent:** this skill is about the **shape** of the surface, not its finish. The glass reads as a slow, viscous, rounded mass: broad gentle swells, no small ripples, no sharp creases. Highlights stay as sharp as they were; they simply glide over softer curves. Smooth does not mean flat or lifeless; some broad motion must remain.

This skill builds on the pipeline described in the `/glsl-liquid-glass` skill (height field → finite-difference normals → Fresnel → dispersion → Beer-Lambert → iridescence + Blinn-Phong → post). It only adjusts what that pipeline already contains.

## 1. Inspect first
Read the whole shader before editing. Map each parameter to its role from the code, not from names alone:
- height field: each wave term's amplitude and frequency, domain-warp amplitudes and frequencies, time speeds
- normal construction: `bumpStrength`, finite-difference `eps`
- any place `h` is reused downstream (surface `z` scale, `thickness`, `baseShift`, `filmPhase`, valley shading)

**Never add new functions, uniforms or noise.**

## 2. Levers (priority order)
| Lever | Direction | Kind |
|---|---|---|
| `bumpStrength` | lower moderately (≈ 0.55 → 0.30–0.40) | Geometric: shallower slopes, softer refraction bending |
| High-frequency height terms | lower their amplitude clearly (≈ halve) or lower their frequency; keep the broadest term dominant | Geometric: removes small ripples |
| Domain-warp amplitudes | lower (≈ 30–50 %) | Geometric: fewer pinched, creased folds |
| Finite-difference `eps` | may raise slightly (e.g. 0.006 → 0.009) | Numerical: smoother normals, no detail loss at the new scale |
| Animation speeds | optionally slow slightly (≈ 10–25 %) | Artistic: reads as more viscous |

Keep the total height range roughly the same (renormalise term weights if needed) so that `thickness`, absorption tint, dispersion shift and iridescence phase, which all depend on `h`, keep their character.

## 3. Do not touch
- Specular exponents and intensities, rim terms (that is `/polished` or `/frost`).
- IOR values, dispersion order and shifts, Fresnel form and `F0`.
- Absorption coefficients, thickness formula, valley shading (that is `/transparent` or `/translucent`).
- Iridescence blend, environment, lights, camera, vignette, exposure, tone mapping, gamma.

## 4. Keep it physically coherent
- The height field must stay smooth and continuous (C² as in the original), built only from its existing sines and warps.
- Keep the pipeline order and function structure.
- Output must remain deterministic for a given `fragCoord` and `iTime`.

## 5. Output
- Unless told otherwise, save a new file next to the original (`<name>.smooth.glsl`); leave the original unchanged.
- Add a short header comment listing the changes.
- Report a table: **parameter | before | after | physical or artistic | why**, plus anything skipped because it didn't exist.

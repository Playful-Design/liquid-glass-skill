---
name: transparent
description: Makes an existing GLSL glass shader clear and see-through, with a crisp undistorted view of what lies behind, little tint and little darkening, by adjusting only its existing absorption, path-length and valley-shading parameters. Use when the user runs /transparent or asks for clear, see-through, colorless, water-clear, crystal-clear or less tinted glass.
---

# /transparent: clear, see-through glass

**Design intent:** this skill is about the **body** of the glass. Light passes through almost unattenuated: the transmitted view is bright, sharp and nearly colorless, with only a faint tint in the thickest areas. Dispersion fringes and Fresnel reflections remain, so it still reads as glass and not as empty space. Transparent does not mean invisible.

This skill builds on the pipeline described in the `/glsl-liquid-glass` skill and only adjusts what that pipeline already contains.

## 1. Inspect first
Read the whole shader before editing. Map each parameter to its role from the code:
- Beer-Lambert absorption coefficients (per channel) and the path-length multiplier
- `thickness` formula and clamp range
- valley shading / depth darkening factor
- any blur, haze or milky lift applied to the refracted color (e.g. from `/frost` or `/translucent`)

**Never add new functions or uniforms.**

## 2. Levers (priority order)
| Lever | Direction | Kind |
|---|---|---|
| Absorption coefficients | lower uniformly (≈ 40–70 %), keeping their ratio so the faint residual tint keeps its hue | Physical (lower extinction) |
| Path-length multiplier | lower (e.g. 2.2 → 1.0–1.4) | Physical (thinner effective volume) |
| Valley shading | raise its floor (e.g. 0.55 → 0.8–0.9) | Artistic depth cue, reduced |
| Existing refraction blur or haze | reduce toward 0 if present | Approximation: clear glass doesn't scatter |

## 3. Do not touch
- IOR values and dispersion shifts: clarity is not about bending less; the prism fringes should stay visible.
- Fresnel form and `F0`: reflections at grazing angles are what keep it reading as glass.
- Specular exponents and intensities, rim, iridescence blend (surface finish).
- Height field, `bumpStrength`.
- Environment, lights, camera, vignette, exposure, tone mapping, gamma.

## 4. Keep it physically coherent
- Transmittance stays `exp(-absorption * thickness * k)` and stays ≤ 1: don't brighten beyond what the environment provides.
- Keep reflection and refraction blended by Fresnel; keep pipeline order.
- Deterministic output.

## 5. Output
- Unless told otherwise, save a new file next to the original (`<name>.transparent.glsl`); leave the original unchanged.
- Add a short header comment listing the changes.
- Report a table: **parameter | before | after | physical or artistic | why**, plus anything skipped because it didn't exist.

---
name: translucent
description: Makes an existing GLSL glass shader translucent, letting light through as a soft milky glow while hiding a clear view of what lies behind, by adjusting its existing absorption and refraction sampling. Use when the user runs /translucent or asks for translucent, milky, opalescent, cloudy, alabaster, jade-like or light-diffusing glass.
---

# /translucent: milky, light-diffusing glass body

**Design intent:** this skill is about the **body** of the glass. Light enters and scatters inside the volume, so the glass glows softly with its own tint, and what lies behind is no longer readable. Thick areas look denser and more saturated, thin areas lighter. The surface finish stays the same: highlights and Fresnel reflections remain as sharp as before, sitting on top of the soft body. Translucent does not mean frosted (rough surface) or opaque (no light through).

This skill builds on the pipeline described in the `/glsl-liquid-glass` skill and only adjusts what that pipeline already contains.

## 1. Inspect first
Read the whole shader before editing. Map each parameter to its role from the code:
- Beer-Lambert absorption coefficients and the path-length multiplier
- `thickness` formula and valley shading
- the per-channel `refract` calls and the `sampleEnv` calls they feed
- the ambient gradient inside `sampleEnv` (read only; used to understand the base level of light)
- any existing refraction blur loop (e.g. from `/frost`): if one exists, reuse it and add nothing else

**Never add new functions or uniforms.**

## 2. Levers (priority order)
| Lever | Direction | Kind |
|---|---|---|
| Refraction blur (wide) | if none exists: inline loop averaging 6–8 taps of the existing per-channel `refract` + `sampleEnv`, `N` tilted by a fixed offset at evenly spaced angles, radius larger than frost (≈ 0.18–0.30) so the background dissolves. No hash, no random. **Refraction only, not reflection** | Approximation of volume scattering |
| Absorption balance | make coefficients closer to each other and moderately lower overall, so the tint is soft and pastel rather than deep | Physical (scattering-dominated rather than absorption-dominated medium) |
| Path-length multiplier | keep or raise slightly so thickness differences read as density | Physical |
| Valley shading | keep; optionally lower its floor a little to strengthen the thick-is-denser cue | Artistic depth cue |

## 3. Do not touch
- Specular exponents and intensities, rim, reflection sampling: the surface stays glossy (otherwise it is `/frost`).
- IOR values and dispersion order (dispersion fades through the blur on its own).
- Fresnel form and `F0`.
- Height field, `bumpStrength`.
- Iridescence blend, environment, lights, camera, vignette, exposure, tone mapping, gamma.

## 4. Keep it physically coherent
- Transmittance stays `exp(-absorption * thickness * k)` ≤ 1; no added emission or constant brightness lift.
- Keep reflection and refraction blended by Fresnel; keep pipeline order.
- Deterministic and stable over time.
- State the performance cost: about N× the refraction sampling for N taps.

## 5. Output
- Unless told otherwise, save a new file next to the original (`<name>.translucent.glsl`); leave the original unchanged.
- Add a short header comment listing the changes.
- Report a table: **parameter | before | after | physical or artistic | why**, plus anything skipped because it didn't exist.

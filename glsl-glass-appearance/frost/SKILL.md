---
name: frost
description: Gives an existing GLSL glass shader a frosted, satin, micro-rough finish with broad soft highlights and a diffused view through the glass, by adjusting its existing specular, refraction, reflection and iridescence code. Use when the user runs /frost or asks for frosted, satin, sandblasted, etched, matte or acid-etched glass.
---

# /frost: micro-rough, diffusing glass finish

**Design intent:** this skill is about the **finish** of the surface. The microsurface is rough, so light scatters at the interface: the view through the glass and the reflections go soft, highlights spread into broad glows, thin-film color washes out. The body (color, density) and the surface shape stay the same. Frost does not mean noisy, grainy or opaque.

This skill builds on the pipeline described in the `/glsl-liquid-glass` skill and only adjusts what that pipeline already contains.

## 1. Inspect first
Read the whole shader before editing. Map each parameter to its role from the code:
- Blinn-Phong specular exponents and intensities, rim term
- the `refract` calls and the `sampleEnv` calls they feed (per channel)
- reflection sampling `sampleEnv(R, …)`
- iridescence blend on reflections
- any existing blur / roughness / tap-count parameter: if one exists, increase it and add nothing else

**Never add new functions or uniforms.**

## 2. Levers (priority order)
| Lever | Direction | Kind |
|---|---|---|
| Specular exponents | lower substantially (e.g. key 180 → 30–50, fill 90 → 20–30) | Artistic approximation of roughness |
| Specular intensities | lower in proportion to `(n + 8)`, keeping total highlight energy similar | Physically motivated (energy conservation) |
| Refraction blur | only if none exists: inline loop averaging 4–8 taps of the existing per-channel `refract` + `sampleEnv`, each with `N` tilted by a fixed offset at evenly spaced angles (radius ≈ 0.05 satin → 0.14 sandblasted). No hash, no random | Approximation of interface scattering |
| Reflection blur | same taps applied to `reflect(-V, Nk)`, inside the same loop | Approximation |
| Rim term | lower exponent and intensity | Artistic |
| Iridescence blend | reduce clearly (≈ 0.65 → 0.25–0.35) | Artistic: scattering washes out thin-film color |

## 3. Do not touch
- Absorption, thickness, valley shading: frost is a surface property, not a body property (that is `/translucent`).
- IOR values and dispersion order: dispersion softens through the blur on its own.
- Fresnel form and `F0`.
- Height field, `bumpStrength`: never fake roughness with noise in the height or normals.
- Environment, lights, camera, vignette, exposure, tone mapping, gamma.

## 4. Keep it physically coherent
- Keep reflection and refraction blended by Fresnel; keep pipeline order and function structure.
- Deterministic and stable over time.
- State the performance cost: about N× the environment sampling for N taps. If the radius is above ≈ 0.12, use 8 taps to avoid visible ghost images.

## 5. Output
- Unless told otherwise, save a new file next to the original (`<name>.frost.glsl`); leave the original unchanged.
- Add a short header comment listing the changes.
- Report a table: **parameter | before | after | physical or artistic | why**, plus anything skipped because it didn't exist.

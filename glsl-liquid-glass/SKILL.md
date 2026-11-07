---
name: glsl-liquid-glass
description: Architectural, optical, and physical specifications for programming an iridescent Liquid Glass GLSL shader (mainImage) with thin-film iridescence, Fresnel reflection, RGB chromatic dispersion, Beer-Lambert absorption, dual Blinn-Phong specular lighting, and ACES tone mapping. Use whenever the user asks to code a glass, crystal, or optical liquid shader, or asks for a liquid glass, iridescent, refractive, or prism-like GLSL effect. Supports two material modes: `iridescent` (backgrounds, lettering) and `natural` (crystals, gems, cut glass, any object with its own volume), with two natural-mode options: `prism` (prisms, cut crystal, gems: spectral rainbow, internal bounces, rainbow caustics) and `broken` (shattered or cracked glass: shards and chipped edges catching the light).
---

# Skill: "Liquid Glass" Physical & Optical Architecture (GLSL)

## 1. Expected Role and Behavior
You are an expert GLSL shader developer specializing in physical optics.
As soon as this skill is triggered, you must write yourself a complete, executable GLSL shader (`mainImage`) that renders an illuminated, viscid, and iridescent "Liquid Glass" surface.
Do not summarize this document: use these functional and physical specifications to directly program the corresponding GLSL code based on the user's request.

---

## 1b. Material Mode: `iridescent` vs `natural` (READ BEFORE CODING)

The spec below describes the **`iridescent`** mode, designed for a surface that fills the frame (background) or for lettering. It is NOT appropriate for a standalone object: applied to a crystal, gem, bottle or cut glass it floods the whole volume with pink/turquoise/violet, whereas real clear glass is almost colorless (color appears only as thin dispersion fringes on edges and as reflections of the environment).

Choose the mode before writing code:

| Target | Mode |
|---|---|
| Background, full-frame surface, lettering | `iridescent` (default, everything below as written) |
| Crystal, gem, bottle, cut glass, sculpture, any object with its own silhouette, or a picture of one | `natural` |
| The user says `glass natural` / `glass iridescent` | Obey, whatever the target |
| Prism, cut crystal, gem, rainbow light through glass / broken, shattered, cracked glass | `natural` + option `prism` / `broken` (section 1d) |

If the target is ambiguous, say which mode you picked in one line.

### `natural` mode: overrides to the pipeline (everything not listed stays unchanged)

| Item | `iridescent` (default) | `natural` |
|---|---|---|
| Thin-film mix on reflections (step 5) | `65%` over the whole surface | `<= 8%`, weighted by `pow(1.0 - NdotV, 3.0)` so it only touches rims |
| Dispersion shift (step 3) | `+0.22 / 0.00 / -0.22` | `+0.05 / 0.00 / -0.05`; IOR `1.51 / 1.52 / 1.53` |
| Extinction coefficients (step 4) | `[0.75, 0.35, 0.18]` (night blue valleys) | `[0.06, 0.05, 0.04]` (near neutral); no navy tint, no hue shift |
| `sampleEnv` softboxes (function B) | band 1 tinted by `thinFilmPalette` | band 1 and band 2 both white/neutral; ambient grey-blue, no palette |
| Fill light `L2` | tinted by iridescence | neutral white |
| Body color | tinted by refraction + absorption | near-white, almost transparent; the dominant read is the refracted background and sharp facet reflections |

Rule of thumb: in `natural` mode, if more than a few percent of the object's pixels show a saturated hue, the result is wrong. Color belongs on facet edges and rims only.

---

## 1c. Reflections and Polish (both modes)

Known defects to avoid:

- **Streaks / starburst lights in every direction** around cut edges. Causes: ultra-sharp environment bands (`0.75..0.99`) evaluated on noisy or discontinuous normals, `atan(R.z, R.x)` seam, and unbounded specular. Required fixes:
  1. Never add radial blur, god rays, star bloom or per-pixel streak effects.
  2. On a faceted or cut shape, give each facet ONE flat normal (no bump noise inside a facet) and compute reflections per facet.
  3. Anti-alias band edges: replace a hard `smoothstep(a, b, x)` by a width of at least `fwidth(x)` (or `2.0 / iResolution.y` in angle units).
  4. Clamp highlights before tone mapping: `spec = min(spec, 2.5)` then a soft shoulder (`spec = spec / (1.0 + 0.25 * spec)`), so edges do not clip to pure white or break into dashes.
  5. Use at most 2 or 3 light panels in the environment; no extra random bands.
- **Smooth edges that don't look polished.** A real polished edge has three cues; implement all three:
  1. A **thin, crisp Fresnel rim line**: `rimLine = smoothstep(0.80, 0.95, 1.0 - NdotV)` (edge width ~1 to 2 px), mostly white in `natural` mode.
  2. A **specular band that follows the curvature**: keep normals smooth (`C^2` height or analytic normals, no noise), so the softbox reflection bends continuously along the contour.
  3. A **subtle dark inner line** just inside the rim (internal reflection): multiply the body by `1.0 - 0.25 * smoothstep(0.55, 0.80, 1.0 - NdotV) * (1.0 - rimLine)`.
- The `frost` finish is the only case where the polish cues above are softened.

Add the result of these cues after the Fresnel blend (step 5) and before post-processing (step 6).

---

## 1d. Optical options for `natural` mode: `prism` and `broken`

Two add-ons for glass that throws light around. Both keep the `natural` overrides (clear, near-neutral glass) and the 1c rules, and add what the base pipeline cannot do: light split into a real rainbow, light bouncing inside the glass, and light caught by small faces.

| The user says | Option |
|---|---|
| prism, crystal, cut glass, gem, diamond, "rainbow light through glass", "light refracting through a prism", `glass prism` | `prism` |
| broken, shattered, cracked, smashed glass, "light through the broken pieces", `glass broken` | `broken` |

Tested references (rendered and checked): `examples/prism.glsl` (`#define SHAPE 0` triangular prism, `1` brilliant-cut gem) and `examples/broken-glass.glsl`. Start from them rather than from scratch.

### Shared: spectral dispersion (replaces the 3-ray RGB split)
Three rays (R, G, B) spread far apart give three separate colored ghosts, not a rainbow. Trace `N_WL` wavelengths (6 to 7; 3 only as a fallback for weak GPUs), each with its own IOR from Cauchy's law, and add them back with weights that sum to white:

```glsl
float gauss(float x, float m, float s) { float u = (x - m) / s; return exp(-0.5 * u * u); }
vec3  wlColor(float l) {   // linear RGB response of one wavelength (nm)
    return vec3(gauss(l, 600.0, 42.0) + 0.28 * gauss(l, 420.0, 20.0), gauss(l, 545.0, 42.0), gauss(l, 455.0, 30.0));
}
float wlAt(int i) { return mix(410.0, 690.0, (float(i) + 0.5) / float(N_WL)); }
float iorAt(float l) {     // Cauchy n = A + B / lambda^2 (micrometres); boost keeps the mean IOR
    float u = l * 1e-3, nMid = glassA + glassB / 0.3025;
    return nMid + dispersionBoost * (glassB / (u * u) - glassB / 0.3025);
}
// per pixel: wsum = sum of wlColor(wlAt(i)); color += radiance_i * wlColor(wlAt(i)) / wsum;
```

| Glass | `glassA` | `glassB` | `dispersionBoost` |
|---|---|---|---|
| Window / crown glass | `1.5046` | `0.0042` | `1` (physical); `5` on broken chips |
| Flint / lead crystal (prism, chandelier) | `1.5900` | `0.0110` | `2.5` to `4` (stylised fire) |

Color appears only where geometry makes it: at steep exit angles, on facet edges and on chips. Flat faces seen head-on stay clear. This replaces the `natural` table's `+0.05 / 0 / -0.05` shift for these two options.

**Use an explicit `refr()`**, not the built-in `refract()`, everywhere in these options (it returns `vec3(0)` on total internal reflection, and some drivers get the built-in wrong near the critical angle):

```glsl
vec3 refr(vec3 I, vec3 N, float eta) {
    float c = -dot(N, I), k = 1.0 - eta * eta * (1.0 - c * c);
    return k <= 0.0 ? vec3(0.0) : normalize(eta * I + (eta * c - sqrt(k)) * N);
}
```

Use a real dielectric Fresnel (`F0 = ((n1 - n2) / (n1 + n2))^2`, about `0.04` to `0.05`, with the transmitted cosine when going from glass to air, and `1.0` beyond the critical angle), not the stylised `F0 = 0.12`. Always `pow(clamp(1.0 - c, 0.0, 1.0), 5.0)`: `pow` of a negative number is undefined on GPUs and shows up as speckles.

### Option `prism`: cut glass, prisms, gems

1. **Geometry: a convex polyhedron, not an SDF.** Describe the object as a list of planes `vec4(outwardNormal, d)` (inside where `dot(n, p) < d`) and intersect rays exactly: entry = the largest `t` over planes the ray enters, exit (from inside) = the smallest positive `t` over planes with `dot(n, d) > 0`. Facets are perfectly flat (1c rule 2), edges are razor sharp and it costs no raymarching. Transform the ray into object space with the object's rotation; turn the object slowly (`~0.2 rad/s`) so the rainbows sweep.
   - Triangular prism: 3 side planes at angles `-90°, 30°, 150°` with `d = inradius`, plus two caps `(0, 0, ±1)`.
   - Brilliant cut (33 planes): table `y = 0.33`; 8 crown planes at `34.5°`; 16 vertical girdle planes, `d = 1`; 8 pavilion planes at `40.75°`, rotated half a step from the crown. All passing through the girdle at `y = ±0.03`. Plane formulas: `examples/prism.glsl`, `facePlane()`.
2. **Internal bounces.** For each wavelength: refract in at the entry face, then loop `MAX_BOUNCES` (4) times: find the exit face, attenuate by `exp(-absorb * t)`, try to refract out. If it gets out, add `energy * (1 - F) * scene(exit)` and keep going with the reflected part (`energy *= F`). On total internal reflection, keep all the energy and reflect. After the loop, add the leftover energy along the last direction. These bounces make cut glass sparkle; a single exit looks like plastic.
3. **A small, bright light.** Rainbows only show when a small, intense source is split: put a sun disc in the environment (angular radius about `0.026`, intensity about `20`) next to the 2 softboxes (1c rule 5 still applies: 3 lights at most). On rays that have gone **through** the glass, widen the sun `×3` and divide its intensity by `9` (same energy): near the critical angle the refraction magnifies directions so much that a sharp disc aliases into grain.
4. **Floor, shadow and rainbow caustic (fake).** The camera never traces light from the sun, so add it:
   - Glass shadow: from the floor point toward the sun, test the polyhedron and multiply the direct light by `0.55` (glass lets light through), not `0`.
   - Caustic: once per pixel, before shading, trace ONE sun ray per wavelength through the upper part of the object (same bounce loop) and store where it lands on the floor. Draw a soft footprint of the beam there in that wavelength's color, scaled by its energy. `causticSpread` (about `4` to `9`) fans the colors out around the middle wavelength, because the true spread is tiny on a close floor. Soften the footprint edge more when the floor is seen through the glass, for the same aliasing reason as the sun.
5. **Polished facet edges** (1c cue 1, for flat facets): the in-face distance to the nearest other facet is `(d_j - dot(n_j, p)) / length(cross(n_j, n_entry))`. Without dividing by the sine of the angle between the facets, shallow edges become thick white bands. A bright line under about 1.8 px wide, plus a light darkening just inside it.
6. Reflection off the entry facet: once, with the middle IOR, clamped as 1c rule 4. Use 2×2 supersampling (`AA 2`); the facets are flat, so this is the only anti-aliasing they need.

### Option `broken`: shattered pane, light caught by the broken faces

A full-frame pane seen head-on, in screen space like the liquid surface (no raymarching), over a backdrop (procedural, the liquid surface, or the user's image). What makes broken glass read is not the crack lines but the **light**: each shard catches it differently, and the small chipped faces along the cracks act as tiny prisms.

1. **Crack field** `crackField(p)` (p relative to the impact point) returns the distance to the nearest crack, the 2D unit vector from that crack toward `p`, and a shard id:
   - **Radial cracks** (`RADIAL` 13): angles evenly spaced with `±37%` jitter and a gentle smooth wander along the radius. About 45% stop at a random radius. A crack that stops **does not split** the glass: shard ids come only from the full-length cracks. Otherwise the tilt jumps along an invisible arc, which shows as a ghost circle.
   - **Ring cracks:** in each sector, straight **chords** between the two neighbouring radial cracks (real ring cracks are polygonal, not circles), at radii `ring0 · growth^j` (`0.045`, `×1.75`), with each endpoint jittered `±15%` independently, so neighbouring sectors do not line up into a spider web. About 45% of chords are missing (longer shards). The ring index (chords crossed) plus the sector make the shard id.
   - **Crushed zone** (radius `0.035`) at the impact: small Voronoi chips, whitened like frost.
   - Crack width `mix(0.0030, 0.0010, r)`, never below `0.9 px`.
2. **One flat normal per shard:** tilt `(hash(id) - 0.5) * 2 * shardTilt`, `shardTilt ≈ 0.09`, stronger near the impact. Each shard therefore reflects the softbox at its own moment (a whole shard flashes) and shifts the backdrop by its own amount (the view behind breaks up). No noise inside a shard.
3. **Chipped (conchoidal) bevel** along every crack, over `chipWidth ≈ 4.5` crack widths (varying per shard): the normal bends toward the crack, `N += vec3(-crackDir * (1 - x)^2 * 1.6 * shell, 0)`, with `x` = distance / chip width and `shell = 1 + 0.35 * sin(14 * x + phase)` (smooth shell ripples, no noise). These steep little faces carry the dispersion: transmission is sampled per wavelength, and the offset `refr(...).xy / -z * thickness` is large only there, so rainbow fringes appear along the cracks and nowhere else.
4. **Lit chips:** add `chip * pow(max(dot(crackDir, -L.xy), 0), 3)` in a wavelength color running along the chip: the broken faces turned toward the light throw colored light.
5. **The crack itself** is an air gap: light reflects inside it. Brightness `0.12 + 1.6 * pow(|dot(crackDir, L.xy)|, 6)`, so only the parts of the cracks facing the light glint, mixed 55% with a spectral fringe. Anti-alias with `fwidth`. Add a thin dark line just outside it (1c cue 3).
6. **Moving light:** the reflected softbox and the light direction `L` drift slowly (`~0.3 rad/s`), so the glints travel from shard to shard and along the cracks. This is the main effect; a still light makes broken glass look like a drawing.
7. Reflection: window-glass Fresnel (`F0 = 0.04`), softbox intensity about `14` so that a shard reflecting it reads clearly. Highlights clamped (1c rule 4). Faint green-grey absorption, stronger on the chips (edge of window glass).

### Pitfalls found while testing (all produced colored per-pixel grain)
- An object resting on the floor: its bottom face lies ON the floor plane. Clamp the floor distance `t = max(t, 0)` for rays leaving through that face, and start shadow rays a little above the floor (`+0.002`). Otherwise the sign is pure rounding noise.
- Far floor: return the environment beyond about 16 units instead of shading the floor (shadow tests at huge coordinates are noise).
- After each internal reflection, nudge the point inside (`p -= n * 1e-4`).
- Any sharp feature seen through the glass (sun disc, caustic edge) must be softened on transmitted rays.

---

## 2. Art Direction and Target Visual Appearance
(Describes the `iridescent` mode; in `natural` mode keep the polished, sharp-reflection look but drop the night-blue tint and the rainbow coating.)
The final result must strictly achieve the following look:
- **Material**: Dense, thick, ultra-smooth, and polished glass, completely free of noise or micro-artifact grain, conveying a sense of moving viscous liquid.
- **Internal Optics**: Visible chromatic separation along refracted edges (prism effect) and light absorption that tints deep valleys in intense night blue while keeping crests bright and transparent.
- **Surface & Reflections**: High-contrast, sharp studio softbox reflections modulated by an iridescent thin-film coating (soap bubble / treated glass effect) shifting color based on viewing angle and thickness.

---

## 3. Mandatory Functions to Implement 

You must structure your code around the following functions while respecting their mathematical logic:

### A. `vec3 thinFilmPalette(float phase)`
- **Role**: Generate a cyclical thin-film interference spectrum (Inigo Quilez cosine palette).
- **Logic**: Compute `a + b * cos(2 * PI * (c * phase + d))` with `a = (0.5, 0.5, 0.5)`, `b = (0.5, 0.5, 0.5)`, `c = (1.0, 1.0, 1.0)`, and a chromatic phase shift `d = (0.00, 0.33, 0.67)`.

### B. `vec3 sampleEnv(vec3 R, float shift)`
- **Role**: Simulate a procedural studio HDR environment (without external textures) from a direction vector `R` (reflected or refracted) and a dispersion offset `shift`.
- **Logic**:
  1. Convert `R` to spherical coordinates: `pitch = asin(clamp(R.y, -1.0, 1.0))` and `yaw = atan(R.z, R.x)`.
  2. Create two softbox light bands using `smoothstep` on `sin` and `cos` functions combining `yaw`, `pitch`, and `shift` (band 1 smooth between `0.55` and `0.95`, band 2 very sharp and intense between `0.75` and `0.99`).
  3. Create a dark ambient background vertically graded from deep blue `(0.02, 0.04, 0.09)` to `(0.08, 0.14, 0.24)` to avoid fully crushed blacks.
  4. Add band 1 tinted by `thinFilmPalette` and band 2 in near-pure white at high intensity (`* 1.6`).

---

## 4. Physical Pipeline in `mainImage`

Inside the main function, after generating a smooth $C^2$ continuous surface (height `h`), sequentially program these physical phenomena:

1. **Analytical Normals via Finite Differences**:
   - Sample height at `uv`, `uv + (eps, 0)`, and `uv + (0, eps)` with `eps = 0.006`.
   - Build normal `N` from negative slopes multiplied by a relief strength (`bumpStrength = 0.55`), then normalize.
   - Compute view vector `V` from surface `(uv, h * 0.18)` to camera `(0, 0, 2.2)` and clamp `NdotV = max(dot(N, V), 0.001)`.

2. **Fresnel Equation (Schlick Approximation)**:
   - Use a base reflectivity for dense glass `F0 = 0.12` and a power of `4.5` on `(1.0 - NdotV)`.

3. **Spectral Chromatic Dispersion (Snell-Descartes Law)**:
   - Compute reflection vector `R = reflect(-V, N)`.
   - Split refraction into 3 distinct rays via `refract(-V, N, 1.0 / ior)` using precise indices of refraction: Red = `1.48`, Green = `1.52`, Blue = `1.56`.
   - Sample `sampleEnv` separately for `.r`, `.g`, and `.b` by offsetting the `shift` parameter (`+0.22`, `0.00`, `-0.22` added to `h * 1.2`).

4. **Beer-Lambert Volumetric Absorption**:
   - Evaluate local thickness `thickness = clamp(0.65 - h * 0.45, 0.1, 1.3)`.
   - Apply exponential attenuation `exp(-absorptionCoeff * thickness * 2.2)` with extinction coefficients `[0.75, 0.35, 0.18]` (absorbs red and green faster than blue).
   - Slightly darken deep valleys with a `smoothstep` on `h` and multiply the refracted color by these two factors.

5. **Iridescence and Dual Blinn-Phong Specular Lighting**:
   - Compute a thin-film phase dependent on viewing angle, height, and time (`NdotV * 2.4 + h * 1.6 - t * 0.15`) to tint environment reflections (`mix` at `65%`).
   - Place two studio directional lights:
     - **Key Light (`L1`)**: Direction `(0.6, 0.75, 0.85)`, half-vector `H1`, ultra-sharp specular (exponent `180.0`, intensity `3.8`) + broad rim halo (`rim1`, exponent `24.0`, intensity `0.45`).
     - **Fill Light (`L2`)**: Direction `(-0.75, -0.45, 0.65)`, secondary specular (exponent `90.0`, intensity `1.4`) tinted by iridescence.
   - Blend refraction and reflection using the `fresnel` factor, then add iridescent rim and specular highlights.

6. **Colorimetric Post-Processing**:
   - Apply a soft radial vignette preserving at least 45% luminance at the borders.
   - Apply an exposure of `1.15` followed by the **ACES Filmic Tone Mapping** curve `(col * (2.51 * col + 0.03)) / (col * (2.43 * col + 0.59) + 0.14)`.
   - Conclude with standard Gamma correction (`pow(col, 1.0 / 2.2)`).
---
name: glsl-glassmorphism
description: Generates a physically based crystal-glass UI button or card in GLSL (Shadertoy-compatible) in a pastel fluid world, with a static thick pill-shaped glass body, a mostly see-through 20% face, solid refractive edges, real dispersion and Total Internal Reflection. Use when asked for glass, crystal or glassmorphism UI that should look like real glass rather than a 2D blur.
---

# GLSL Crystal Glass Button

## Core principles

Use 3D raymarching with the building blocks below. Never fake the glass with a 2D blur (a CSS `backdrop-filter` is acceptable only as a no-WebGL fallback).

1. **One shared world.** The glass reflects and refracts the same light pastel fluid backdrop (`sampleBackgroundFluid`); reflections add two softboxes on top of it (`sampleStudioEnv`). Do not use a separate dark studio gradient for reflections: the glass then goes dull.
2. **Static glass, moving world.** The card never rotates or sways. Only the fluid backdrop animates. Pointer presence may lift highlights and dispersion slightly (`gEng`).
3. **Dense, luminous interior.** With `LUMINOUS_INTERIOR 1` the internal Fresnel angle is `dot(-rd, -nExit)`, which is always 0, so `fInternal` is 1 and the interior shows only internal reflection. This is physically incorrect but gives the bright, mirror-like crystal look, so it is the default. Set it to 0 for physically correct internal Fresnel (`dot(-rd, nExit)`).
4. **Mostly see-through face, solid edges.** The face is `GLASS_OPACITY = 0.20` of the glass body over the backdrop; opacity rises with edge curvature (`+ 0.65 * curvature`) so the bevel reads as solid glass. Specular band and rim are added after the blend at full strength.
5. **Thick, rounded edges.** `z = 0.055`, `bevelR = 0.045`; keep `bevelR <= z`. The 2D corner radius is decoupled from the bevel (a pill: `cornerR` = half the height).
6. **Clear volume and true dispersion.** `BEER_ABSORB = vec3(0.0)`, 7 wavelengths with Gaussian weights recombined to white, `iorBase = 1.15`, `dispersion = 0.015`.
7. **Light shadow.** About 8% darkening under the card with a tight falloff.
8. **Smooth silhouette.** Record the closest approach of every ray (`marchEntry`) and blend edge pixels with `clamp(0.5 - minD / pw, 0.0, 1.0)`, shading at the closest-approach point (flip the normal if `dot(N, rd) > 0.0`).
9. **Resolution-relative framing.** `P = min(iResolution.x * 0.84 / 1.8, iResolution.y * 0.24)` pixels per world unit. An HTML `<button>` overlay must use the same `P` in CSS pixels for size and radius.
10. **Portability.** GLSL ES 1.00 compatible: constant loop bounds, no `pow()` on negative bases (use `x * x`), and a minimum march step so rays never stall.

## Exact equations and building blocks

### 1. Defines
```glsl
#define MAX_STEPS 100
#define MAX_DIST 10.0
#define SURF_DIST 0.001
#define F0_GLASS 0.04
#define BEER_ABSORB vec3(0.0)          // zero absorption: perfectly clear glass
#define WL_BODY_STEPS 7                // wavelengths traced per pixel (3 is cheaper)
#define GLASS_OPACITY 0.20             // opacity of the glass face over the backdrop
#define LUMINOUS_INTERIOR 1            // 1: interior shows internal reflection only (dense, bright look)
                                       // 0: physically correct internal Fresnel

float gEng;                            // 0..1 pointer engagement (lifts highlights only)
```

### 2. Spectrum and soft shoulder
```glsl
// --- 1. Spectrum & soft shoulder ---
vec3 spectrumWeight(float u) {
    float a = (u - 0.12) / 0.22, a2 = (u - 0.90) / 0.12;
    float g = (u - 0.45) / 0.22, b = (u - 0.80) / 0.21;
    float r = exp(-a * a) + 0.26 * exp(-a2 * a2);
    return max(vec3(r, exp(-g * g), exp(-b * b)), 0.0);
}

vec3 softShoulder(vec3 x, float knee, float maxVal) {
    vec3 over = max(x - knee, vec3(0.0));
    vec3 compressed = knee + (maxVal - knee) * (1.0 - exp(-over / (maxVal - knee)));
    return mix(x, compressed, step(vec3(knee), x));
}
```

### 3. Geometry, normals and marches
```glsl
// --- 2. SDF: pill-shaped 2D outline, thick rounded 3D bevel (keep bevelR <= z) ---
float sdCard(vec3 p) {
    vec2 b2 = vec2(0.9, 0.32);
    float z = 0.055, cornerR = 0.32, bevelR = 0.045;
    vec2 q = abs(p.xy) - b2 + cornerR;
    float d2 = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - cornerR;
    vec2 w = vec2(d2, abs(p.z) - z + bevelR);
    return length(max(w, 0.0)) + min(max(w.x, w.y), 0.0) - bevelR;
}

vec3 calcNormal(vec3 p) {
    const float h = 0.0008;
    const vec2 k = vec2(1.0, -1.0);
    return normalize(
        k.xyy * sdCard(p + k.xyy * h) +
        k.yyx * sdCard(p + k.yyx * h) +
        k.yxy * sdCard(p + k.yxy * h) +
        k.xxx * sdCard(p + k.xxx * h));
}

// Inside march (signDir = -1.0) for internal bounces
void intersectCard(vec3 ro, vec3 rd, float signDir, out float tRes) {
    float t = 0.0;
    tRes = -1.0;
    for (int i = 0; i < MAX_STEPS; i++) {
        float d = sdCard(ro + rd * t) * signDir;
        if (d < SURF_DIST) { tRes = t; break; }
        if (t > MAX_DIST) break;
        t += max(d, SURF_DIST);
    }
}

// Entry march that also records the closest approach (edge anti-aliasing)
void marchEntry(vec3 ro, vec3 rd, out float tHit, out float minD, out float tMin) {
    float t = 0.0;
    tHit = -1.0; minD = 1e9; tMin = 0.0;
    for (int i = 0; i < MAX_STEPS; i++) {
        float d = sdCard(ro + rd * t);
        if (d < minD) { minD = d; tMin = t; }
        if (d < 0.0004) { tHit = t; return; }
        t += max(d, 0.0004);
        if (t > MAX_DIST) return;
    }
}
```

### 4. Lighting and fluid world
```glsl
// --- 3. Studio lighting & fluid world ---
float rectPanel(vec3 rd, vec3 centerDir, vec3 upHint, vec2 halfSize, vec2 softness) {
    vec3 f = normalize(centerDir);
    vec3 r = normalize(cross(f, upHint));
    vec3 u = cross(r, f);
    float fDot = dot(rd, f);
    if (fDot <= 0.0) return 0.0;
    vec2 uv = vec2(dot(rd, r), dot(rd, u)) / max(fDot, 0.15);
    vec2 d = abs(uv) - halfSize;
    float sx = 1.0 - smoothstep(0.0, softness.x, d.x);
    float sy = 1.0 - smoothstep(0.0, softness.y, d.y);
    return sx * sy * smoothstep(0.0, 0.35, fDot);
}

vec3 sampleBackgroundFluid(vec3 rd) {
    vec2 uv = rd.xy;
    float t = iTime * 0.4;
    uv.x += sin(uv.y * 3.5 + t) * 0.3;
    uv.y += cos(uv.x * 2.5 - t) * 0.3;

    vec3 col1 = vec3(0.54, 0.81, 0.94);
    vec3 col2 = vec3(0.70, 0.88, 0.97);
    vec3 col3 = vec3(0.85, 0.95, 1.00);
    float mix1 = smoothstep(-0.8, 0.8, sin(uv.x * 4.0 + uv.y * 2.0));
    float mix2 = smoothstep(-0.5, 0.5, cos(uv.y * 5.0 - uv.x * 3.0 + t * 1.5));
    vec3 bg = mix(col1, col2, mix1);
    bg = mix(bg, col3, mix2);

    float orb1 = smoothstep(0.4, 0.0, length(rd.xy - vec2(0.4, 0.3)));
    float orb2 = smoothstep(0.3, 0.0, length(rd.xy - vec2(-0.5, -0.4)));
    bg += vec3(0.9, 0.95, 1.0) * orb1 * 0.4;
    bg += vec3(0.4, 0.7, 0.9) * orb2 * 0.3;
    return bg;
}

// Glass reflects the same world it refracts, plus two softboxes
vec3 sampleStudioEnv(vec3 rd, bool isBackground) {
    vec3 bg = sampleBackgroundFluid(rd);
    if (isBackground) return bg;
    vec3 panels = vec3(0.0);
    panels += vec3(1.0) * rectPanel(rd, vec3(-0.5, 0.5, -0.5), vec3(0.0, 1.0, 0.0), vec2(0.3, 0.2), vec2(0.1)) * 2.0;
    panels += vec3(0.9, 0.95, 1.0) * rectPanel(rd, vec3(0.8, 0.2, -0.4), vec3(0.0, 1.0, 0.0), vec2(0.1, 0.6), vec2(0.1)) * 1.5;
    return bg + panels;
}
```

### 5. Multi-wavelength tracing and TIR loop
```glsl
// --- 4. Multi-wavelength dispersion & internal bounces ---
vec3 traceWavelength(vec3 pEntry, vec3 nEntry, vec3 rdIn, float ior) {
    vec3 rd = refract(rdIn, nEntry, 1.0 / ior);
    if (length(rd) < 0.001) return sampleStudioEnv(reflect(rdIn, nEntry), false);

    vec3 p = pEntry - nEntry * 0.0025;
    float totalDist = 0.0;
    vec3 envColor = vec3(0.0);

    for (int bounce = 0; bounce < 3; bounce++) {
        float tExit;
        intersectCard(p, rd, -1.0, tExit);
        if (tExit < 0.0) { envColor = sampleStudioEnv(rd, false); break; }

        totalDist += tExit;
        p += rd * tExit;

        vec3 nExit = -calcNormal(p);
        vec3 rdOut = refract(rd, nExit, ior);

        if (length(rdOut) > 0.001) {
#if LUMINOUS_INTERIOR
            float cosI = clamp(dot(-rd, -nExit), 0.0, 1.0);   // always 0 -> fInternal = 1
#else
            float cosI = clamp(dot(-rd, nExit), 0.0, 1.0);
#endif
            float fInternal = F0_GLASS + (1.0 - F0_GLASS) * pow(1.0 - cosI, 5.0);
            vec3 transmitted = sampleStudioEnv(normalize(rdOut), true);
            vec3 internalRefl = sampleStudioEnv(reflect(rd, nExit), false);
            envColor = mix(transmitted, internalRefl, fInternal);
            break;
        } else {
            rd = reflect(rd, nExit);
            p += nExit * 0.0025;
            if (bounce == 2) envColor = sampleStudioEnv(rd, true);
        }
    }
    return envColor * exp(-BEER_ABSORB * totalDist);
}
```

### 6. Shading
```glsl
// --- 5. Shading ---
vec3 shadeGlass(vec3 rd, vec3 pEntry, vec3 bgCol) {
    vec3 N = calcNormal(pEntry);
    if (dot(N, rd) > 0.0) N = -N;                 // closest-approach points can sit just outside
    vec3 V = -rd;
    float NdotV = clamp(dot(N, V), 0.0, 1.0);
    float fresnel = F0_GLASS + (1.0 - F0_GLASS) * pow(1.0 - NdotV, 5.0);

    vec3 reflCol = sampleStudioEnv(reflect(rd, N), false);
    vec3 refrCol = vec3(0.0), sumWeights = vec3(0.0);
    float iorBase = 1.15;
    float dispersion = 0.015 * (1.0 + 0.35 * gEng);
    for (int i = 0; i < WL_BODY_STEPS; i++) {
        float u = float(i) / float(WL_BODY_STEPS - 1);
        vec3 w = spectrumWeight(u);
        float ior = iorBase + (1.0 - u) * dispersion;
        refrCol += traceWavelength(pEntry, N, rd, ior) * w;
        sumWeights += w;
    }
    refrCol /= sumWeights;

    float epsEdge = 0.002;
    vec3 nShiftX = calcNormal(pEntry + vec3(epsEdge, 0.0, 0.0));
    vec3 nShiftY = calcNormal(pEntry + vec3(0.0, epsEdge, 0.0));
    float curvature = clamp((length(N - nShiftX) + length(N - nShiftY)) * 12.0, 0.0, 1.0);

    // face stays at GLASS_OPACITY; the thick bevel reads as solid glass
    vec3 body = mix(refrCol, reflCol, fresnel);
    vec3 col = mix(bgCol, body, clamp(GLASS_OPACITY + 0.65 * curvature, 0.0, 1.0));

    vec3 keyLightDir = normalize(vec3(-0.5, 0.5, -0.5));
    vec3 H = normalize(keyLightDir + V);
    float lift = 1.0 + 0.35 * gEng;
    float specBand = pow(max(dot(N, H), 0.0), 42.0) * (0.18 + 0.85 * curvature);
    col += vec3(0.95, 0.97, 1.00) * specBand * 0.8 * lift;

    float crispRim = pow(1.0 - NdotV, 8.0) * (0.45 + 0.55 * curvature);
    col += vec3(0.92, 0.96, 1.00) * crispRim * 0.65 * lift;
    return col;
}
```

### 7. Main assembly
```glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    gEng = clamp(iMouse.z, 0.0, 1.0);

    // Resolution-relative framing: P = pixels per world unit, pw = world size of one pixel
    float P = min(iResolution.x * 0.84 / 1.8, iResolution.y * 0.24);
    float K = iResolution.y / (3.0 * P);
    float pw = 1.0 / P;

    vec2 px = fragCoord - 0.5 * iResolution.xy;
    vec3 ro = vec3(0.0, 0.0, -3.0);
    vec3 rd = normalize(vec3(px / iResolution.y * K, 1.0));

    float tHit, minD, tMin;
    marchEntry(ro, rd, tHit, minD, tMin);

    vec3 world = sampleBackgroundFluid(rd);
    float sh = max(sdCard(vec3(ro.xy + rd.xy * 3.0 - vec2(0.0, -0.09), 0.0)), 0.0);
    vec3 col = world * (1.0 - 0.08 * exp(-sh * 7.0));      // light drop shadow

    if (tHit >= 0.0) {
        col = shadeGlass(rd, ro + rd * tHit, world);
    } else {
        float cov = clamp(0.5 - minD / pw, 0.0, 1.0);       // sub-pixel silhouette coverage
        if (cov > 0.0) col = mix(col, shadeGlass(rd, ro + rd * tMin, world), cov);
    }

    fragColor = vec4(softShoulder(col, 0.8, 1.5), 1.0);
}
```

## Tuning knobs

| Knob | Where | Effect |
| --- | --- | --- |
| `GLASS_OPACITY` | define | Face opacity over the backdrop |
| `0.65 * curvature` | `shadeGlass` | How solid the bevel looks (0.0 = flat opacity everywhere) |
| `LUMINOUS_INTERIOR` | define | 1 dense bright interior, 0 physically correct |
| `z`, `bevelR` | `sdCard` | Thickness and edge roundness |
| `WL_BODY_STEPS` | define | 7 smooth fringing, 3 cheaper |
| `iTime * 0.4` | fluid | Background drift speed |
| `0.08 * exp(-sh * 7.0)` | `mainImage` | Shadow strength and falloff |

## Output

- Always deliver **GLSL code**: one complete, Shadertoy-compatible `mainImage` shader saved as a `.glsl` file in the working directory, named after the request (e.g. `glass-card.glsl`). It uses only `iResolution`, `iTime` and `iMouse`. Never overwrite an existing file: add `-2`, `-3`….
- This holds whatever the user gives: words, a reference image or an existing shader.
- An `.html` live preview next to it is optional, never a replacement for the `.glsl`.
- Changes the user asks for (colors, outline shape, extra details) go into the shader itself, keeping the principles above.

## Known gaps

- Inner-shadow trapping is not implemented; curvature only strengthens the specular rim and edge opacity.
- Edge anti-aliasing is distance-based coverage outside the silhouette, not true multisampling.
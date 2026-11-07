// =====================================================================
{{HEADER}}
// =====================================================================

#define PI 3.14159265359

// ---------------------------------------------------------------------
// Background: a solid color (sRGB), or your image in iChannel0.
//   BG_IMAGE 0 : solid bgColor
//   BG_IMAGE 1 : the image in iChannel0 fills the frame ("cover"), and the
//                glass letters refract it
// ---------------------------------------------------------------------
#define BG_IMAGE {{BG_IMAGE}}
const vec3  bgColor     = {{BG_COLOR}};
const float photoInGlass = {{PHOTO_IN_GLASS}};   // image mode: 0 = liquid inside the letters, 1 = clear glass showing the image

// ---------------------------------------------------------------------
// Glass optics (same names and values as glsl-liquid-glass)
// ---------------------------------------------------------------------
const float F0              = 0.12;
const float fresnelPow      = 4.5;
const vec3  ior             = vec3(1.48, 1.52, 1.56);
const vec3  absorptionCoeff = vec3(0.75, 0.35, 0.18);
const float absorptionScale = 2.2;
const vec3  L1              = vec3(0.6, 0.75, 0.85);    // key light
const vec3  L2              = vec3(-0.75, -0.45, 0.65); // fill light
const float spec1Exp = 180.0, spec1Int = 3.8;
const float rim1Exp  = 24.0,  rim1Int  = 0.45;
const float spec2Exp = 90.0,  spec2Int = 1.4;
const float iridMix  = 0.65;
const float shadowStrength = {{SHADOW}};

// Scene
const float PUFF   = {{PUFF}};    // glass puffiness: rounding radius of the letters (glyph units)
const float markBevel = min(0.07, PUFF * 0.5);   // rounding of the shapes replacing marks
const float camZ   = 6.0;
const float focal  = 2.0;
const float TEXT_W = {{TEXT_W}};
const float TEXT_H = {{TEXT_H}};

float gT, gK, gBgZ;

// ---------------------------------------------------------------------
// A. Thin-film interference spectrum   B. Studio environment
// ---------------------------------------------------------------------
vec3 thinFilmPalette(float phase)
{
    const vec3 a = vec3(0.5), b = vec3(0.5), c = vec3(1.0);
    const vec3 d = vec3(0.00, 0.33, 0.67);
    return a + b * cos(2.0 * PI * (c * phase + d));
}

vec3 sampleEnv(vec3 Rd, float shift)
{
    float pitch = asin(clamp(Rd.y, -1.0, 1.0));
    float yaw   = atan(Rd.z, Rd.x);
    float band1 = smoothstep(0.55, 0.95, sin(yaw * 2.0 + pitch * 3.0 + shift));
    float band2 = smoothstep(0.75, 0.99, cos(yaw * 3.0 - pitch * 2.0 + shift * 1.5));
    vec3 col = mix(vec3(0.02, 0.04, 0.09), vec3(0.08, 0.14, 0.24),
                   clamp(pitch / PI + 0.5, 0.0, 1.0));
    col += band1 * thinFilmPalette(yaw * 0.25 + pitch * 0.5 + shift);
    col += band2 * vec3(0.97, 0.98, 1.0) * 1.6;
    return col;
}

vec3 acesFilm(vec3 col)
{
    return clamp((col * (2.51 * col + 0.03)) / (col * (2.43 * col + 0.59) + 0.14), 0.0, 1.0);
}

// ---------------------------------------------------------------------
// Liquid glass surface (glsl-liquid-glass steps 1-5), seen only THROUGH the glass
// ---------------------------------------------------------------------
float heightField(vec2 uv, float t)
{
    vec2 p = uv * 1.8;
    vec2 q = p + 0.35 * vec2(sin(p.y * 1.7 + t * 0.60), cos(p.x * 1.5 - t * 0.50));
    float h = 0.0;
    h += 0.50 * sin(q.x * 2.1 + t * 0.70) * cos(q.y * 1.8 - t * 0.40);
    h += 0.30 * sin(length(q - vec2(0.4 * sin(t * 0.30), 0.3 * cos(t * 0.275))) * 3.2 - t * 0.90);
    h += 0.20 * cos(q.x * 1.3 - q.y * 2.6 + t * 0.50);
    return h;
}

vec3 liquidBackground(vec2 uv, float t)
{
    const float eps = 0.006;
    const float bumpStrength = 0.55;
    float h  = heightField(uv, t);
    float hx = heightField(uv + vec2(eps, 0.0), t);
    float hy = heightField(uv + vec2(0.0, eps), t);
    vec3 N = normalize(vec3(-vec2(hx - h, hy - h) / eps * bumpStrength, 1.0));

    vec3  V     = normalize(vec3(0.0, 0.0, 2.2) - vec3(uv, h * 0.18));
    float NdotV = max(dot(N, V), 0.001);
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - NdotV, fresnelPow);

    vec3  Rf = reflect(-V, N);
    float baseShift = h * 1.2;
    vec3 refrCol;
    refrCol.r = sampleEnv(refract(-V, N, 1.0 / ior.r), baseShift + 0.22).r;
    refrCol.g = sampleEnv(refract(-V, N, 1.0 / ior.g), baseShift).g;
    refrCol.b = sampleEnv(refract(-V, N, 1.0 / ior.b), baseShift - 0.22).b;

    float thickness = clamp(0.65 - h * 0.45, 0.1, 1.3);
    refrCol *= exp(-absorptionCoeff * thickness * absorptionScale);
    refrCol *= mix(0.55, 1.0, smoothstep(-0.9, 0.35, h));

    vec3 irid    = thinFilmPalette(NdotV * 2.4 + h * 1.6 - t * 0.15);
    vec3 reflCol = sampleEnv(Rf, baseShift);
    reflCol = mix(reflCol, reflCol * irid * 1.5, iridMix);

    vec3 H1 = normalize(normalize(L1) + V);
    vec3 H2 = normalize(normalize(L2) + V);
    float NdotH1 = max(dot(N, H1), 0.0);
    float NdotH2 = max(dot(N, H2), 0.0);

    vec3 col = mix(refrCol, reflCol, fresnel);
    col += pow(NdotH1, rim1Exp) * rim1Int * irid;
    col += pow(NdotH1, spec1Exp) * spec1Int;
    col += pow(NdotH2, spec2Exp) * spec2Int * irid;
    return col;
}

// ---------------------------------------------------------------------
// 2D helpers
// ---------------------------------------------------------------------
float sdBox(vec2 p, vec2 b)
{
    vec2 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

// ---------------------------------------------------------------------
// Shapes replacing marks (glsl-sdf-shapes library)
// ---------------------------------------------------------------------
{{SHAPES}}

// ---------------------------------------------------------------------
// Text: font outlines generated by font_to_glsl.py
// ---------------------------------------------------------------------
{{TEXT_BLOCK}}

// ---------------------------------------------------------------------
// 3D scene
// ---------------------------------------------------------------------
float mapGlyphs(vec3 pos)
{
    vec2 d2 = sdfText(pos.xy);
    // Letters: puffy glass. Thick strokes become round, thin strokes become thin lenses.
    float dLetters = length(vec2(max(d2.x + PUFF, 0.0), pos.z)) - PUFF;
    // Shapes: rounded slab, same front as the letters
    vec2 w = vec2(d2.y + markBevel, abs(pos.z) - (PUFF - markBevel));
    float dMark = min(max(w.x, w.y), 0.0) + length(max(w, 0.0)) - markBevel;
    return min(dLetters, dMark);
}

// The text stands still: only the liquid inside it moves.
float map(vec3 pos)
{
    return mapGlyphs(pos / gK) * gK;
}

vec3 calcNormal(vec3 p)
{
    const vec2 e = vec2(1.0, -1.0) * 0.5773 * 0.001;
    return normalize(e.xyy * map(p + e.xyy) + e.yyx * map(p + e.yyx) +
                     e.yxy * map(p + e.yxy) + e.xxx * map(p + e.xxx));
}

vec2 boxHit(vec3 ro, vec3 rd, vec3 b)
{
    vec3 m  = 1.0 / rd;
    vec3 n  = m * ro;
    vec3 kk = abs(m) * b;
    vec3 t1 = -n - kk, t2 = -n + kk;
    return vec2(max(max(t1.x, t1.y), t1.z), min(min(t2.x, t2.y), t2.z));
}

// Contact shadow of the letters on the background plane (1 = lit)
float contactShadow(vec3 P)
{
    vec3 L1n = normalize(L1);
    vec2 T = P.xy + L1n.xy * (-gBgZ) / L1n.z;
    vec2  d2 = sdfText(T / gK);
    float dT = min(d2.x, d2.y) * gK;
    return mix(1.0 - shadowStrength, 1.0, smoothstep(-0.05, 0.6 * (-gBgZ), dT));
}

// Background image, sRGB, "cover" fit. s: screen coordinates (y in [-1, 1]).
vec3 imageAt(vec2 s)
{
#if BG_IMAGE
    float aspect = iResolution.x / iResolution.y;
    vec2  res    = max(iChannelResolution[0].xy, vec2(1.0));
    float imgA   = res.x / res.y;
    float Hs     = max(2.0, 2.0 * aspect / imgA);        // image height on screen, in the same units
    vec2  uv     = 0.5 + s / vec2(Hs * imgA, Hs);
    return texture(iChannel0, clamp(uv, 0.0, 1.0)).rgb;
#else
    return bgColor;
#endif
}

void setupScene()
{
    float aspect = iResolution.x / iResolution.y;
    gK   = 0.72 * min(2.0 * 3.0 * aspect / TEXT_W, 2.0 * 3.0 / TEXT_H);
    gBgZ = -PUFF * gK - 0.25;
}

// ---------------------------------------------------------------------
// Pass 1, GEOMETRY: everything that depends on the letters' shape. It does not
// change over time, so the live preview computes it once and stores it in 4 textures.
//   g0 = (N, thickness)   hit;   (0, 0, 0, -1) when the ray misses the letters
//   g1..g3 = where the red, green, blue rays end after crossing the glass:
//            (P.xy, shadow at P, 1) on the background plane, or (direction, 0) toward the studio
//   miss: g1.x = contact shadow of the background seen directly
// ---------------------------------------------------------------------
vec4 exitRay(vec3 E, vec3 dir)
{
    if (dir.z < -0.05)
    {
        vec3 P = E + dir * (gBgZ - E.z) / dir.z;
        float sh = 1.0;
#if BG_IMAGE
        sh = contactShadow(P);
#endif
        return vec4(P.xy, sh, 1.0);
    }
    return vec4(dir, 0.0);
}

void geometryPass(vec2 fragCoord, out vec4 g0, out vec4 g1, out vec4 g2, out vec4 g3)
{
    setupScene();
    vec2 uv = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
    vec3 ro = vec3(0.0, 0.0, camZ);
    vec3 rd = normalize(vec3(uv, -focal));

    vec3 Pbg = ro + rd * (gBgZ - ro.z) / rd.z;
    g0 = vec4(0.0, 0.0, 0.0, -1.0);
    g1 = vec4(contactShadow(Pbg), 0.0, 0.0, 0.0);
    g2 = g3 = vec4(0.0);

    vec3 bHalf = vec3(TEXT_W * 0.5 + 0.1, TEXT_H * 0.5 + 0.1, PUFF + 0.05) * gK;
    vec2 tb = boxHit(ro, rd, bHalf);
    if (!(tb.x < tb.y && tb.y > 0.0)) return;

    float tt = max(tb.x, 0.0);
    bool hit = false;
    for (int i = 0; i < 96; i++)
    {
        float d = map(ro + rd * tt);
        if (d < 0.001) { hit = true; break; }
        tt += d;
        if (tt > tb.y) break;
    }
    if (!hit) return;

    vec3 p = ro + rd * tt;
    vec3 N = calcNormal(p);

    // Thickness: march inside the letter along the green ray
    vec3  rdIn = refract(rd, N, 1.0 / ior.g);
    vec3  q = p - N * 0.01;
    float travel = 0.0;
    for (int i = 0; i < 48; i++)
    {
        float d = -map(q);
        if (d < 0.001) break;
        float stepLen = max(d, 0.002);
        q += rdIn * stepLen;
        travel += stepLen;
    }
    vec3 Ne = calcNormal(q);

    // Dispersion through the letter, per channel
    vec4 g[3];
    for (int c = 0; c < 3; c++)
    {
        float ic   = ior[c];
        vec3  dIn  = refract(rd, N, 1.0 / ic);
        vec3  dOut = refract(dIn, -Ne, ic);
        if (dot(dOut, dOut) < 1e-6) dOut = reflect(dIn, -Ne);
        g[c] = exitRay(p + dIn * travel, dOut);
    }
    g0 = vec4(N, travel / gK);
    g1 = g[0]; g2 = g[1]; g3 = g[2];
}

// ---------------------------------------------------------------------
// Pass 2, SHADING: runs every frame; only the liquid and the light move.
// ---------------------------------------------------------------------
vec3 exitColor(vec4 g, float shift)
{
    if (g.w > 0.5)
    {
        float bgHalfH = (camZ - gBgZ) / focal;
        vec3 liquid = liquidBackground(0.5 * g.xy / bgHalfH, gT);   // the liquid lives inside the letters
#if BG_IMAGE
        vec3 photo = pow(imageAt(g.xy / bgHalfH), vec3(2.2)) * g.z;   // the image, refracted
        return mix(liquid, photo, photoInGlass);
#else
        return liquid;
#endif
    }
    return sampleEnv(g.xyz, shift);
}

vec3 shadingPass(vec2 fragCoord, vec4 g0, vec4 g1, vec4 g2, vec4 g3)
{
    setupScene();
    gT = iTime;
    vec2 uv = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
    vec3 rd = normalize(vec3(uv, -focal));

    // Background seen directly: the exact color or image, with the contact shadow
    if (g0.w < 0.0) return imageAt(uv) * g1.x;

    vec3  N = g0.xyz;
    float thickness = g0.w;
    vec3  V = -rd;
    float NdotV = max(dot(N, V), 0.001);
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - NdotV, fresnelPow);

    vec3 refrCol;
    refrCol.r = exitColor(g1, thickness * 1.2 + 0.22).r;
    refrCol.g = exitColor(g2, thickness * 1.2).g;
    refrCol.b = exitColor(g3, thickness * 1.2 - 0.22).b;
    refrCol *= exp(-absorptionCoeff * thickness * absorptionScale);
    refrCol *= mix(1.0, 0.85, smoothstep(0.4, 1.0, thickness));

    vec3 irid    = thinFilmPalette(NdotV * 2.4 + thickness * 1.6 - gT * 0.15);
    vec3 reflCol = sampleEnv(reflect(rd, N), thickness * 1.2);
    reflCol = mix(reflCol, reflCol * irid * 1.5, iridMix);

    vec3  H1 = normalize(normalize(L1) + V);
    vec3  H2 = normalize(normalize(L2) + V);
    float NdotH1 = max(dot(N, H1), 0.0);
    float NdotH2 = max(dot(N, H2), 0.0);

    vec3 col = mix(refrCol, reflCol, fresnel);
    col += pow(NdotH1, rim1Exp)  * rim1Int * irid;
    col += pow(NdotH1, spec1Exp) * spec1Int;
    col += pow(NdotH2, spec2Exp) * spec2Int * irid;

    // Post-processing on the glass only (the background keeps its exact color)
    col *= 1.15;
    col  = acesFilm(col);
    return pow(col, vec3(1.0 / 2.2));
}

// ---------------------------------------------------------------------
// Main (Shadertoy: both passes in one; the .html preview runs them separately)
// ---------------------------------------------------------------------
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec4 g0, g1, g2, g3;
    geometryPass(fragCoord, g0, g1, g2, g3);
    fragColor = vec4(shadingPass(fragCoord, g0, g1, g2, g3), 1.0);
}

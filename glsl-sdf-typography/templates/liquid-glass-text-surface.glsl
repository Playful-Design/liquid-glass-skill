// =====================================================================
{{HEADER}}
// =====================================================================
//  Look "surface": ONE continuous liquid glass surface (the glsl-liquid-glass
//  background, same height field, same optics) cut into the shape of the text.
//  The letters are not separate objects: the liquid flows across the whole text,
//  and each letter's outline is a soft rounded rim of that same material.
// =====================================================================

#define PI 3.14159265359

// ---------------------------------------------------------------------
// Background: a solid color (sRGB), or your image in iChannel0.
// ---------------------------------------------------------------------
#define BG_IMAGE {{BG_IMAGE}}
const vec3  bgColor      = {{BG_COLOR}};
const float photoInGlass = {{PHOTO_IN_GLASS}};   // image mode: how much of the picture shows through the glass

// Palette: 0 = original liquid glass (deep, iridescent), 1 = soft pastel glass
#define PASTEL {{PASTEL}}
const vec3 pastelTint = {{TINT}};                 // pastel mode: the glass's main hue (sRGB)

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
const float bumpStrength = 0.55;

// Text relief
const float PUFF   = {{PUFF}};   // width of the rounded rim along each outline (glyph units)
const float RELIEF = 0.9;        // how strongly the rim bends the light (the outline's visibility)
const float shadowStrength = {{SHADOW}};
const float TEXT_W = {{TEXT_W}};
const float TEXT_H = {{TEXT_H}};

float gT;

// ---------------------------------------------------------------------
// A. Thin-film interference spectrum   B. Studio environment
// ---------------------------------------------------------------------
vec3 thinFilmPalette(float phase)
{
#if PASTEL
    const vec3 a = vec3(0.70), b = vec3(0.30), c = vec3(1.0);   // same spectrum, softened
#else
    const vec3 a = vec3(0.5),  b = vec3(0.5),  c = vec3(1.0);
#endif
    const vec3 d = vec3(0.00, 0.33, 0.67);
    return a + b * cos(2.0 * PI * (c * phase + d));
}

vec3 sampleEnv(vec3 Rd, float shift)
{
    float pitch = asin(clamp(Rd.y, -1.0, 1.0));
    float yaw   = atan(Rd.z, Rd.x);
    float band1 = smoothstep(0.55, 0.95, sin(yaw * 2.0 + pitch * 3.0 + shift));
    float band2 = smoothstep(0.75, 0.99, cos(yaw * 3.0 - pitch * 2.0 + shift * 1.5));
#if PASTEL
    // Light studio: a bright room tinted by the glass hue instead of a night-blue one
    vec3 tint = pow(pastelTint, vec3(2.2));
    vec3 col = mix(tint * 0.30, mix(tint, vec3(1.0), 0.35), clamp(pitch / PI + 0.5, 0.0, 1.0));
    col += band1 * thinFilmPalette(yaw * 0.25 + pitch * 0.5 + shift) * 0.75;
    col += band2 * vec3(1.0) * 0.9;
#else
    vec3 col = mix(vec3(0.02, 0.04, 0.09), vec3(0.08, 0.14, 0.24),
                   clamp(pitch / PI + 0.5, 0.0, 1.0));
    col += band1 * thinFilmPalette(yaw * 0.25 + pitch * 0.5 + shift);
    col += band2 * vec3(0.97, 0.98, 1.0) * 1.6;
#endif
    return col;
}

vec3 acesFilm(vec3 col)
{
    return clamp((col * (2.51 * col + 0.03)) / (col * (2.43 * col + 0.59) + 0.14), 0.0, 1.0);
}

// ---------------------------------------------------------------------
// The liquid surface (glsl-liquid-glass height field, unchanged)
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
// Layout: screen coordinates s (y in [-1, 1]) -> glyph units
// ---------------------------------------------------------------------
float textScale()
{
    float aspect = iResolution.x / iResolution.y;
    return 0.80 * min(2.0 * aspect / TEXT_W, 2.0 / TEXT_H);
}

float textDist(vec2 s)          // signed distance to letters and shapes, in screen units
{
    float k  = textScale();
    vec2  d2 = sdfText(s / k);
    return min(d2.x, d2.y) * k;
}

// Rim profile: 0 outside, rises along a quarter circle over the rim width, 1 inside
float rimProfile(float d, float w)
{
    float t = clamp(-d / w, 0.0, 1.0);
    return sqrt(t * (2.0 - t));
}

// Background image, sRGB, "cover" fit
vec3 imageAt(vec2 s)
{
#if BG_IMAGE
    float aspect = iResolution.x / iResolution.y;
    vec2  res    = max(iChannelResolution[0].xy, vec2(1.0));
    float imgA   = res.x / res.y;
    float Hs     = max(2.0, 2.0 * aspect / imgA);
    vec2  uv     = 0.5 + s / vec2(Hs * imgA, Hs);
    return texture(iChannel0, clamp(uv, 0.0, 1.0)).rgb;
#else
    return bgColor;
#endif
}

// ---------------------------------------------------------------------
// Pass 1, GEOMETRY (static, computed once by the .html preview):
//   g0 = (distance, distance at +x, distance at +y, distance for the shadow)
// ---------------------------------------------------------------------
void geometryPass(vec2 fragCoord, out vec4 g0, out vec4 g1, out vec4 g2, out vec4 g3)
{
    vec2  s   = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
    float e   = 2.0 / iResolution.y;                        // one pixel
    vec2  off = normalize(L1).xy * 0.035;                   // shadow cast away from the key light
    g0 = vec4(textDist(s), textDist(s + vec2(e, 0.0)), textDist(s + vec2(0.0, e)), textDist(s + off));
    g1 = g2 = g3 = vec4(0.0);
}

// ---------------------------------------------------------------------
// Pass 2, SHADING (every frame): the glsl-liquid-glass pipeline on the
// liquid height field + the letters' rims, only inside the letters.
// ---------------------------------------------------------------------
vec3 shadingPass(vec2 fragCoord, vec4 g0, vec4 g1, vec4 g2, vec4 g3)
{
    gT = iTime;
    vec2  s  = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
    float px = 2.0 / iResolution.y;
    float d  = g0.x;

    // Outside: the background, with a soft shadow of the text
    vec3 bg = imageAt(s) * mix(1.0 - shadowStrength, 1.0, smoothstep(-0.01, 0.05, g0.w));
    float inside = smoothstep(px, -px, d);
    if (inside <= 0.0) return bg;

    // 1. Normal of ONE surface: the liquid, plus the rounded rim of the letters
    vec2  uv  = s * 0.5;                                      // the liquid's own frame (glsl-liquid-glass)
    const float eps = 0.006;
    float h   = heightField(uv, gT);
    float hx  = heightField(uv + vec2(eps, 0.0), gT);
    float hy  = heightField(uv + vec2(0.0, eps), gT);
    vec2  slope = -vec2(hx - h, hy - h) / eps * bumpStrength;

    float w   = max(PUFF * textScale(), 2.0 * px);            // rim width on screen
    float r   = rimProfile(d, w);
    float rx  = rimProfile(g0.y, w), ry = rimProfile(g0.z, w);
    slope    -= vec2(rx - r, ry - r) / px * w * RELIEF;       // the rim tilts the surface toward the outline
    vec3  N   = normalize(vec3(slope, 1.0));

    vec3  V     = normalize(vec3(0.0, 0.0, 2.2) - vec3(uv, h * 0.18));
    float NdotV = max(dot(N, V), 0.001);

    // 2. Fresnel
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - NdotV, fresnelPow);

    // 3. Dispersion
    vec3  Rf = reflect(-V, N);
    float baseShift = h * 1.2;
    vec3 refrCol;
    refrCol.r = sampleEnv(refract(-V, N, 1.0 / ior.r), baseShift + 0.22).r;
    refrCol.g = sampleEnv(refract(-V, N, 1.0 / ior.g), baseShift).g;
    refrCol.b = sampleEnv(refract(-V, N, 1.0 / ior.b), baseShift - 0.22).b;
#if BG_IMAGE
    vec3 photo = pow(imageAt(s + N.xy * 0.06), vec3(2.2));   // the picture, bent by the glass
    refrCol = mix(refrCol, photo, photoInGlass);
#endif

    // 4. Beer-Lambert: thinner along the rims, thicker inside
    float thickness = clamp(0.65 - h * 0.45, 0.1, 1.3) * mix(0.45, 1.0, r);
#if PASTEL
    refrCol *= exp(-absorptionCoeff * thickness * absorptionScale * 0.45);
    refrCol *= mix(0.65, 1.0, smoothstep(-0.9, 0.35, h));
#else
    refrCol *= exp(-absorptionCoeff * thickness * absorptionScale);
    refrCol *= mix(0.55, 1.0, smoothstep(-0.9, 0.35, h));
#endif

    // 5. Reflection and iridescence
    vec3 irid    = thinFilmPalette(NdotV * 2.4 + h * 1.6 - gT * 0.15);
    vec3 reflCol = sampleEnv(Rf, baseShift);
    reflCol = mix(reflCol, reflCol * irid * 1.5, iridMix);

    // 6. Dual Blinn-Phong
    vec3  H1 = normalize(normalize(L1) + V);
    vec3  H2 = normalize(normalize(L2) + V);
    float NdotH1 = max(dot(N, H1), 0.0);
    float NdotH2 = max(dot(N, H2), 0.0);

    vec3 col = mix(refrCol, reflCol, fresnel);
#if PASTEL
    col += pow(NdotH1, rim1Exp)  * rim1Int * 0.6 * irid;
    col += pow(NdotH1, spec1Exp) * spec1Int * 0.6;
    col += pow(NdotH2, spec2Exp) * spec2Int * 0.5 * irid;
#else
    col += pow(NdotH1, rim1Exp)  * rim1Int * irid;
    col += pow(NdotH1, spec1Exp) * spec1Int;
    col += pow(NdotH2, spec2Exp) * spec2Int * irid;
#endif

    // 7. Post-processing on the glass (the background keeps its exact color)
    col *= 1.15;
    col  = acesFilm(col);
    col  = pow(col, vec3(1.0 / 2.2));
    return mix(bg, col, inside);
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

// =============================================================================
//  Liquid Glass — iridescent, refractive, viscous glass surface
//  Shadertoy-compatible: paste into a new shader's Image tab.
//  Uniforms used: iResolution, iTime
// =============================================================================

#define PI 3.14159265359

// -----------------------------------------------------------------------------
// Thin-film interference spectrum (Inigo Quilez cosine palette)
// -----------------------------------------------------------------------------
vec3 thinFilmPalette(float phase)
{
    const vec3 a = vec3(0.5);
    const vec3 b = vec3(0.5);
    const vec3 c = vec3(1.0);
    const vec3 d = vec3(0.00, 0.33, 0.67);
    return a + b * cos(2.0 * PI * (c * phase + d));
}

// -----------------------------------------------------------------------------
// Procedural studio HDR environment (no textures)
// -----------------------------------------------------------------------------
vec3 sampleEnv(vec3 R, float shift)
{
    float pitch = asin(clamp(R.y, -1.0, 1.0));
    float yaw   = atan(R.z, R.x);

    // Softbox 1: wide, soft, iridescent-tinted
    float band1 = smoothstep(0.55, 0.95, sin(yaw * 2.0 + pitch * 3.0 + shift));
    // Softbox 2: narrow, sharp, hot white strip
    float band2 = smoothstep(0.75, 0.99, cos(yaw * 3.0 - pitch * 2.5 + shift * 1.5));

    // Dark ambient studio gradient (never fully black)
    float g  = clamp(pitch / PI + 0.5, 0.0, 1.0);
    vec3 col = mix(vec3(0.02, 0.04, 0.09), vec3(0.08, 0.14, 0.24), g);

    col += band1 * thinFilmPalette(yaw / (2.0 * PI) + pitch * 0.5 + shift);
    col += band2 * vec3(1.0, 0.98, 0.95) * 1.6;
    return col;
}

// -----------------------------------------------------------------------------
// Smooth (C-infinity) animated liquid height field — sines + domain warping only,
// so there is no noise grain or derivative discontinuity.
// -----------------------------------------------------------------------------
float heightField(vec2 uv, float t)
{
    vec2 p = uv * 2.0;

    // Two passes of gentle domain warping for a viscous, flowing look
    vec2 q = p;
    q += 0.35 * vec2(sin(p.y * 2.1 + t * 0.70),       cos(p.x * 1.8 - t * 0.60));
    q += 0.20 * vec2(sin(q.y * 3.3 - t * 0.90 + 1.7), cos(q.x * 2.9 + t * 0.80 + 0.4));

    float h = 0.0;
    h += 0.55 * sin(q.x * 2.3 + t * 0.5) * cos(q.y * 1.9 - t * 0.4);
    h += 0.30 * sin(length(q - vec2(0.3 * sin(t * 0.3), 0.2 * cos(t * 0.25))) * 4.5 - t * 1.1);
    h += 0.15 * cos(q.x * 4.1 - q.y * 3.7 + t * 0.9);
    return h; // roughly in [-1, 1]
}

// -----------------------------------------------------------------------------
// ACES filmic tone mapping (Narkowicz fit)
// -----------------------------------------------------------------------------
vec3 acesFilm(vec3 col)
{
    return clamp((col * (2.51 * col + 0.03)) / (col * (2.43 * col + 0.59) + 0.14), 0.0, 1.0);
}

// =============================================================================
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2  uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float t  = iTime;

    // ---- 1. Surface + finite-difference normals -----------------------------
    const float eps          = 0.006;
    const float bumpStrength = 0.55;

    float h  = heightField(uv, t);
    float hx = heightField(uv + vec2(eps, 0.0), t);
    float hy = heightField(uv + vec2(0.0, eps), t);

    vec2 slope = vec2(hx - h, hy - h) / eps;
    vec3 N = normalize(vec3(-slope * bumpStrength, 1.0));

    vec3  surfPos = vec3(uv, h * 0.18);
    vec3  camPos  = vec3(0.0, 0.0, 2.2);
    vec3  V       = normalize(camPos - surfPos);
    float NdotV   = max(dot(N, V), 0.001);

    // ---- 2. Fresnel (Schlick) -----------------------------------------------
    const float F0 = 0.12;
    float fresnel = F0 + (1.0 - F0) * pow(1.0 - NdotV, 4.5);

    // ---- 3. Reflection + spectral dispersion --------------------------------
    vec3 R = reflect(-V, N);

    vec3 Tr = refract(-V, N, 1.0 / 1.48);
    vec3 Tg = refract(-V, N, 1.0 / 1.52);
    vec3 Tb = refract(-V, N, 1.0 / 1.56);

    float baseShift = h * 1.2;
    vec3 refr;
    refr.r = sampleEnv(Tr, baseShift + 0.22).r;
    refr.g = sampleEnv(Tg, baseShift + 0.00).g;
    refr.b = sampleEnv(Tb, baseShift - 0.22).b;

    // ---- 4. Beer-Lambert absorption -----------------------------------------
    float thickness     = clamp(0.65 - h * 0.45, 0.1, 1.3);
    vec3  absorption    = vec3(0.75, 0.35, 0.18);          // red/green die first
    vec3  transmittance = exp(-absorption * thickness * 2.2);
    float valleyShade   = mix(0.55, 1.0, smoothstep(-0.9, 0.4, h));
    refr *= transmittance * valleyShade;

    // ---- 5. Iridescence + dual Blinn-Phong ----------------------------------
    float filmPhase = NdotV * 2.4 + h * 1.6 - t * 0.15;
    vec3  irid      = thinFilmPalette(filmPhase);

    vec3 refl = sampleEnv(R, baseShift);
    refl = mix(refl, refl * irid * 1.5, 0.65);

    // Key light
    vec3  L1    = normalize(vec3(0.6, 0.75, 0.85));
    vec3  H1    = normalize(L1 + V);
    float NdH1  = max(dot(N, H1), 0.0);
    float spec1 = pow(NdH1, 180.0) * 3.8;
    float rim1  = pow(NdH1, 24.0)  * 0.45;

    // Fill light
    vec3  L2    = normalize(vec3(-0.75, -0.45, 0.65));
    vec3  H2    = normalize(L2 + V);
    float spec2 = pow(max(dot(N, H2), 0.0), 90.0) * 1.4;

    vec3 col = mix(refr, refl, fresnel);
    col += rim1  * irid;
    col += spec1 * vec3(1.0, 0.98, 0.96);
    col += spec2 * irid;

    // ---- 6. Post-processing -------------------------------------------------
    float vignette = 1.0 - 0.55 * smoothstep(0.35, 1.25, length(uv)); // >= 0.45
    col *= vignette;

    col *= 1.15;              // exposure
    col  = acesFilm(col);
    col  = pow(col, vec3(1.0 / 2.2));

    fragColor = vec4(col, 1.0);
}

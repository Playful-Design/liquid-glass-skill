// =====================================================================
//  Glass prism (glsl-liquid-glass, mode `natural` + option `prism`)
//  Shadertoy-compatible mainImage.
//  - Cut glass as a convex polyhedron: exact ray/plane intersections,
//    one flat normal per facet (section 1c rule 2), no raymarching.
//  - Spectral dispersion: N_WL wavelengths, Cauchy IOR per wavelength.
//  - Up to MAX_BOUNCES internal reflections (Fresnel split + total
//    internal reflection), which is what makes cut glass sparkle.
//  - Fake rainbow caustic on the floor + glass shadow.
//  SHAPE 0 = triangular prism, 1 = brilliant-cut gem.
// =====================================================================

#define SHAPE        0
#define N_WL         7      // wavelengths (3 = fast, 7 = smooth rainbow)
#define MAX_BOUNCES  4      // internal bounces
#define AA           2      // supersampling per axis (1 on weak GPUs)

#define PI  3.14159265359
#define TAU 6.28318530718

// ---- Glass (Cauchy: n = A + B / lambda^2, lambda in micrometres)
const float glassA          = 1.5900;   // flint glass
const float glassB          = 0.0110;
const float dispersionBoost = 3.5;      // 1 = physical, 2..4 = stylised fire
const vec3  absorb          = vec3(0.06, 0.05, 0.04);   // near neutral

// ---- Scene
const float floorY  = -0.60;
const float prismR  = 0.42;   // inradius of the triangle
const float prismL  = 0.95;   // half length
const float gemS    = 0.75;   // gem radius
const float sunInt  = 22.0;
const float causticSpread = 9.0;   // fake: fans the floor rainbow out (1 = same as the rays)
const vec3  sunDirC = vec3(-0.80, 0.30, -0.55);

// ---------------------------------------------------------------------
// Spectrum
// ---------------------------------------------------------------------
float gauss(float x, float m, float s) { float u = (x - m) / s; return exp(-0.5 * u * u); }
vec3  wlColor(float l) {   // linear RGB response of one wavelength (nm)
    return vec3(gauss(l, 600.0, 42.0) + 0.28 * gauss(l, 420.0, 20.0),
                gauss(l, 545.0, 42.0),
                gauss(l, 455.0, 30.0));
}
float wlAt(int i) { return mix(410.0, 690.0, (float(i) + 0.5) / float(N_WL)); }
float iorAt(float l) {
    float u = l * 1e-3;
    float nMid = glassA + glassB / (0.55 * 0.55);
    return nMid + dispersionBoost * (glassB / (u * u) - glassB / (0.55 * 0.55));
}

// ---------------------------------------------------------------------
// Convex polyhedron: planes vec4(outward normal, d), inside: dot(n,p) < d
// ---------------------------------------------------------------------
#if SHAPE == 0
#define NF 5
vec4 facePlane(int i) {
    if (i < 3) {                                  // bottom face first (-y)
        float a = -0.5 * PI + float(i) * TAU / 3.0;
        return vec4(cos(a), sin(a), 0.0, prismR);
    }
    return vec4(0.0, 0.0, i == 3 ? 1.0 : -1.0, prismL);
}
const float restY = prismR;                       // centre height above floor
#else
#define NF 33
vec4 facePlane(int i) {
    if (i == 0) return vec4(0.0, 1.0, 0.0, 0.33 * gemS);                  // table
    if (i < 9) {                                                          // crown
        float a = float(i - 1) * TAU / 8.0, c = radians(34.5);
        return vec4(sin(c) * cos(a), cos(c), sin(c) * sin(a), (sin(c) + 0.03 * cos(c)) * gemS);
    }
    if (i < 25) {                                                         // girdle
        float a = (float(i - 9) + 0.5) * TAU / 16.0;
        return vec4(cos(a), 0.0, sin(a), gemS);
    }
    float a = (float(i - 25) + 0.5) * TAU / 8.0, c = radians(40.75);     // pavilion
    return vec4(sin(c) * cos(a), -cos(c), sin(c) * sin(a), (sin(c) + 0.03 * cos(c)) * gemS);
}
const float restY = 0.92 * gemS + 0.05;
#endif

// Object pose (rotates slowly so the rainbows sweep)
mat3 objRot;          // local -> world
vec3 objPos;
vec3 sunDir;

bool hitConvex(vec3 ro, vec3 rd, out float tN, out int iN) {
    tN = -1e9; float tF = 1e9; iN = 0;
    for (int i = 0; i < NF; i++) {
        vec4  P  = facePlane(i);
        float dn = dot(P.xyz, rd);
        float ds = P.w - dot(P.xyz, ro);
        if (abs(dn) < 1e-7) { if (ds < 0.0) return false; continue; }
        float t = ds / dn;
        if (dn < 0.0) { if (t > tN) { tN = t; iN = i; } }
        else          { tF = min(tF, t); }
    }
    return tN < tF && tF > 0.0 && tN > 0.0;
}

// From inside: exact exit point and face
float exitConvex(vec3 p, vec3 d, out int j) {
    float tE = 1e9; j = 0;
    for (int i = 0; i < NF; i++) {
        vec4 P = facePlane(i);
        float dn = dot(P.xyz, d);
        if (dn > 1e-7) { float t = (P.w - dot(P.xyz, p)) / dn; if (t < tE) { tE = t; j = i; } }
    }
    return max(tE, 0.0);
}

// Explicit refraction: returns vec3(0) on total internal reflection.
// (Built-in refract() is unreliable at the critical angle on some GPU
//  drivers with fast math: it produced coloured per-pixel grain.)
vec3 refr(vec3 I, vec3 N, float eta) {
    float c = -dot(N, I);
    float k = 1.0 - eta * eta * (1.0 - c * c);
    if (k <= 0.0) return vec3(0.0);
    return normalize(eta * I + (eta * c - sqrt(k)) * N);
}

float fresnelDielectric(float cosI, float n1, float n2) {
    float r0 = (n1 - n2) / (n1 + n2); r0 *= r0;
    float c = cosI;
    if (n1 > n2) {
        float s2 = (n1 / n2) * (n1 / n2) * (1.0 - c * c);
        if (s2 > 1.0) return 1.0;
        c = sqrt(1.0 - s2);
    }
    return r0 + (1.0 - r0) * pow(clamp(1.0 - c, 0.0, 1.0), 5.0);   // clamp: pow(<0) is undefined
}

// ---------------------------------------------------------------------
// Environment: neutral studio, 2 softboxes + small sun (1c rule 5)
// ---------------------------------------------------------------------
float panel(vec3 d, vec3 c, vec2 size) {
    float k = dot(d, c);
    if (k <= 0.0) return 0.0;
    vec3 u = normalize(cross(c, vec3(0.0, 1.0, 0.0)));
    vec3 v = cross(u, c);
    vec2 q = abs(vec2(dot(d, u), dot(d, v)) / k) - size;
    return 1.0 - smoothstep(-0.02, 0.02, max(q.x, q.y));
}

float sunSoft = 1.0;   // 1 for camera/reflection rays, >1 inside the glass

vec3 env(vec3 d) {
    vec3 col = mix(vec3(0.075, 0.078, 0.085), vec3(0.012, 0.014, 0.018), smoothstep(-0.05, 0.6, d.y));
    col += 2.4 * panel(d, normalize(vec3(0.75, 0.55, 0.35)), vec2(0.40, 0.20));
    col += 1.3 * panel(d, normalize(vec3(-0.85, 0.30, 0.55)), vec2(0.12, 0.45));
    float s = dot(d, sunDir);
    float r = 0.026 * sunSoft;                       // angular radius
    col += sunInt / (sunSoft * sunSoft) * smoothstep(cos(r * 1.25), cos(r * 0.75), s)
         + 0.25 * pow(max(s, 0.0), 300.0);
    return col;
}

// ---------------------------------------------------------------------
// Fake caustic: one representative sun ray through the glass per
// wavelength, footprint of the beam drawn on the floor.
// ---------------------------------------------------------------------
vec3  cauQ[N_WL];
float cauE[N_WL];

void prepareCaustics() {
    vec3 sunL = transpose(objRot) * sunDir;
    vec3 aim = (SHAPE == 0 ? vec3(0.0, 0.9 * prismR, 0.0) : vec3(0.0, 0.1 * gemS, 0.0));
    vec3 ro = aim + sunL * 6.0;
    vec3 rd = -sunL;
    float tN; int iN;
    bool ok = hitConvex(ro, rd, tN, iN);
    for (int w = 0; w < N_WL; w++) {
        cauE[w] = 0.0; cauQ[w] = vec3(0.0);
        if (!ok) continue;
        float n = iorAt(wlAt(w));
        vec3 nE = facePlane(iN).xyz;
        vec3 p = ro + rd * tN;
        vec3 d = refr(rd, nE, 1.0 / n);
        float e = 1.0 - fresnelDielectric(-dot(rd, nE), 1.0, n);
        for (int b = 0; b < MAX_BOUNCES; b++) {
            int j; float t = exitConvex(p, d, j);
            p += d * t;
            vec3 nX = facePlane(j).xyz;
            vec3 o = refr(d, -nX, n);
            if (dot(o, o) > 0.0) {
                vec3 pw = objRot * p + objPos, ow = objRot * o;
                if (ow.y < -0.02) {
                    cauQ[w] = pw + ow * ((floorY - pw.y) / ow.y);
                    cauE[w] = e * (1.0 - fresnelDielectric(dot(d, nX), n, 1.0));
                }
                break;
            }
            d = reflect(d, -nX);
            p -= nX * 1e-4;
        }
    }
    // fan the colours out around the middle wavelength
    vec3 mid = cauQ[N_WL / 2];
    for (int w = 0; w < N_WL; w++) if (cauE[w] > 0.0) cauQ[w] = mid + (cauQ[w] - mid) * causticSpread;
}

vec3 floorShade(vec3 q, vec3 rd, float dist) {
    vec3 alb = vec3(0.42, 0.41, 0.40);
    float sh = 1.0, tN; int iN;
    // start the shadow ray slightly above the floor: the prism's bottom face lies ON
    // the floor plane, and a ray starting exactly on a face flips in/out per pixel
    vec3 roL = transpose(objRot) * (q + vec3(0.0, 2e-3, 0.0) - objPos);
    if (dist < 8.0 && hitConvex(roL, transpose(objRot) * sunDir, tN, iN)) sh = 0.55;
    vec3 col = alb * (0.05 + 0.9 * max(sunDir.y, 0.0) * sh);

    // rainbow caustic
    vec3 wsum = vec3(0.0);
    for (int w = 0; w < N_WL; w++) wsum += wlColor(wlAt(w));
    vec3 ax = objRot * vec3(0.0, 0.0, 1.0);
    vec2 a2 = length(ax.xz) > 1e-3 ? normalize(ax.xz) : vec2(1.0, 0.0);
    vec2 p2 = vec2(-a2.y, a2.x);
    vec2 beam = (SHAPE == 0 ? vec2(prismL, 0.16 * prismR) : vec2(0.35 * gemS));   // half sizes
    vec3 cau = vec3(0.0);
    for (int w = 0; w < N_WL; w++) {
        if (cauE[w] <= 0.0) continue;
        vec2 l = (q - cauQ[w]).xz;
        float r = length(vec2(dot(l, a2) / beam.x, dot(l, p2) / beam.y * 0.6));
        cau += wlColor(wlAt(w)) / wsum * cauE[w] * (1.0 - smoothstep(1.0 - 0.45 * sunSoft / 3.0 - 0.3, 1.0, r));   // softer when seen through the glass (it gets minified there and aliases)
    }
    col += alb * cau * 3.0;

    return mix(col, env(rd), smoothstep(7.0, 16.0, dist));
}

vec3 scene(vec3 p, vec3 d) {
    if (d.y < -1e-4) {
        // max(.., 0): light leaving through the bottom face starts ON the floor,
        // where the sign of t is pure rounding noise (it caused coloured grain)
        float t = max((floorY - p.y) / d.y, 0.0);
        if (t < 16.0) return floorShade(p + d * t, d, t);   // far floor = env (avoids precision noise)
    }
    return env(d);
}

// ---------------------------------------------------------------------
// Shading a camera ray
// ---------------------------------------------------------------------
vec3 render(vec3 ro, vec3 rd, float pxAngle) {
    vec3 roL = transpose(objRot) * (ro - objPos);
    vec3 rdL = transpose(objRot) * rd;
    float tN; int iN;
    if (!hitConvex(roL, rdL, tN, iN)) return scene(ro, rd);

    vec3 pL = roL + rdL * tN;
    vec3 nL = facePlane(iN).xyz;
    vec3 pW = objRot * pL + objPos, nW = objRot * nL;
    float cosI = max(-dot(rdL, nL), 1e-4);
    float nMid = iorAt(550.0);

    // Reflection off the entry facet (wavelength independent), clamped (1c rule 4)
    float F = fresnelDielectric(cosI, 1.0, nMid);
    vec3 refl = scene(pW + nW * 1e-3, reflect(rd, nW));
    refl = min(refl, vec3(2.5)); refl = refl / (1.0 + 0.25 * refl);
    vec3 col = F * refl * 1.6;

    // Spectral transmission with internal bounces
    vec3 wsum = vec3(0.0);
    for (int w = 0; w < N_WL; w++) wsum += wlColor(wlAt(w));
    vec3 trans = vec3(0.0);
    sunSoft = 3.0;
    for (int w = 0; w < N_WL; w++) {
        float n = iorAt(wlAt(w));
        vec3 d = refr(rdL, nL, 1.0 / n);
        vec3 p = pL;
        vec3 e = vec3(1.0 - fresnelDielectric(cosI, 1.0, n));
        vec3 acc = vec3(0.0);
        for (int b = 0; b < MAX_BOUNCES; b++) {
            int j; float t = exitConvex(p, d, j);
            p += d * t;
            e *= exp(-absorb * t / (SHAPE == 0 ? prismR : gemS));
            vec3 nX = facePlane(j).xyz;
            vec3 o = refr(d, -nX, n);
            if (dot(o, o) > 0.0) {
                float Fx = fresnelDielectric(dot(d, nX), n, 1.0);
                float graze = smoothstep(0.0, 0.25, dot(o, nX));   // fade near-critical exits
                acc += e * (1.0 - Fx) * graze * scene(objRot * p + objPos, objRot * o);
                e *= Fx;
            }
            d = reflect(d, -nX);
            p -= nX * 1e-4;
        }
        acc += e * env(objRot * d) * 0.5;   // leftover energy
        trans += acc * wlColor(wlAt(w)) / wsum;
    }
    sunSoft = 1.0;
    col += trans;

    // Polished facet edges: thin crisp line where two facets meet (1c)
    float g1 = 1e9, g2 = 1e9;
    for (int i = 0; i < NF; i++) {
        vec4 P = facePlane(i);
        if (i == iN) continue;
        // in-face distance to the edge shared with facet i (gap / sin of the dihedral)
        float g = (P.w - dot(P.xyz, pL)) / max(length(cross(P.xyz, nL)), 1e-3);
        if (g < g1) { g2 = g1; g1 = g; } else if (g < g2) g2 = g;
    }
    float px = pxAngle * tN;
    float edge = 1.0 - smoothstep(0.5 * px, 1.8 * px, g1);
    col = col * (1.0 - 0.18 * (1.0 - smoothstep(1.8 * px, 5.0 * px, g1))) + edge * 0.35;
    return col;
}

vec3 aces(vec3 c) { return clamp((c * (2.51 * c + 0.03)) / (c * (2.43 * c + 0.59) + 0.14), 0.0, 1.0); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float t = iTime;
    float a = 0.55 + t * 0.22;
    float c = cos(a), s = sin(a);
#if SHAPE == 0
    objRot = mat3(c, 0.0, -s,  0.0, 1.0, 0.0,  s, 0.0, c);
#else
    float tl = 0.35;   // gem tilted towards the camera
    mat3 tilt = mat3(1.0, 0.0, 0.0,  0.0, cos(tl), sin(tl),  0.0, -sin(tl), cos(tl));
    objRot = tilt * mat3(c, 0.0, -s,  0.0, 1.0, 0.0,  s, 0.0, c);
#endif
    objPos = vec3(0.0, floorY + restY, 0.0);
    sunDir = normalize(sunDirC);
    prepareCaustics();

    vec3 ro = vec3(0.0, 0.75, 3.7);
    vec3 ta = vec3(0.0, -0.20, 0.0);
    vec3 fw = normalize(ta - ro), rt = normalize(cross(fw, vec3(0.0, 1.0, 0.0))), up = cross(rt, fw);
    const float focal = 1.9;
    float pxAngle = 1.0 / (iResolution.y * 0.5 * focal);

    vec3 col = vec3(0.0);
    for (int i = 0; i < AA; i++)
    for (int j = 0; j < AA; j++) {
        vec2 o  = (vec2(i, j) + 0.5) / float(AA) - 0.5;
        vec2 uv = (fragCoord + o - 0.5 * iResolution.xy) / (0.5 * iResolution.y);
        vec3 rd = normalize(rt * uv.x + up * uv.y + fw * focal);
        col += render(ro, rd, pxAngle);
    }
    col /= float(AA * AA);

    col *= 1.15;
    col = aces(col);
    col = pow(col, vec3(1.0 / 2.2));
    fragColor = vec4(col, 1.0);
}

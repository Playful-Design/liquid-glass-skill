// =====================================================================
//  Broken glass pane (glsl-liquid-glass, mode `natural` + option `broken`)
//  Shadertoy-compatible mainImage. Full-frame pane seen head-on.
//  - Impact crack network: radial cracks (some stop early) + concentric
//    chords (polygonal rings, offset from sector to sector), crushed zone.
//  - Each shard: ONE flat normal, slightly tilted (1c rule 2), so each
//    shard catches the light differently and shifts the view behind it.
//  - Chipped (conchoidal) bevel along every crack: small steep curved
//    faces that act like tiny prisms -> spectral dispersion and glints.
//  - Hairline crack = air gap: glints where its wall faces the light.
//  - The light moves slowly, so the glints travel from shard to shard.
// =====================================================================

#define N_WL 6               // wavelengths for the dispersion on chipped faces
#define PI  3.14159265359
#define TAU 6.28318530718

// ---- Crack pattern
const vec2  impact     = vec2(0.10, 0.04);  // impact point (uv, y in [-0.5, 0.5])
const int   RADIAL     = 13;                // radial cracks
const int   RINGS      = 6;                 // ring chords per sector
const float ring0      = 0.045;             // first ring radius
const float ringGrowth = 1.75;              // ring spacing growth
const float crushR     = 0.035;             // crushed zone radius
const float shardTilt  = 0.09;              // max tilt of a shard

// ---- Glass
const float glassA          = 1.5046;       // crown glass (window)
const float glassB          = 0.0042;
const float dispersionBoost = 5.0;          // chips are tiny prisms: exaggerate
const float thickness       = 0.035;        // pane thickness (uv units), view shift
const float chipWidth       = 4.5;          // bevel width, in crack widths

// ---------------------------------------------------------------------
float h11(float n) { return fract(sin(n * 91.3458) * 47453.5453); }
float h21(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2  h22(vec2 p)  { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }

float gauss(float x, float m, float s) { float u = (x - m) / s; return exp(-0.5 * u * u); }
vec3  wlColor(float l) {
    return vec3(gauss(l, 600.0, 42.0) + 0.28 * gauss(l, 420.0, 20.0), gauss(l, 545.0, 42.0), gauss(l, 455.0, 30.0));
}
float wlAt(int i) { return mix(415.0, 685.0, (float(i) + 0.5) / float(N_WL)); }
float iorAt(float l) {
    float u = l * 1e-3, nMid = glassA + glassB / 0.3025;
    return nMid + dispersionBoost * (glassB / (u * u) - glassB / 0.3025);
}

// Explicit refraction (built-in refract() is unreliable on some drivers)
vec3 refr(vec3 I, vec3 N, float eta) {
    float c = -dot(N, I);
    float k = 1.0 - eta * eta * (1.0 - c * c);
    if (k <= 0.0) return vec3(0.0);
    return normalize(eta * I + (eta * c - sqrt(k)) * N);
}

// ---------------------------------------------------------------------
// Crack field: distance to the nearest crack, the 2D unit vector from
// that crack towards p, and an id for the shard p is in.
// ---------------------------------------------------------------------
float radAngle(int k, float r) {
    float fk = float(k);
    float base = (fk + 0.75 * (h11(fk + 3.7) - 0.5)) * TAU / float(RADIAL);
    return base + 0.06 * sin(r * 4.0 + fk * 1.7) + 0.022 * sin(r * 11.0 + fk * 3.1);   // gentle wander
}
// radius where radial crack k stops (crack 0 always runs to the edge).
// A crack that stops does NOT split the glass into two shards: shard ids
// come from the full-length cracks only, otherwise the tilt jumps along an
// invisible arc and shows as a ghost circle.
float radEnd(int k) {
    if (k == 0 || h11(float(k) * 5.3 + 1.0) < 0.55) return 1e3;
    return 0.18 + 0.9 * h11(float(k) * 2.1);
}
vec2  polar(float r, float a) { return r * vec2(cos(a), sin(a)); }

struct Crack { float d; vec2 n; vec2 id; float r; };

Crack crackField(vec2 p) {
    Crack c;
    float r = length(p);
    c.r = r;

    // crushed zone at the impact: small Voronoi chips
    if (r < crushR) {
        vec2 g = p * 140.0, ip = floor(g), fp = fract(g);
        float d1 = 8.0, d2 = 8.0; vec2 c1 = vec2(0.0), c2 = vec2(0.0), id = vec2(0.0);
        for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
            vec2 o = vec2(x, y), pt = o + h22(ip + o) - fp;
            float d = dot(pt, pt);
            if (d < d1) { d2 = d1; c2 = c1; d1 = d; c1 = pt; id = ip + o; }
            else if (d < d2) { d2 = d; c2 = pt; }
        }
        vec2 m = 0.5 * (c1 + c2), e = normalize(c2 - c1);
        c.d = abs(dot(m, e)) / 140.0;
        c.n = -e;
        c.id = id + 1000.0;
        return c;
    }

    float th = atan(p.y, p.x);
    if (th < radAngle(0, r)) th += TAU;

    // sector between the nearest ACTIVE radial cracks (those reaching radius r)
    int k = 0, kn = 0, kFull = 0; bool found = false;
    for (int i = 1; i < RADIAL; i++) {
        if (r > radEnd(i)) continue;
        if (radAngle(i, r) <= th) { k = i; if (radEnd(i) > 100.0) kFull = i; }
        else if (!found) { kn = i; found = true; }
    }
    float a0 = radAngle(k, r);
    float a1 = found ? radAngle(kn, r) : radAngle(0, r) + TAU;
    vec2 et = vec2(-sin(th), cos(th));

    c.d = r * (th - a0); c.n = et;
    float dB = r * (a1 - th);
    if (dB < c.d) { c.d = dB; c.n = -et; }

    // ring chords of this sector (own offsets per sector, some missing)
    int ring = 0;
    for (int j = 0; j < RINGS; j++) {
        float fj = float(j), fk = float(k);
        if (j > 0 && h21(vec2(fj, float(kFull)) + 0.37) < 0.45) continue;   // presence per full sector
        float base = ring0 * pow(ringGrowth, fj);
        float ra = base * (1.0 + 0.30 * (h21(vec2(fk, fj) + 1.1) - 0.5));
        float rb = base * (1.0 + 0.30 * (h21(vec2(fk, fj) + 2.3) - 0.5));
        vec2 A = polar(ra, radAngle(k, ra));
        vec2 B = polar(rb, found ? radAngle(kn, rb) : radAngle(0, rb) + TAU);
        vec2 pa = p - A, ba = B - A;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        vec2 q = pa - ba * h;
        float d = length(q);
        if (ba.x * pa.y - ba.y * pa.x < 0.0) ring = j + 1;               // beyond this chord
        if (d < c.d) { c.d = d; c.n = q / max(d, 1e-6); }
    }
    c.id = vec2(float(kFull), float(ring));
    return c;
}

// ---------------------------------------------------------------------
// Behind the pane: dark studio, two small coloured glows and one thin
// bright strip, so the shard shifts and the dispersion read.
// ---------------------------------------------------------------------
vec3 backdrop(vec2 uv) {
    vec3 col = mix(vec3(0.020, 0.018, 0.028), vec3(0.06, 0.05, 0.08), smoothstep(-0.6, 0.6, uv.y));
    col += vec3(0.85, 0.22, 0.30) * 0.30 * exp(-dot(uv - vec2(-0.60, -0.20), uv - vec2(-0.60, -0.20)) * 14.0);
    col += vec3(0.20, 0.45, 0.95) * 0.22 * exp(-dot(uv - vec2(0.62, 0.25), uv - vec2(0.62, 0.25)) * 16.0);
    float strip = 1.0 - smoothstep(0.0, 0.006, abs(uv.x + 0.28) - 0.012);
    col += vec3(1.0) * 1.2 * strip * smoothstep(0.55, 0.15, abs(uv.y));
    return col;
}

// Reflected environment: the moving softbox + one fixed panel (1c rule 5)
vec3 env(vec3 R, vec3 L) {
    vec3 col = vec3(0.02, 0.022, 0.03) + 0.05 * max(R.y, 0.0);
    col += 14.0 * smoothstep(0.990, 0.994, dot(R, L));
    col += 4.0 * smoothstep(0.955, 0.975, dot(R, normalize(vec3(-0.6, 0.5, 0.6))));
    return col;
}

vec3 aces(vec3 c) { return clamp((c * (2.51 * c + 0.03)) / (c * (2.43 * c + 0.59) + 0.14), 0.0, 1.0); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float px = 1.0 / iResolution.y;
    float t = iTime;

    // The moving light: glints travel across the shards
    vec3 L = normalize(vec3(0.55 * cos(t * 0.31), 0.45 * sin(t * 0.23) + 0.15, 0.80));
    vec2 Lp = normalize(L.xy + 1e-4);

    Crack c = crackField(uv - impact);

    // crack width (never below ~1 px, wider near the impact)
    float w = max(mix(0.0030, 0.0010, smoothstep(0.0, 0.9, c.r)), 0.9 * px);

    // 1. Shard normal: one flat tilt per shard, stronger near the impact
    vec2 rnd  = h22(c.id + 0.5) - 0.5;
    float amt = shardTilt * mix(1.0, 0.35, smoothstep(0.0, 0.8, c.r));
    vec3 N = normalize(vec3(rnd * 2.0 * amt, 1.0));

    // 2. Chipped bevel along the crack: steep, curved small faces
    float cw = w * chipWidth * (0.6 + 0.8 * h21(c.id + 9.1));
    float x  = c.d / cw;                           // 0 at the crack, 1 where the chip ends
    float chip = 0.0;
    if (x < 1.0) {
        float shell = 1.0 + 0.35 * sin(x * 14.0 + h21(c.id) * 6.0);   // conchoidal ripples (smooth)
        chip = (1.0 - x) * (1.0 - x);
        N = normalize(N + vec3(-c.n * chip * 1.6 * shell, 0.0));
    }

    vec3 V = vec3(0.0, 0.0, 1.0);
    float NdotV = max(dot(N, V), 0.001);

    // 3. Transmission with spectral dispersion (strong only where chips are steep)
    vec3 wsum = vec3(0.0);
    for (int i = 0; i < N_WL; i++) wsum += wlColor(wlAt(i));
    vec3 trans = vec3(0.0);
    for (int i = 0; i < N_WL; i++) {
        vec3 d = refr(-V, N, 1.0 / iorAt(wlAt(i)));
        vec2 off = d.xy / max(-d.z, 0.2) * thickness;
        trans += backdrop(uv + off) * wlColor(wlAt(i)) / wsum;
    }
    trans *= exp(-vec3(0.06, 0.04, 0.05) * (1.0 + 2.0 * chip));   // faint green edge tint of window glass

    // 4. Reflection (Fresnel, window glass) + clamped highlight (1c rule 4)
    float F = 0.04 + 0.96 * pow(clamp(1.0 - NdotV, 0.0, 1.0), 5.0);
    vec3 refl = env(reflect(-V, N), L);
    float spec = pow(max(dot(N, normalize(L + V)), 0.0), mix(900.0, 140.0, chip)) * mix(3.0, 6.0, chip);
    spec = min(spec, 2.5); spec = spec / (1.0 + 0.25 * spec);
    vec3 col = mix(trans, refl, F) + spec;

    // 5. Lit chips: the small broken faces turned towards the light throw coloured light
    float chipLit = chip * pow(max(dot(c.n, -Lp), 0.0), 3.0);
    col += chipLit * 0.9 * wlColor(mix(430.0, 670.0, x));

    // 6. Hairline crack (air gap): glints where the crack wall faces the light
    float aa = fwidth(c.d) + 0.5 * px;
    float line = 1.0 - smoothstep(w * 0.5 - aa, w * 0.5 + aa, c.d);
    float facing = abs(dot(c.n, Lp));
    float glint  = 0.12 + 1.6 * pow(facing, 6.0);
    vec3  fringe = wlColor(mix(420.0, 680.0, fract(facing * 1.7 + c.r * 2.0))) / 0.9;
    col = mix(col, glint * mix(vec3(1.0), fringe, 0.55), line * 0.9);

    // polished-edge cue: thin dark line just outside the crack (1c)
    col *= 1.0 - 0.25 * (1.0 - smoothstep(w * 0.6, w * 1.6, c.d)) * (1.0 - line);

    // crushed zone: whitish frosted chips
    col = mix(col, col * 0.6 + vec3(0.35), (1.0 - smoothstep(crushR * 0.7, crushR, c.r)) * 0.5);

    col *= 1.15;
    col = aces(col);
    col = pow(col, vec3(1.0 / 2.2));
    fragColor = vec4(col, 1.0);
}

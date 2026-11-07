// =====================================================================
//  glsl-sdf-shapes: library of 2D shapes used to replace letter marks.
//  Every shape is centred on the origin and fits [-1, 1].
//  Each block starts with "// @shape <name>" and ends with "// @end";
//  scripts copy only the blocks they need. Names: sdf<Name>(vec2 p).
// =====================================================================

// @shape circle
float sdfCircle(vec2 p) { return length(p) - 1.0; }
// @end

// @shape heart
// Exact heart (Inigo Quilez), recentred and scaled to fit [-1, 1]
float heartDot2(vec2 v) { return dot(v, v); }
float sdHeartIQ(vec2 p)
{
    p.x = abs(p.x);
    if (p.y + p.x > 1.0)
        return sqrt(heartDot2(p - vec2(0.25, 0.75))) - sqrt(2.0) / 4.0;
    return sqrt(min(heartDot2(p - vec2(0.00, 1.00)),
                    heartDot2(p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}
float sdfHeart(vec2 p)
{
    const float f = 0.604;
    return sdHeartIQ(p * f + vec2(0.0, 0.552)) / f;
}
// @end

// @shape star
// Exact 5-point star (Inigo Quilez), recentred to fit [-1, 1]
float sdStar5(vec2 p, float r, float rf)
{
    const vec2 k1 = vec2(0.809016994375, -0.587785252292);
    const vec2 k2 = vec2(-k1.x, k1.y);
    p.x = abs(p.x);
    p -= 2.0 * max(dot(k1, p), 0.0) * k1;
    p -= 2.0 * max(dot(k2, p), 0.0) * k2;
    p.x = abs(p.x);
    p.y -= r;
    vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
    float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
    return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}
float sdfStar(vec2 p) { return sdStar5(p + vec2(0.0, 0.0955), 1.0, 0.5); }
// @end

// @shape sparkle
// Exact n-point star (Inigo Quilez): 4 sharp points
float sdStarN(vec2 p, float r, int n, float m)
{
    float an = 3.141593 / float(n);
    float en = 3.141593 / m;
    vec2  acs = vec2(cos(an), sin(an));
    vec2  ecs = vec2(cos(en), sin(en));
    float bn = mod(atan(p.x, p.y), 2.0 * an) - an;
    p = length(p) * vec2(cos(bn), abs(sin(bn)));
    p -= r * acs;
    p += ecs * clamp(-dot(p, ecs), 0.0, r * acs.y / ecs.y);
    return length(p) * sign(p.x);
}
float sdfSparkle(vec2 p) { return sdStarN(p, 1.0, 4, 3.2); }
// @end

// @shape diamond
// Exact rhombus (Inigo Quilez)
float rhombusNdot(vec2 a, vec2 b) { return a.x * b.x - a.y * b.y; }
float sdfDiamond(vec2 p)
{
    const vec2 b = vec2(0.72, 1.0);
    p = abs(p);
    float h = clamp(rhombusNdot(b - 2.0 * p, b) / dot(b, b), -1.0, 1.0);
    float d = length(p - 0.5 * b * vec2(1.0 - h, 1.0 + h));
    return d * sign(p.x * b.y + p.y * b.x - b.x * b.y);
}
// @end

// @shape moon
// Exact crescent (Inigo Quilez), opening to the right
float sdMoonIQ(vec2 p, float d, float ra, float rb)
{
    p.y = abs(p.y);
    float a = (ra * ra - rb * rb + d * d) / (2.0 * d);
    float b = sqrt(max(ra * ra - a * a, 0.0));
    if (d * (p.x * b - p.y * a) > d * d * max(b - p.y, 0.0))
        return length(p - vec2(a, b));
    return max(length(p) - ra, -(length(p - vec2(d, 0.0)) - rb));
}
float sdfMoon(vec2 p) { return sdMoonIQ(p + vec2(0.1, 0.0), 0.55, 0.95, 0.8); }
// @end

// @shape flower
// Five round petals around a round centre (composed)
float sdfFlower(vec2 p)
{
    const float sector = 6.2831853 / 5.0;
    float an = round(atan(p.y, p.x) / sector) * sector;
    vec2  q  = vec2(cos(an) * p.x + sin(an) * p.y, -sin(an) * p.x + cos(an) * p.y);
    float petal = length(q - vec2(0.58, 0.0)) - 0.42;
    return min(petal, length(p) - 0.36);
}
// @end

// @shape plus
// Plus sign: union of two exact boxes (composed)
float plusBox(vec2 p, vec2 b) { vec2 q = abs(p) - b; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0); }
float sdfPlus(vec2 p) { return min(plusBox(p, vec2(1.0, 0.3)), plusBox(p, vec2(0.3, 1.0))) ; }
// @end

// @shape butterfly
// Butterfly: two pairs of round wings blended into a slim body, with antennae (composed)
float bflySmin(float a, float b, float k) { float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0); return mix(b, a, h) - k * h * (1.0 - h); }
float bflySeg(vec2 p, vec2 a, vec2 b, float r) { vec2 pa = p - a, ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return length(pa - ba * h) - r; }
float sdfButterfly(vec2 p)
{
    p.y -= 0.05;
    vec2 q = vec2(abs(p.x), p.y);
    float upper = length(q - vec2(0.50, 0.30)) - 0.44;             // fore wings
    float lower = length(q - vec2(0.34, -0.42)) - 0.30;            // hind wings
    float wings = bflySmin(upper, lower, 0.12);
    wings = bflySmin(wings, length(q - vec2(0.12, -0.05)) - 0.22, 0.10);   // wing roots, no gap at the body
    float body  = bflySeg(p, vec2(0.0, -0.62), vec2(0.0, 0.42), 0.09);
    float ant   = bflySeg(q, vec2(0.03, 0.42), vec2(0.26, 0.82), 0.045);
    ant = min(ant, length(q - vec2(0.27, 0.84)) - 0.08);           // antenna tips
    return min(bflySmin(wings, body, 0.06), ant);
}
// @end

// @shape butterflies
// Two butterflies in flight, a big one and a small one (composed)
float bfliesSmin(float a, float b, float k) { float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0); return mix(b, a, h) - k * h * (1.0 - h); }
float bfliesSeg(vec2 p, vec2 a, vec2 b, float r) { vec2 pa = p - a, ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return length(pa - ba * h) - r; }
float bfliesOne(vec2 p)
{
    p.y -= 0.05;
    vec2 q = vec2(abs(p.x), p.y);
    float wings = bfliesSmin(length(q - vec2(0.50, 0.30)) - 0.44, length(q - vec2(0.34, -0.42)) - 0.30, 0.12);
    wings = bfliesSmin(wings, length(q - vec2(0.12, -0.05)) - 0.22, 0.10);
    float body  = bfliesSeg(p, vec2(0.0, -0.62), vec2(0.0, 0.42), 0.09);
    float ant   = min(bfliesSeg(q, vec2(0.03, 0.42), vec2(0.26, 0.82), 0.05), length(q - vec2(0.27, 0.84)) - 0.09);
    return min(bfliesSmin(wings, body, 0.06), ant);
}
mat2 bfliesRot(float a) { return mat2(cos(a), sin(a), -sin(a), cos(a)); }
float sdfButterflies(vec2 p)
{
    const float s1 = 0.56, s2 = 0.38;
    float big   = bfliesOne(bfliesRot( 0.30) * (p - vec2(-0.38,  0.36)) / s1) * s1;
    float small = bfliesOne(bfliesRot(-0.35) * (p - vec2( 0.55, -0.50)) / s2) * s2;
    return min(big, small);
}
// @end

// @shape cloud
// Fluffy cloud: round puffs on a rounded base (composed)
float cloudSmin(float a, float b, float k) { float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0); return mix(b, a, h) - k * h * (1.0 - h); }
float sdfCloud(vec2 p)
{
    p.y += 0.02;
    float d = length(p - vec2(-0.56, -0.18)) - 0.36;
    d = cloudSmin(d, length(p - vec2(0.00, 0.16)) - 0.52, 0.18);
    d = cloudSmin(d, length(p - vec2(0.56, -0.14)) - 0.38, 0.18);
    vec2 b = abs(p - vec2(0.0, -0.36)) - vec2(0.62, 0.06);          // flat bottom
    float base = length(max(b, 0.0)) + min(max(b.x, b.y), 0.0) - 0.18;
    return cloudSmin(d, base, 0.20);
}
// @end

// @shape crown
// Crown: three spikes topped with pearls, on a band (exact polygon + circles)
float crownPoly(vec2 p)
{
    const int N = 7;
    vec2 v[N] = vec2[N](vec2(-0.78, -0.42), vec2(-0.86, 0.48), vec2(-0.40, 0.04),
                        vec2( 0.00,  0.62), vec2( 0.40, 0.04), vec2( 0.86, 0.48), vec2(0.78, -0.42));
    float d = dot(p - v[0], p - v[0]);
    float s = 1.0;
    for (int i = 0, j = N - 1; i < N; j = i, i++)
    {
        vec2 e = v[j] - v[i], w = p - v[i];
        vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
        d = min(d, dot(b, b));
        bvec3 c = bvec3(p.y >= v[i].y, p.y < v[j].y, e.x * w.y > e.y * w.x);
        if (all(c) || all(not(c))) s *= -1.0;
    }
    return s * sqrt(d);
}
float sdfCrown(vec2 p)
{
    p.y += 0.02;
    float d = crownPoly(p) - 0.03;
    d = min(d, length(p - vec2(-0.86, 0.58)) - 0.13);               // pearls
    d = min(d, length(p - vec2( 0.00, 0.74)) - 0.14);
    d = min(d, length(p - vec2( 0.86, 0.58)) - 0.13);
    vec2 b = abs(p - vec2(0.0, -0.58)) - vec2(0.80, 0.12);           // band
    return min(d, length(max(b, 0.0)) + min(max(b.x, b.y), 0.0) - 0.06);
}
// @end

// @shape spade
// Spade (ace of spades): an upside-down heart on a flared stem (composed)
float spadeDot2(vec2 v) { return dot(v, v); }
float spadeHeart(vec2 p)
{
    p.x = abs(p.x);
    if (p.y + p.x > 1.0) return sqrt(spadeDot2(p - vec2(0.25, 0.75))) - sqrt(2.0) / 4.0;
    return sqrt(min(spadeDot2(p - vec2(0.00, 1.00)), spadeDot2(p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}
float spadeTri(vec2 p, vec2 p0, vec2 p1, vec2 p2)
{
    vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
    vec2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
    vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                     vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                     vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}
float sdfSpade(vec2 p)
{
    const float f = 0.85;
    float body = spadeHeart(vec2(p.x, 0.80 - p.y) * f) / f;          // point up, lobes down
    float stem = spadeTri(p, vec2(0.0, -0.30), vec2(-0.34, -0.98), vec2(0.34, -0.98));
    return min(body, stem);
}
// @end

// @shape club
// Club (trèfle): three round leaves on a flared stem (composed)
float clubSmin(float a, float b, float k) { float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0); return mix(b, a, h) - k * h * (1.0 - h); }
float clubTri(vec2 p, vec2 p0, vec2 p1, vec2 p2)
{
    vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
    vec2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
    vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                     vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                     vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}
float sdfClub(vec2 p)
{
    float d = length(p - vec2(0.00, 0.55)) - 0.38;
    d = clubSmin(d, length(p - vec2(-0.50, -0.02)) - 0.38, 0.08);
    d = clubSmin(d, length(p - vec2( 0.50, -0.02)) - 0.38, 0.08);
    d = clubSmin(d, length(p - vec2( 0.00,  0.12)) - 0.22, 0.08);
    float stem = clubTri(p, vec2(0.0, 0.0), vec2(-0.32, -0.98), vec2(0.32, -0.98));
    return min(d, stem);
}
// @end

// @shape fullmoon
// Full moon: a disc with craters (composed)
float sdfFullmoon(vec2 p)
{
    float d = length(p) - 1.0;
    d = max(d, -(length(p - vec2(-0.36,  0.30)) - 0.22));
    d = max(d, -(length(p - vec2( 0.30, -0.22)) - 0.30));
    d = max(d, -(length(p - vec2( 0.18,  0.55)) - 0.12));
    d = max(d, -(length(p - vec2(-0.30, -0.50)) - 0.14));
    return d;
}
// @end

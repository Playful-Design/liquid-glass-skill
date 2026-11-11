---
name: glsl-sdf-typography
description: Writes any word, name or sentence as 3D liquid glass lettering in GLSL, in any real font (Google Fonts by name, a font file, or a vibe such as romantic, cloud, medieval, cartoon) or in hand-built neon tubes, filled with the moving liquid glass surface, on a solid background color (black by default) or on the user's own image, with a ready-to-open HTML preview. Reads plain-language requests or the /liquid-glass-skill short syntax to find the text, the background color and which letter marks (i/j dots, punctuation dots, accents) to replace with shapes from glsl-sdf-shapes. Use when the user asks to write, spell or render a word, name, title, phrase or sentence in glass, GLSL or SDF, or to replace the dot or accent of a letter with a heart, star or other shape.
---

# GLSL SDF Typography Builder

## 1. Role and Expected Behavior
You are a GLSL SDF (Signed Distance Field) typography expert. When invoked, read the user's request (section 2), set the text in the requested letter style (section 2.1), and deliver one complete, executable shader: liquid glass letters on a solid background (section 7). The letters keep the liquid glass look: the moving liquid surface of the `glsl-liquid-glass` skill is visible **through the letters and shapes only**, while everything around them is one flat color.
DO NOT hardcode the entire alphabet. Only generate SDF functions for the characters actually present in the requested text.

## 2. Reading the Request
Requests come either as the `/liquid-glass-skill` short syntax (that skill defines it), or as plain sentences, for example:
- *"Write 'Joyeux anniversaire Mia' and replace the dot of the i in Mia with a heart."*
- *"The phrase 'pixel jam': the i gets a star instead of its dot, the j a diamond, cream background."*
- *"Bonjour Chloé on two lines, with a little moon instead of the accent on the é."*

Extract five things:

1. **Text.** The exact string to render. Quoted text wins; otherwise take the words the user explicitly designates ("write my name Chloé", "the title …"). Keep case, accents, punctuation and spacing exactly as given. Never translate, correct spelling or change case. If it is unclear which words to render, ask one short question.
2. **Line breaks.** Honor explicit ones ("on two lines", a `/`, a newline). Otherwise wrap automatically (section 6).
3. **Mark edits.** For each one: target character, which occurrence(s), shape, and options (size, color, melted or floating).
   - Occurrence: "the i in Mia", "the second i", "the last j", "every i". If the user names a character that occurs several times without saying which, apply the edit to **all** of them and say so.
   - Only detachable marks can be replaced (table below). If the user targets a character without one (e.g. "the dot of the o", or the uppercase `I`), do not invent silently: ask whether to add the shape above the letter as an ornament.
   - Shapes come from the `glsl-sdf-shapes` catalogue. If a requested shape is not listed, build it as that skill describes and say it is a composed approximation.
   - Default: the shape replaces the whole mark (both dots of a diaeresis unless the user says one), floats above the letter, and has the same glass as the letters.
4. **Font or vibe** (section 2.1). A mood word ("storybook", "romantic", "fluffy") picks a vibe. Default: `DM Serif Display`.
5. **Background.** One solid color, black `#000000` by default (or the vibe's color). Accept color names (the `liquid-glass-skill` skill has the table) and hex codes. **Or an image** the user gives (a file path, or an image attached to the message: save it to a file first), see section 2.2. The liquid surface is never shown around the letters, only inside them (section 7.2): letters in front of a moving liquid background cannot be read. That surface alone, as a full-screen background, is the `glsl-liquid-glass` skill.

| Replaceable mark | Characters | Default build | Centre |
|---|---|---|---|
| Tittle (dot) | `i` `j` | circle, radius `R` | `y = +0.60` |
| Punctuation dots | `.` `:` `;` `!` `?` | circle, radius `R` | on the baseline or above it, as the glyph needs |
| Diaeresis (two dots) | `ä ë ï ö ü ÿ` and capitals | two circles, `x = ±0.22` | `+0.60` (lowercase), `+1.30` (capitals) |
| Acute, grave, circumflex | `é è ê à â î ô û ù` and capitals | short capsules | `+0.60` (lowercase), `+1.30` (capitals) |
| Cedilla | `ç` `Ç` | short arc below | `y = -1.30` |
| Ring | `å` `Å` | small ring | `+0.60` / `+1.30` |

Before the code, print a short summary so the user can check your reading:

| Text | Lines | Mark edits | Font | Background |
|---|---|---|---|---|
| `happy birthday Chloe` | `happy birthday` / `Chloe` | `i` in *birthday* → star (floating) | DM Serif Display | black `#000000` |
| `Be mine` | 1 | `i` → heart | Lavishly Yours (vibe *romantic*) | `#F6D5DC` |
| `Mia` | 1 | `i` → heart | DM Serif Display | image `beach.jpg` |

### 2.1 Letter style: a real font (default) or neon tubes

**Font mode (default).** The letters are the real outlines of a font, turned into exact distance functions and rendered as puffy liquid glass. Do not draw these letters by hand: run the script, which writes the whole shader from `templates/liquid-glass-text.glsl` and the shapes in `glsl-sdf-shapes/shapes.glsl`.

```bash
python3 <this skill>/scripts/font_to_glsl.py --google "DM Serif Display" \
    --text "I love/Playful Design!" --mark "i@Design=star" --mark "!=heart" \
    --bg "#B5A0D0" --out i-love-playful-design.glsl
```

| User says | Script option |
|---|---|
| `vibe romantic`, "storybook style", "something fluffy" | `--vibe romantic` (table below) |
| `tint pink`, "pink glass", "clear glass" | `--tint pink` (pastel palette); "clear" → `--tint white` |
| `rainbow`, "original liquid colors", "iridescent" | `--palette liquid` |
| `3d`, "separate 3D letters", "puffy balloon letters" | `--look objects` (section 7.0) |
| `font Pacifico`, "in Playfair Display" | `--google "Pacifico"` (downloaded from Google Fonts, cached in `~/.cache/liquid-glass-fonts`) |
| a font file ("use ~/fonts/Brand.otf") | `--font PATH` |
| `bold`, `italic`, `weight 800` | `--style Bold` / `--style Italic` for static families, `--axis wght=800` for variable ones |
| the text, `/` for a new line | `--text "line one/line two"`. Choose the lines as section 6 says |
| "the i in Design → star" | `--mark "i@Design=star"` |
| "the 2nd i", "every i" | `--mark "i:2=star"`, `--mark "i=star"` |
| "dot of the ! → heart", bigger | `--mark "!=heart"`, `--mark "!=heart*1.3"` |
| "a full moon **instead of** the o" (whole letter, any character) | `--replace "o=fullmoon"`, `--replace "o@love=heart"` (same syntax as `--mark`; the shape takes the letter's place and size) |
| background color | `--bg "#B5A0D0"` or a color name |
| background image | `--image PATH` (section 2.2) |
| puffier / flatter glass | `--puff 0.25` / `--puff 0.10` (default: from the font's stem width) |
| looser / tighter spacing, line spacing | `--tracking 0.05` (em), `--line-height 1.0` |

- Heavy decorative fonts (textures, splatters): `--simplify 0.008` drops the tiny specks and keeps the shader fast. The script prints the number of `segments` and a `warning` above 4000: browsers can give up on such a shader (a blank page or a frown icon). Raise `--simplify` (0.008, then 0.015) or shorten the text. A vibe can set `simplify` in `vibes.json`; avoid fonts that still exceed 4000 segments on short texts.
- Detailed shapes (`butterflies`, `crown`, `butterfly`) need room: give them `*2` or more on an i, and prefer `butterfly` over `butterflies` when the text is small or on a light background.
- Shapes available to the script: `circle heart star sparkle diamond moon fullmoon flower plus butterfly butterflies cloud crown spade club` (words like "ace of spades", "trèfle", "full moon" map to them: see the `glsl-sdf-shapes` catalogue). For any other shape, add it to `shapes.glsl` first (the `glsl-sdf-shapes` skill says how).
- The script refuses a mark on a character with no detachable dot or accent in that font, and a character missing from the font. Report this to the user instead of working around it.
- **Licences:** Google Fonts are free to embed (OFL or Apache). For a font file the user brings, remind them once that the shader contains the letter outlines, so the font's licence must allow embedding.
- **Cost:** a font letter is 20 to 60 curves, so a long sentence is heavier than the tubes. If a sentence goes beyond about 40 characters, warn that it may run slowly on weak GPUs.
- If you can render the shader (for example with WebGL in a headless browser), check it once, especially the marks: a shape that collides with a neighbour gets `*0.8`.

**Vibes** (`vibes.json` in this skill; each sets the font, a background color used only when the user names none, and any tuning). Match the user's words to a vibe or one of its aliases:

| Vibe | Also matches | Font | Default background |
|---|---|---|---|
| `adventure` | adventurous, bold, explorer | Caprasimo | deep teal `#12343B` |
| `cloud` | cloudy, fluffy, soft, bubbly | Rubik Bubbles | sky `#BFD9F2` |
| `medieval` | fantasy, celtic, knight | Uncial Antiqua | night blue `#14202B` |
| `romantic` | valentine, love, wedding | Lavishly Yours | blush `#F6D5DC` |
| `cartoon` | storybook, old design, whimsical | Henny Penny | cream `#F2EEE6` |
| `dripping` | drips, wet paint, melting, spooky | Rubik Wet Paint | black `#0A0A0A` |

- If the user describes a mood that matches no vibe, pick a fitting Google Font yourself, say which, and offer to save it as a new vibe (add an entry to `vibes.json`, then reinstall the skill).

**Neon tube mode** (`font tubes`, "neon", "monoline"): the hand-built letters of sections 3 to 6, round glass tubes of constant thickness. Use it only when the user asks for that look.

### 2.2 On an image
With `--image PATH` the user's picture replaces the solid color: it fills the frame (cropped to cover it, like a wallpaper), the letters cast their soft contact shadow on it, and the glass letters bend it like real glass. Inside the letters, `photoInGlass` mixes the liquid surface with the picture (`--photo-in-glass`, default `0.35`; `0` = liquid only, `1` = clear glass showing only the picture). Use `1` when the user wants "clear glass on my photo", `0` when they want the liquid letters to stand out.
- The shader reads the picture from `iChannel0`. Besides the `.glsl`, the script writes **`NAME.html`**: a page with the shader and the picture built in, which plays live in any browser by double-clicking it. Always point the user to this file: Shadertoy cannot load their own pictures without an extension. In the page, dropping another image onto it swaps the background, Space pauses, S saves a PNG.
- iPhone photos (HEIC) and pictures over 3 MB are converted to a JPEG of 2048 px at most (macOS `sips`).
- A busy photo makes letters harder to read: if needed, suggest a calmer area of the picture, a lower `--photo-in-glass`, or a bigger text.

## 3. Rules for Building Letters (Tube Strokes, neon tube mode only)
The letters are round glass tubes (neon style). Build every letter **exclusively** from strokes of one constant radius `const float R = 0.15;`: straight capsules and circular arcs. Every stroke of every letter and default mark uses `R` (monoline). The 2D distance to the strokes later becomes a 3D tube (section 7.3).

```glsl
float sdCapsule(vec2 p, vec2 a, vec2 b, float r) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba)/dot(ba, ba), 0.0, 1.0);
    return length(pa - ba*h) - r;
}

// Stroke along a circular arc: centre c, radius ra, middle direction `dir`
// (radians, 0 = +x, PI/2 = up), half-aperture `ap` (PI/2 = half circle, PI = full circle).
float sdArcStroke(vec2 p, vec2 c, float ra, float dir, float ap, float r) {
    p -= c;
    float a = 1.5707963 - dir;                 // rotate so that `dir` points to +y
    p = mat2(cos(a), sin(a), -sin(a), cos(a)) * p;
    vec2 sc = vec2(sin(ap), cos(ap));
    p.x = abs(p.x);
    return ((sc.y*p.x > sc.x*p.y) ? length(p - sc*ra) : abs(length(p) - ra)) - r;
}
```

**Metrics (glyph units, stroke centrelines):**
- Capitals and digits: baseline `y = -0.85`, cap line `y = +0.85` (ink spans `-1.0` to `+1.0`).
- Lowercase: x-height `y = +0.15`, ascenders up to `+0.85`, descenders down to `-1.55`.
- Half-width `hw` (centreline): standard capitals `0.40`, standard lowercase and digits `0.35`, wide (`M W m w`) `0.60`, narrow (`I i l j ! . , : ; '`) `0.0` to `0.15`. Each glyph is centred on its own origin `x = 0`.
- Round letters (`O C G D U S o c e …`) are stadiums: half-circle arcs joined by straight capsules. Never scale `p` non-uniformly to make an ellipse, because that breaks the distance field.
- Unsupported characters (non-Latin scripts, emoji): tell the user instead of guessing.

Reference glyphs (match their style for every other character):

```glsl
float glyph_O(vec2 p) {
    float d = sdArcStroke(p, vec2(0.0,  0.45), 0.40,  1.5708, 1.5708, R);
    d = min(d, sdArcStroke(p, vec2(0.0, -0.45), 0.40, -1.5708, 1.5708, R));
    d = min(d, sdCapsule(p, vec2(-0.40, -0.45), vec2(-0.40, 0.45), R));
    d = min(d, sdCapsule(p, vec2( 0.40, -0.45), vec2( 0.40, 0.45), R));
    return d;
}

float glyph_A(vec2 p) {
    float d = sdCapsule(p, vec2(0.0, 0.85), vec2(-0.45, -0.85), R);
    d = min(d, sdCapsule(p, vec2(0.0, 0.85), vec2( 0.45, -0.85), R));
    d = min(d, sdCapsule(p, vec2(-0.29, -0.25), vec2(0.29, -0.25), R));
    return d;
}

// Lowercase bowl, shared by a b d o p q g e…
float bowl(vec2 p) {
    float d = sdArcStroke(p, vec2(0.0, -0.20), 0.35,  1.5708, 1.5708, R);
    d = min(d, sdArcStroke(p, vec2(0.0, -0.50), 0.35, -1.5708, 1.5708, R));
    d = min(d, sdCapsule(p, vec2(-0.35, -0.50), vec2(-0.35, -0.20), R));
    d = min(d, sdCapsule(p, vec2( 0.35, -0.50), vec2( 0.35, -0.20), R));
    return d;
}
float glyph_d(vec2 p) { return min(bowl(p), sdCapsule(p, vec2(0.35, -0.85), vec2(0.35, 0.85), R)); }

float glyph_i(vec2 p) {
    float d = sdCapsule(p, vec2(0.0, -0.85), vec2(0.0, 0.15), R);   // stem up to x-height
    return min(d, length(p - vec2(0.0, 0.60)) - R);                 // default tittle
}
```

## 4. Custom Dots and Accents (Shape Integration, neon tube mode; the script does this in font mode)
When a mark edit applies (section 2):
1. Build the base of the letter without its mark (e.g. `glyph_dotless_i`, the stem alone).
2. Add the shape as a separate **mark** through the `MARK` macro (section 6), not inside the glyph. Marks go into their own distance, because shapes get a different 3D profile from the tubes (section 7.3).
3. The shape is the 2D SDF from `glsl-sdf-shapes`, centred on the origin and fitting `[-1, 1]`, scaled exactly: `sdfShape((p - c) / s) * s`.
4. Size and position: half-size `s = 0.24` for compact shapes (heart, circle, diamond, moon), `s = 0.30` for spiky or thin ones (star, sparkle, flower, lightning bolt). Centre it at the mark's position from the table, nudged up `0.08` (`s = 0.24`) or `0.12` (`s = 0.30`), so that at least `0.10` of clear space separates it from the stem.
5. Floating (default): marks stay a separate object. `melted`: lower the mark until it touches the stem and blend the mark and stroke distances with `smin` (k ≈ 0.08) inside `mapGlyphs`.
6. If the shape is wider than its letter, check its neighbours: a shape above the x-height only collides with ascenders and capitals. Widen the spacing only if the shape would come within `0.10` of their ink.

**Colored shapes:** if the user wants a mark in a different color ("a red heart"), give it its own material: `map` also returns which object was hit (tube or mark), and the mark uses its own absorption coefficients (section 7.4). Examples: red `(0.08, 0.90, 0.80)`, pink `(0.05, 0.60, 0.35)`, gold `(0.10, 0.25, 0.90)`, green `(0.70, 0.10, 0.60)`.

## 5. Variable Kerning (Spacing, neon tube mode; fonts use their own kerning)
Letters have different widths. Compute the distance from each glyph origin to the next from their real ink extents:

`advance(a → b) = rightExtent_a + leftExtent_b + 2*R + tracking`

where the extents are the centreline extents on each side (`hw` for symmetric letters; measure asymmetric ones such as `r t C e`).

- `tracking = 0.20` by default, `0.28` for short all-caps words, `0.15` for long sentences.
- Optical pairs: subtract `0.10` to `0.30` where an open or diagonal side meets another (`AV VA LT To Ty LY ry py ay rt`), and `0.05` between two rounds (`OO oc oe`).
- Never let neighbours' ink touch: keep at least `0.10` between the closest outer edges.
- Word space: `0.90` between the neighbouring letters' ink edges, instead of the tracking.

Precompute the x position of every glyph in a line, then centre each line on its ink bounds.

## 6. Layout for Sentences and Performance
- **Wrapping:** break only at spaces, never inside a word. Keep phrases that belong together on one line (`happy birthday` / `Chloe`), then aim for lines of at most about 16 glyph units and a text block whose shape is close to the screen's (16:9). Above 4 lines, warn that readability drops and suggest shortening the text.
- **Line spacing:** baseline to baseline `3.6` (`4.0` if a line has accented capitals under a line with descenders). Centre the block vertically.
- **Safe culling:** sentences contain many strokes, so skip glyphs and lines whose bounding box is farther than the best distance found so far. This is exact because a box always lies closer than the ink inside it. Never return a fake large distance for culled regions instead, because the raymarcher would then step through the letters.

```glsl
float sdBox(vec2 p, vec2 b) { vec2 q = abs(p) - b; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0); }

// Strokes accumulate in d (tube profile), shapes replacing marks in dM (rounded slab).
#define GLYPH(fn, x, hw) { vec2 g = q - vec2(x, 0.0); \
    if (sdBox(g - vec2(0.0, -0.08), vec2((hw) + 0.45, 1.80)) < d) d = min(d, fn(g)); }
#define MARK(fn, x, y, s) { vec2 g = q - vec2(x, y); \
    if (sdBox(g, vec2((s) + 0.1)) < dM) dM = min(dM, fn(g / (s)) * (s)); }

vec2 sdfText(vec2 p) {
    float d = 1e10, dM = 1e10;
    // Line 1: "happy birthday", baseline offset and glyph x positions precomputed (sections 5 and 6)
    vec2 q = p - vec2(0.0, 1.8);
    if (sdBox(q - vec2(0.0, -0.08), vec2(LINE1_HALF_W + 0.45, 1.80)) < min(d, dM)) {
        GLYPH(glyph_h, -6.9165, 0.35)
        // ...
        GLYPH(glyph_dotless_i, 0.5435, 0.12)
        MARK(sdfStar, 0.5435, 0.72, 0.30)
        // ...
    }
    // Line 2 ...
    return vec2(d, dM);
}
```

## 7. Liquid Glass Letters on a Solid Background

### 7.0 Looks: one surface (default) or separate 3D letters
**Surface look (default, `templates/liquid-glass-text-surface.glsl`).** The text is cut out of ONE continuous liquid glass surface: the `glsl-liquid-glass` height field and optics, evaluated in screen space across the whole text, plus a rounded rim along every outline (`rimProfile`, width `PUFF`) that bends the light like a glass edge. The letters read as one material and the liquid visibly flows from letter to letter. It is 2D (no raymarching), so it is light and smooth.
- **Default palette by background:** `liquid` on a dark background (luminance below 0.35: black, navy, dark grey…), where pastel glass looks silver and loses the liquid glass feeling; `pastel` on a light background and on images. `--palette` overrides it.
- Palette `pastel` (light backgrounds; the user's chosen look, "pastel rich"): soft light studio tinted by `pastelTint`, softened thin-film spectrum (`a = 0.70, b = 0.30`), lighter absorption (`× 0.45`), gentler highlights. The tint defaults to the background's hue at pastel strength (a soft lilac on white, grey or black backgrounds); `--tint COLOR` sets it.
- Palette `liquid` (dark backgrounds, or `--palette liquid`; "original colors", "rainbow", "deep", "iridescent"): exactly the `glsl-liquid-glass` look, deep night blue and full iridescence, cut into the text.
- Why this is the default: separate 3D letters each refract a different part of the liquid and each catch their own highlights and rainbow rims, so a sentence looks like a row of foil balloons and has too many colors. Do not go back to it unless the user asks.

**Objects look (`--look objects`; "3D letters", "each letter in 3D", "puffy", "balloon"):** each letter is a puffy 3D glass object filled with the liquid, as described in the rest of this section (7.1 to 7.6). Tube mode uses it too.

The rest of this section describes the objects look. The letters use the optical pipeline of the `glsl-liquid-glass` skill, and the liquid surface of that skill fills them: it lies behind the glass, and only rays that pass through a letter or shape can see it. The background around the letters is one flat color.

### 7.1 Shared optics
Declare the optical constants **once** at the top, using the `glsl-liquid-glass` names and values: `thinFilmPalette`, `sampleEnv`, `F0 = 0.12`, Fresnel power `4.5`, IORs `1.48 / 1.52 / 1.56`, `absorptionCoeff = (0.75, 0.35, 0.18)`, `absorptionScale`, the key and fill lights (`L1`, `L2`) and their specular exponents and intensities. The finish skills (`/frost`, `/polished`, `/denser`, `/lighter`, `/transparent`, `/translucent`) then apply to the letters and the liquid inside them, and `/smooth` and `/textured` change the liquid's height field.

### 7.2 Background and the liquid inside the letters
- `const vec3 bgColor` at the very top of the file, in sRGB, with a comment saying the user can change it there.
- Pixels that see the background directly output `bgColor` **exactly** (times the contact shadow below). Do not apply vignette, exposure, tone mapping or gamma to them, so the color is the one the user asked for.
- **The liquid:** copy the `glsl-liquid-glass` height field and steps 1 to 5 of its pipeline (no post-processing) into `vec3 liquidBackground(vec2 uv, float t)`, returning linear color. It lies on a plane at `bgZ = -R * k - 0.25` (world units, `k` below), behind the letters. Only rays that **leave the glass** reach it: at the point `P` where such a ray meets the plane, take `liquidBackground(0.5 * P.xy / bgHalfH, t)` with `bgHalfH = (camZ - bgZ) / focal`. The `0.5` matches the standalone shader's uv, which spans `[-0.5, 0.5]` vertically, so the liquid has the same scale as the original background. Rays that miss the letters never see the liquid.
- **Contact shadow** (grounds the letters, and is what keeps them readable on light colors): project the plane point toward the key light onto the text plane, `T = P.xy + L1n.xy * (-bgZ) / L1n.z` (with `L1n = normalize(L1)`), and multiply by `mix(1.0 - shadowStrength, 1.0, smoothstep(-0.05, 0.6 * (-bgZ), min(dText.x, dText.y) * k))`, with `shadowStrength = 0.25`. On black it is invisible, which is fine.

### 7.3 Camera, glass profile and raymarching
In font mode the template already contains all of 7.1 to 7.5; the profile there is the puffy one: `length(vec2(max(d + PUFF, 0.0), z)) - PUFF`, which keeps the outline exact and rounds thick strokes fully while thin strokes become thin lenses. The rest of this section describes the tube mode, which uses the same pipeline.

- Camera: `ro = vec3(0, 0, camZ)` with `camZ = 6.0`, `rd = normalize(vec3(uv, -focal))` with `focal = 2.0`, where `uv` is centred and spans `[-1, 1]` vertically.
- **Fit:** with `W` and `H` the text block's ink size in glyph units, `k = 0.72 * min(2.0 * 3.0 * aspect / W, 2.0 * 3.0 / H)` converts glyph units to world units (`3.0 = camZ / focal`, the visible half-height at `z = 0`). Use `0.72`, not more, so that perspective never pushes the text out of the frame.
- **Glass profile:** letters are round tubes around the stroke centrelines. A flat extrusion looks like plastic on a solid background, while tubes bend the light like real glass. Marks are rounded slabs with the same front as the tubes, because thin shape points would vanish as tubes. Work in glyph units, then scale the whole 3D position uniformly (this keeps the distance exact):

```glsl
const float markBevel = 0.07;
float mapGlyphs(vec3 pos) {
    vec2 d2 = sdfText(pos.xy);
    float dTube = length(vec2(max(d2.x + R, 0.0), pos.z)) - R;          // letters
    vec2 w = vec2(d2.y + markBevel, abs(pos.z) - (R - markBevel));       // marks
    float dMark = min(max(w.x, w.y), 0.0) + length(max(w, 0.0)) - markBevel;
    return min(dTube, dMark);
}
float map(vec3 pos) { return mapGlyphs(pos / k) * k; }
```

- **The text stands still; only the liquid inside it moves.** Do not animate the letters (no sway, no rotation): moving letters must be re-traced every frame, which makes the animation stutter, while still letters let the preview compute their shape once.
- Split the shader in two, as the font-mode template does: `geometryPass` (raymarching, normals, thickness, where the red, green and blue rays leave the glass, contact shadows: all independent of time) and `shadingPass` (liquid, reflections, highlights, post-processing: the only part that uses `iTime`). `mainImage` calls both, for Shadertoy; the `.html` preview runs `geometryPass` once per window size into float textures, then only `shadingPass` every frame, which is what makes it smooth.
- Intersect the ray with the text's bounding box first (half-depth `(R + (W/2 + 0.1) * sin(0.12) + 0.05) * k`). Pixels that miss it show only the background. Otherwise raymarch from the box entry (`MAX_STEPS = 96`, hit at `d < 0.001`).
- Normals: tetrahedral finite differences of `map`, `eps = 0.001`.

### 7.4 Letter shading
At a hit point `p` with normal `N`, view vector `V = -rd`, `NdotV = max(dot(N, V), 0.001)`:
1. **Fresnel (Schlick):** `fresnel = F0 + (1.0 - F0) * pow(1.0 - NdotV, 4.5)`.
2. **Thickness:** refract with the green IOR, `rdIn = refract(rd, N, 1.0 / 1.52)`, then march **inside** the glass (`d = -map(q)`, at most 48 steps) from `p - N * 0.01` until you leave it. `thickness` = distance travelled, divided by `k` (glyph units). Exit point `pe`, outward normal `Ne`.
3. **Dispersion through the glass:** for each channel `c` with its IOR: `dIn = refract(rd, N, 1.0 / ior_c)`; exit point ≈ `p + dIn * thickness * k`; `dOut = refract(dIn, -Ne, ior_c)`. On total internal reflection (`dOut == vec3(0)`), use `reflect(dIn, -Ne)` and stop there (no further bounces). If `dOut.z < -0.05`, intersect the liquid plane and take channel `c` of `liquidBackground` there. Otherwise take channel `c` of `sampleEnv(dOut, shift_c)`, with `shift_c = thickness * 1.2 + (0.22, 0.0, -0.22)`.
4. **Beer-Lambert:** multiply the refracted color by `exp(-absorptionCoeff * thickness * absorptionScale)` (the mark's own coefficients if it has its own material), and by `mix(1.0, 0.85, smoothstep(0.4, 1.0, thickness))`.
5. **Reflection and iridescence:** `R = reflect(rd, N)`, `sampleEnv(R, thickness * 1.2)`, tinted by `thinFilmPalette(NdotV * 2.4 + thickness * 1.6 - t * 0.15)` with the `65%` mix.
6. **Dual Blinn-Phong:** key and fill lights exactly as in `glsl-liquid-glass` (exponents `180` / `90`, intensities `3.8` / `1.4`, rim exponent `24`, intensity `0.45`).
7. `col = mix(refracted, reflected, fresnel) + rim + specular`.

### 7.5 Post-processing (glass pixels only)
Exposure `1.15`, ACES filmic tone mapping, gamma `1 / 2.2`, exactly as in `glsl-liquid-glass`. No vignette: the background must stay one flat color.

### 7.6 Readability check
The liquid colors inside the letters stand out on black and on light colors alike, and the contact shadow grounds them on light colors. If the chosen background is close to the liquid's own colors (deep blue, turquoise, violet), raise `shadowStrength` (up to `0.45`) and say that a more contrasting color would read better.

## 8. Output
- Save one complete, Shadertoy-compatible shader in the working directory, named after the text (e.g. `happy-birthday-chloe.glsl`). Never overwrite an existing file: add `-2`, `-3`….
- Start the file with a header comment giving the text, the lines, the mark edits, the background color and the main parameters.
- Always also the `NAME.html` live preview next to it (the script writes it), with the same name rule.
- In your reply: the summary table from section 2, the file path(s), how to change the background color (the `bgColor` line) and that double-clicking the `.html` plays it live and smoothly in a browser (with the picture in image mode), and anything you could not do as asked (e.g. a shape built as an approximation, or a mark the font cannot take).

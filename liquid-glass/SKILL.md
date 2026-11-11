---
name: liquid-glass
description: Single entry point for every glass GLSL shader, from words or an image. Picks the shape (animated liquid glass background via glsl-liquid-glass; 3D glass letters in any font or vibe via glsl-sdf-typography, with dots and accents replaced by shapes via glsl-sdf-shapes; a glass card, button or panel via glsl-glassmorphism) and the kind of glass (plain liquid, shard / broken glass, prism, crystal / gem), recognized automatically from the words or a reference image. Always delivers GLSL code. Understands the short syntax /liquid-glass 'happy birthday' letter i in birthday shape heart background purple glass crystal, as well as plain sentences. Use when the user runs /liquid-glass, or asks for any glass, liquid glass, glassmorphism, crystal, prism, gem, shard or broken glass shader, background, card, button, word, name, title or sentence, or shares an image of glass.
---

# /liquid-glass: one command, any glass

Two choices make every shader: the **shape** (section 1) and the **glass** (section 1b). The result is always **GLSL code**: one complete Shadertoy-compatible `mainImage` in a `.glsl` file, whatever the user gives (words, an image or a shader). An `.html` preview is extra, never a replacement.

## 1. Pick the shape (mode)

| The request contains… | Mode | Follow |
|---|---|---|
| No text to write and no card: `/liquid-glass` alone, "make a liquid glass shader", "a liquid glass background", a glass object | **Background** | the `glsl-liquid-glass` skill, exactly as written |
| Text to write: quoted text, words right after `/liquid-glass`, or "write …" | **Lettering** | the `glsl-sdf-typography` skill (and `glsl-sdf-shapes` for any shape) |
| `card`, button, panel, glassmorphism, UI glass | **Card** | the `glsl-glassmorphism` skill; `background COLOR` recolors its fluid backdrop |

## 1b. Pick the glass (material)

The user never has to name it: recognize it from the words or the image. Typing `glass TYPE` forces it.

| Glass | Words that point to it | What you see in a reference image | Rules |
|---|---|---|---|
| **shard** | broken, shattered, cracked, smashed, shard, fragment, splinter | A thin plate with a jagged outline; flat faces; thickness visible as thin bright edges | `materials/shard.md` |
| **prism** | prism, triangular or pyramid glass, rainbow through glass, light splitting, spectrum | A regular geometric solid; rainbow rays thrown around it | `materials/prism.md` |
| **crystal** | crystal, gem, diamond, jewel, quartz, cut glass, faceted, chandelier | Many facets, white sparkle | `materials/crystal.md` |
| **none** (plain liquid glass) | everything else | Smooth, flowing, organic forms | nothing to read |

- When two fit: broken + anything → **shard**; rainbow rays are the subject → **prism**; facets and sparkle are the subject → **crystal**. If still unclear, pick one and say so in one line.
- **With an image:** before coding, describe it in one sentence (*"Looks like a glass shard: flat faces, jagged outline, bright thin edges."*), then name the glass.
- Read only the one `materials/` file you need (next to this file). Write the shader with the mode's skill, then apply the material's rules before delivering. Where they disagree on physics, **the material wins**; shape, lights, background and pipeline always come from the mode's skill or the user's image.
- With the Background mode and a material, use `glsl-liquid-glass`'s `natural` mode, plus its `prism` or `broken` option for the shape.
- **Materials change values, never content.** They only set index, dispersion, Fresnel, absorption and thin-film. They may dim or turn off an existing light or reflection the reference image doesn't show; they never add or move lights, streaks, lines, outlines, glows or objects. If a look needs more, tell the user.
- Check by rendering at least two moments, compared with the reference image when there is one.
- Tell the user the glass you detected and why (one line), and a short table **setting | before | after | why**.

The `/shard`, `/prism` and `/crystal` shortcuts apply one material to a shader the user already has, saved as `<name>.<glass>.glsl` next to the original (the original stays unchanged).

In Lettering mode the text is cut out of one continuous liquid glass surface (the original deep iridescent colors on dark backgrounds, soft pastel glass on light ones): the liquid flows across all the letters as one material, and the background around them is one solid color (black unless the user picks another) or an image. If the user asks for the liquid all around the letters too, explain that the letters can no longer be read there and keep the solid color.

## 2. Short syntax

```
/liquid-glass 'TEXT' [letter X [in WORD] [OCCURRENCE] shape SHAPE [whole] [small|big|bigger] [COLOR] [melted]]... [vibe NAME | font NAME [bold|italic|weight N]] [background COLOR | image PATH [clear|liquid]] [tint COLOR] [rainbow] [3d] [lines N] [glass TYPE] [FINISH]
/liquid-glass card [background COLOR] [glass TYPE] [FINISH]
/liquid-glass [glass TYPE] [FINISH]
```

| Part | Meaning | Default |
|---|---|---|
| `'TEXT'` or `"TEXT"` | Text to write, exactly as typed (case, accents, punctuation). Without quotes: every word after `/liquid-glass` up to the first keyword. A `/` inside the text forces a line break. | required |
| `letter X` | Character whose dot or accent is replaced (see the marks table in `glsl-sdf-typography`) | none |
| `in WORD` | Only the occurrences of X inside that word | every word |
| `OCCURRENCE` | `first`, `second`, `third`, `last`, `all`, or a number | all occurrences |
| `shape SHAPE` | A shape from the `glsl-sdf-shapes` catalogue: circle, heart, star, sparkle, diamond, moon, full moon, flower, plus, butterfly, butterflies, cloud, crown, spade (ace of spades), club (trèfle). French names work too | required after `letter` |
| `whole` after the shape | The shape replaces the WHOLE letter, not just its dot ("a full moon instead of the o"): any letter works. Script `--replace "o=fullmoon"` | only the dot or accent |
| `small` / `big` / `bigger` after the shape | Shape size: ×0.7 / ×1.5 / ×2 (script `--mark "i=heart*2"`). An enlarged shape moves away from its letter to keep its gap. Fine calligraphy fonts (vibe `romantic`) have tiny dots: use `bigger` there by default | the size of the original dot, a little larger |
| `COLOR` after the shape | Colored glass for that shape only (e.g. `shape heart red`) | same glass as the letters |
| `melted` | Shape fused into the letter instead of floating above it | floating |
| `font NAME` | Any Google Fonts family (`font Pacifico`, `font 'Playfair Display' weight 800`), a font file path, or `font tubes` for hand-built neon tubes | `DM Serif Display` |
| `vibe NAME` | A mood that picks a font and its settings: `adventure` (bold), `cloud` (fluffy, soft), `medieval`, `romantic` (valentine), `cartoon` (old design), `dripping` (wet paint). The full list and aliases are in `glsl-sdf-typography` | none |
| `background COLOR` | Solid background: a color name (table below), `light`/`dark` + name, or a hex code `#RRGGBB` | black `#000000`, or the vibe's color |
| `image PATH` | The text sits on that picture, and the glass bends it. Also writes a `.html` that plays it live in a browser. `clear` = clear glass showing the picture, `liquid` = liquid letters only | liquid with a little of the picture |
| `tint COLOR` | Hue of the pastel glass (`tint pink`, `tint white` for almost clear glass) | the background's hue, softened |
| `rainbow` / `pastel` | `rainbow`: the original deep, iridescent liquid glass colors. `pastel`: soft pearly glass | rainbow on a dark background, pastel on a light one or on an image |
| `3d` | Each letter as a separate puffy 3D glass object (the older look) instead of one glass surface cut into the text | one surface |
| `lines N` | Number of lines | automatic |
| `glass TYPE` | `shard`, `prism` or `crystal` (section 1b). Optional: recognized automatically from the words or image | plain liquid glass |
| `FINISH` | `frost`, `polished`, `denser`, `lighter`, `transparent`, `translucent`: applied after generating, with that skill | none |

- Several `letter … shape …` groups can follow each other.
- Keywords may come in any order after the text, and French works too: `lettre`, `dans`, `forme`, `fond`, `lignes`, `police` (font), `gras` (bold), `italique`, `ambiance` / `style` (vibe), `image` / `photo`.
- A mood said in a sentence ("in a fairy-tale style", "something romantic") means `vibe`. An image attached to the message means `image`: save it to a file in the working directory first.
- Plain sentences mean the same thing: *"write happy birthday Chloe, replace the dot of the i of birthday by a star, purple background"*.
- If something cannot be read without guessing (two possible texts, an unknown keyword), ask one short question.

### Color names

| Name | Hex | Name | Hex |
|---|---|---|---|
| black | `#000000` | white | `#FFFFFF` |
| cream | `#F2EEE6` | light grey | `#D9D9DE` |
| dark grey | `#1E1E22` | navy | `#0B1430` |
| blue | `#2747A8` | light blue | `#BFD9F2` |
| purple | `#6B40A1` | lilac / lavender | `#C9B6E8` |
| pink | `#F2A7C3` | hot pink | `#E0408A` |
| red | `#B3202A` | orange | `#E8772E` |
| yellow | `#F2D04A` | green | `#2E8B57` |
| mint | `#BDECD6` | teal | `#1F7A7A` |

Any other name: choose a sensible hex and state it. `light X` / `dark X`: mix X 50% with white or black.

### Examples

| Command | Reading |
|---|---|
| `/liquid-glass` | Background mode |
| `/liquid-glass 'Mia'` | "Mia", black background |
| `/liquid-glass 'happy birthday' letter i in birthday shape heart background purple` | i of *birthday* → heart, purple `#6B40A1` |
| `/liquid-glass 'pixel jam' letter i shape star letter j shape diamond background cream` | i → star, j → diamond, cream |
| `/liquid-glass 'Bonjour / Chloé' lettre é forme lune fond #FDE2E4` | 2 lines, accent of é → moon, pale pink |
| `/liquid-glass 'Mia' letter i shape heart red frost` | red glass heart, then `/frost` |
| `/liquid-glass 'I love / Playful Design!' letter i in Design shape star letter ! shape heart font Pacifico background light purple` | script font Pacifico, i of *Design* → star, ! → heart, `#B5A0D0` |
| `/liquid-glass 'Be mine' letter i shape heart vibe valentine` | Lavishly Yours, i → heart, blush `#F6D5DC` |
| `/liquid-glass 'Summer!' letter ! shape heart vibe cloud image ~/Pictures/beach.jpg` | Rubik Bubbles on the photo, plus `summer.html` to watch it live |
| `/liquid-glass 'Mia' glass crystal` | "Mia" in cut-crystal glass, black background |
| `/liquid-glass card background lavender glass shard` | glassmorphism card on lavender, broken window glass |
| *"a glass prism throwing rainbows"* | Background mode, prism (detected) |

## 3. Before the code
Print the reading so the user can check it:

| Mode | Text | Lines | Mark edits | Font | Background | Glass |
|---|---|---|---|---|---|---|
| Lettering | `happy birthday` | 1 | `i` in *birthday* → heart (floating) | DM Serif Display | purple `#6B40A1` | none |
| Lettering | `Summer!` | 1 | `!` → heart | Rubik Bubbles (vibe *cloud*) | image `beach.jpg` | none |
| Card | — | — | — | — | lavender `#C9B6E8` | shard |

Then follow the skill for the mode, then the material. Name the file after the text (`happy-birthday.glsl`), `glass-card.glsl` in Card mode, or `liquid-glass.glsl` in Background mode. Never overwrite an existing file: add `-2`, `-3`… to the name. The `.glsl` file is always delivered; an `.html` preview only alongside it.

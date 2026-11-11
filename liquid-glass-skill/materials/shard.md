# Shard: real broken glass

This type **optimizes**, it does not create. It only changes how the glass that is already there reacts to light: physics values, plus a short description of the result to check against. Shape, lights, background and every element in the scene stay as they are (or as the user's image shows).

## How it should read (global description)
A piece of clear window glass. The flat faces are polished and almost invisible: you mostly see the background through them, slightly darker and slightly shifted. The glass shows itself mainly at its **broken edges**, where its thickness catches the light: bright where an edge faces the light, dim or dark elsewhere, uneven along its length. No rainbow, except perhaps a faint fringe on an edge.

## Physics (always apply)
| Setting | Value | Why |
|---|---|---|
| Index of refraction | about **1.52** (soda-lime window glass) | Real window glass |
| Fresnel | `F0 = 0.04`, exponent 5, or exact dielectric Fresnel | Glass reflects about 4% head-on, much more at grazing angles |
| Dispersion | physical: Abbe number about 58, `dispersionBoost = 1` (chips at most 1.5) | Window glass splits light only slightly, so the faces stay colorless |
| Thin-film mix | **0** | Broken glass has no coating |
| Absorption | very faint green-grey (iron in the glass), applied per distance travelled | Thin faces look clear; edges, seen through more glass, look slightly green |
| Edge light | comes from the existing lights reflecting and being trapped (total internal reflection) inside the edge thickness | That is why real edges glow unevenly |

## Do not add
- You **may** lower or turn off an existing light, reflection or line that the reference image doesn't show. You may never add or move one.
- No new lights, strips, streaks, glints or highlights that the shader or image doesn't already have.
- No lines, outlines or patterns painted on the faces.
- No new shapes, pieces or background changes.

If the result needs more light to read, say so to the user instead of adding it.

## Check before delivering
- The faces are clear and quiet; the edges carry most of the visible glass.
- No rainbow on the faces.
- If there is a reference image, the glass reacts to light like it does there.

Output, as all glass types: a new file `<name>.shard.glsl` next to the original, plus a table of **setting | before | after | why**.

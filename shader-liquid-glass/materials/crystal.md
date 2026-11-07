# Crystal: real cut crystal

This type **optimizes**, it does not create. It only changes how the glass that is already there reacts to light: physics values, plus a short description of the result to check against. Shape, lights, background and every element in the scene stay as they are (or as the user's image shows).

## How it should read (global description)
A clear, faceted solid that reads through **white sparkle**: crisp facet reflections and bright internal bounces. Color ("fire") appears only as **small, occasional flecks** that change as it turns; it never covers whole facets.

## Physics (always apply)
| Setting | Value | Why |
|---|---|---|
| Index of refraction | lead crystal about **1.55–1.60**; diamond 2.42 only if asked | Higher index means more internal reflection, more sparkle |
| Dispersion | physical: Abbe about 35–50 (crystal glass), 55 (diamond); `dispersionBoost` **1–1.5** | Exaggerated dispersion is what makes too many colors |
| Fresnel | exact dielectric Fresnel, total internal reflection, keep the internal bounces | The bounces make the sparkle |
| Thin-film mix | **0** | No coating |
| Absorption | near zero | Clear crystal |

## Do not add
- You **may** lower or turn off an existing light, reflection or line that the reference image doesn't show. You may never add or move one.
- No new lights, flares, stars, glints or floor caustics that the shader or image doesn't already have.
- No new shapes, objects or background changes.

If the crystal looks too dark, say so to the user instead of adding light.

## Check before delivering
- Mostly white, grey or clear; saturated color covers only a few percent, as flecks.
- If there is a reference image, the crystal reacts like it does there.

Output, as all glass types: a new file `<name>.crystal.glsl` next to the original, plus a table of **setting | before | after | why**.

# Prism: real optical glass

This type **optimizes**, it does not create. It only changes how the glass that is already there reacts to light: physics values, plus a short description of the result to check against. Shape, lights, background and every element in the scene stay as they are (or as the user's image shows).

## How it should read (global description)
A clear, colorless solid with crisp edges. The prism itself is not rainbow-colored: the color appears **where the split light lands**, as a spectrum on the surfaces around it, starting from where light leaves the prism. On the body, color shows only as small sparks at steep exits and edges.

## Physics (always apply)
| Setting | Value | Why |
|---|---|---|
| Index of refraction | per wavelength (Sellmeier or Cauchy): crown glass about 1.52, flint about 1.62 | Real optical glass |
| Dispersion | physical: Abbe about 64 (crown) or 36 (flint); `dispersionBoost` **1–1.5** | Exaggerated dispersion tints the whole body |
| Fresnel | exact dielectric Fresnel, total internal reflection | Gives the crisp, bright edges and internal reflections |
| Thin-film mix | **0** | A prism has no coating |
| Absorption | near zero | Optical glass is clear |
| Spectrum outside | if the shader already draws a caustic, it must come from the dispersion inside the prism and start at the prism | The rainbow is a consequence of the glass, not a separate effect |

## Do not add
- You **may** lower or turn off an existing light, reflection or line that the reference image doesn't show. You may never add or move one.
- No new lights, rays, god rays, bloom or painted rainbows that the shader or image doesn't already have.
- No new shapes, objects or background changes.

If the spectrum is too faint to read, say so to the user instead of adding an effect.

## Check before delivering
- The body is mostly clear; color on it is limited to small sparks.
- Any spectrum is connected to the prism.
- If there is a reference image, the glass reacts like it does there.

Output, as all glass types: a new file `<name>.prism.glsl` next to the original, plus a table of **setting | before | after | why**.

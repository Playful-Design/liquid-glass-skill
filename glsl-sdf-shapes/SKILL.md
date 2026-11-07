---
name: glsl-sdf-shapes
description: Generates perfect 3D mathematical shapes (Heart, Diamond, Star, Spades, Clubs, etc.) in GLSL using SDFs. Can be used standalone or integrated into typography.
---

# GLSL SDF Shapes Builder

## 1. Role and Expected Behavior
You are a GLSL SDF expert specializing in mathematical shapes. When the user requests a classic design shape (e.g., Heart, Star, Diamond, Spade, Club), you must generate the exact mathematical 2D SDF for this shape, and extrude it into 3D.

## 2. Geometry: Exact Mathematical SDFs
Do NOT approximate shapes with messy combinations if an analytical formula exists (use Inigo Quilez standards).

- **Heart:** Use the exact analytical 2D heart SDF (using `atan2` or cubic/quadratic equations).
- **Star:** Use the exact 2D star SDF with angles and `cos`/`sin` parameters.
- **Diamond / Card Suits:** Use symmetric combinations of smooth geometric primitives, `smin`, or specific polygon SDFs to create perfect vector-like 2D shapes.

Scale the 2D SDF appropriately so it naturally fits within a `[-1.0, 1.0]` coordinate space.

```glsl
// Example structure for a custom shape
float sdfStar(vec2 p, float r, int n, float m) {
    // ... exact mathematical star SDF ...
    return d;
}
```

## 3. Shape Catalogue
Match the user's words (in any language) to these shapes. Centre each shape's visual bounding box on the origin and make it fit `[-1, 1]`.

**Ready in `shapes.glsl`** (the typography script uses these names directly; preview of all of them: `previews/shapes-catalogue.png` in the project):

| Name | Words users may use |
|---|---|
| `circle` | dot, round, bubble, rond |
| `heart` | heart, love, cœur, ♥ |
| `star` | star, étoile |
| `sparkle` | sparkle, twinkle, shine, étincelle, ✦ |
| `diamond` | diamond, rhombus, losange, carreau, ♦ |
| `moon` | moon, crescent, croissant de lune, lune |
| `fullmoon` | full moon, pleine lune |
| `flower` | flower, fleur |
| `plus` | plus, cross, croix |
| `butterfly` | butterfly, papillon |
| `butterflies` | butterflies, papillons (two butterflies) |
| `cloud` | cloud, nuage |
| `crown` | crown, couronne |
| `spade` | spade, ace of spades, pique, as de pique, ♠ |
| `club` | club, clover, trèfle, ♣ |

**Other shapes** (build them as below, then add them to `shapes.glsl`):

| Shape | Words users may use | Build |
|---|---|---|
| Circle | dot, round, bubble, rond | exact: `length(p) - r` |
| Heart | heart, love, cœur, ♥ | exact IQ `sdHeart`, recentred |
| Star | star, étoile (5 points by default), n-point star | exact IQ `sdStar5` / `sdStar` |
| Sparkle | sparkle, twinkle, étincelle | exact IQ `sdStar`, 4 points, sharp |
| Diamond | diamond, rhombus, losange, ♦ | exact IQ `sdRhombus` |
| Crescent moon | moon, crescent, lune | exact IQ `sdMoon` |
| Plus / cross | plus, cross, croix | exact IQ `sdCross` |
| X | x, kiss, saltire | exact IQ `sdRoundedX` |
| Triangle | triangle | exact IQ `sdEquilateralTriangle` |
| Polygons | pentagon, hexagon, octagon | exact IQ `sdPentagon` / `sdHexagon` / `sdOctogon` |
| Ring | ring, donut, anneau | exact: `abs(length(p) - r) - t` |
| Drop | drop, teardrop, goutte | circle + isosceles triangle (IQ `sdTriangleIsosceles`), `smin` |
| Leaf / petal | leaf, petal, eye, feuille | exact IQ `sdVesica` |
| Flower | flower, fleur | 5 or 6 circles around a centre circle, `min` |
| Lightning bolt | lightning, bolt, éclair | exact IQ `sdPolygon`, about 6 vertices |
| Arrow | arrow, flèche | exact IQ `sdPolygon` |

Any other outline (house, bow, crown variants…): use `sdPolygon` if it is polygonal (exact), otherwise compose the primitives above and tell the user it is a composed approximation.

## 4. Integration with Typography (Custom Dots)
If this shape is being called by the `glsl-sdf-typography` skill to replace a dot or accent, output ONLY the 2D SDF function. The typography skill will handle the scaling, translation, and 3D extrusion.

`shapes.glsl` (next to this file) is the ready-made library the typography script uses: `circle heart star sparkle diamond moon flower plus`. To make a new shape available to the script, add it there as a block starting with `// @shape <name>` and ending with `// @end`, defining `float sdf<Name>(vec2 p)`, centred on the origin and fitting `[-1, 1]`. Give any helper function a name unique to that block.

## 5. Standalone 3D Extrusion
If the shape is requested as a standalone object (e.g., "Generate a 3D Heart"), extrude it into a thick 3D object with a smooth bevel to catch specular highlights beautifully.

```glsl
// Inside map(vec3 pos)
float d2d = sdfRequestedShape(pos.xy);
float depth = 0.3; // Thickness of the glass/solid shape
float bevel = 0.08; // Smooth rounded edges
    
float d3d = length(max(vec2(d2d, abs(pos.z) - depth), 0.0)) + min(max(d2d, abs(pos.z) - depth), 0.0) - bevel;
```

## 6. Rendering Setup (If Standalone)
If rendering as a standalone object to verify geometry:
- Implement a standard Raymarching loop.
- Compute surface normals `N` via finite differences (`eps = 0.001`).
- Center the object. You may add a slow rotation on the Y/X axis (`pos.xz *= rot(iTime);`) to showcase the 3D volume.
---
name: liquid-glass
description: Create liquid glass GLSL shaders for animated backgrounds, lettering, logos, and UI surfaces, including clear, frosted, iridescent, prism, crystal, and broken glass finishes. Use for glass shader requests or a glass reference image; deliver executable GLSL with an optional browser preview.
---

# Shader Liquid Glass

Read [liquid-glass/SKILL.md](liquid-glass/SKILL.md) for the entry workflow, prompt syntax, shape selection and material selection. The installed folder includes the supporting skills below; read their files directly rather than requiring separate installations.

- **Background or glass object:** [glsl-liquid-glass/SKILL.md](glsl-liquid-glass/SKILL.md).
- **Lettering in a font:** [glsl-sdf-typography/SKILL.md](glsl-sdf-typography/SKILL.md), plus [glsl-sdf-shapes/SKILL.md](glsl-sdf-shapes/SKILL.md) for replacement dots or shapes.
- **Card, button or panel:** [glsl-glassmorphism/SKILL.md](glsl-glassmorphism/SKILL.md).
- **A finish:** read the relevant file under `glsl-glass-appearance/`; for frosted or satin glass use [glsl-glass-appearance/frost/SKILL.md](glsl-glass-appearance/frost/SKILL.md).
- **A special material:** read the matching file under `liquid-glass/materials/`.

When adapting an existing logo, preserve its exact supplied geometry. Select the optical material from the prompt and reference rather than replacing the mark with a different font or shape.

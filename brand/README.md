# Fri typography

Inter 4.1 is Fri's single brand family. Font files are bundled locally; the app never requests a font CDN.

| Role | Weight | Size |
| --- | --- | --- |
| Web display | 600 | Fluid, 48–152 px |
| Section headline | 600 | Fluid, 34–59 px |
| App page title | 600 | 28–34 px |
| Card title | 600 | 16–18 px |
| Body / fields | 400 | 16–17 px |
| Button / navigation | 600 | 14–16 px |
| Essential metadata | 400 | 13–14 px |

Use sentence case. No decorative subtitle, eyebrow, tagline inside functional screens, or duplicate action. Keep event metadata, validation, permission scope and billing facts. Place those facts at the relevant decision rather than beneath every heading.

Web and Electron use the variable WOFF2. React Native embeds static 400/600/700 weights. Android system widgets use the launcher's supported sans family with matching hierarchy; Glance does not support arbitrary bundled fonts. Native pickers and system menus keep platform typography.

Source: https://rsms.me/inter/ · https://github.com/rsms/inter/releases/tag/v4.1
License: SIL Open Font License, included in fonts/LICENSE.txt. Static weights were instantiated from the official variable TTF at optical size 14 with fontTools.

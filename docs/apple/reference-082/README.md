# 0.8.2 visual reference

These are unmodified synthetic browser captures from the Windows verification session, not macOS/iOS screenshots. They demonstrate the approved palette, font, opaque time sheet, selected wheel band and one Confirm action. Native window chrome and platform accessibility controls may differ.

- [Light, narrow viewport](time-picker-mobile.png)
- [Dark, desktop viewport](time-picker-dark.png)

Use `FRI-liquid-glass.html` for the complete runnable reference, `preview/keyboard.test.cjs` to reproduce the interactions, and `apple/Handoff/design-tokens.json` for exact colors/type/geometry. The capture's backdrop transparency is a browser simulation; native macOS must retain its existing AppKit backdrop.

No user calendar or authenticated source is shown. Native acceptance screenshots must be captured again after implementing the port.

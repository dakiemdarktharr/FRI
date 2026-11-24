# Import feedback runtime evidence

Unmodified full-screen XCTest captures from isolated Simulator stores:

- [iPad normal text](ipad-feedback.png): error remains visible under the scrolling form, with Details and Dismiss.
- [iPhone larger text, landscape](iphone-landscape-large-text.png): complete error and both controls fit below the navigation bar.
- [iPhone larger text, portrait](iphone-portrait-large-text.png): same feedback after rotating back.
- [iPad larger text, landscape](ipad-landscape-large-text.png): feedback and controls fit in the presented sheet after rotation.

The tests additionally exercise Details, dismissal without clearing the source, two-message duplicate feedback, correction of a missing date, save and relaunch persistence. The parent readiness ledger lists the exact result bundles and remaining limits. These are Simulator captures, not Mac, physical-device, VoiceOver or release-signing evidence.

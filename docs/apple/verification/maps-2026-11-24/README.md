# Maps runtime verification

[Original iPhone Simulator screenshot](iphone-map.png), reviewed at full size: the New York query, full MapKit preview and Saved place label are visible. No image retouching or response stub.

Final `testMapsSearchDraftPersistenceAndDisconnect`: **PASS**, one test, zero failures/skips, 66.844 seconds body, iPhone 18 Pro / iOS 27.2 Simulator. Bundle `test_sim_2026-11-24T00-17-15-411Z_pid22065_21c31ca5.xcresult`. Run with `FRI_MAPS_NETWORK_TEST=1`; uses a unique synthetic store.

Checks blank-query disabling, keyboard Search, New York map visibility, unsubmitted edit retaining the saved place, a successful Tokyo replacement, relaunch persistence, Disconnect and empty state after another relaunch. The test scrolls actual form controls and the map into view. It does not inject or guarantee in-flight cancellation or delayed responses.

The same iPad flow is **INCOMPLETE**, with lazy-row/scroll diagnostics followed by repeated XCTest animation-idle waits, including after restarting only the QA iPad without erasing data. Canceled result bundles and remaining gaps are documented in the [readiness ledger](../PRODUCTION-READINESS.md). Mac compilation passed; fresh Mac onscreen verification is pending because Computer Use returns cgWindowNotFound. These are not release or complete visual-parity results.

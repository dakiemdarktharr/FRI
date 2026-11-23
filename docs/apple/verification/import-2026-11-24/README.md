# Public calendar review captures

Unmodified full-screen XCTest captures from the native iOS app, using isolated synthetic stores and a real public HTTPS request. No physical device was accessed.

- [iPhone review](iphone-review.png): persistent Name, Time (HH:mm), Duration in minutes and other labels, with the source event converted to 20:00 local time and a 60-minute duration.
- [iPad review](ipad-review.png): scrolled lower form, showing duration/category/location/notes labels and reachable Add to drafts/Skip controls. The upper time field is partially behind the navigation bar at this scroll position; this capture does not claim all fields fit simultaneously.

Source: [pinned ical.js minimal.ics](https://github.com/kewisch/ical.js/blob/4b28e296c6f2e9742fcde82fd2cde39b9ad382da/samples/minimal.ics). Result bundles and limitations are in the parent production-readiness ledger. These images do not establish full desktop visual equivalence or Mac runtime behavior.

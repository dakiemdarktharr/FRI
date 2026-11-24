# Ocean footage

Ocean source: **Waves Breaking at the Beach Shore**, Maor Attias, Pexels video 5193615.

- Source: https://www.pexels.com/video/waves-breaking-at-the-beach-shore-5193615/
- License: https://www.pexels.com/license/ (checked 2026-11-23; free use and modification, including websites).
- FRI transformation: cropped to 16:9, speed 1.18×, 0.8-second loop dissolve, H.264 1280×720 at 30 fps, no audio; a WebGL shader converts every displayed frame to Ink/Cloud halftone.
- The poster is a rendered frame of the same transformed video. No endorsement by the creator is implied.

The earlier generated ocean photograph remains in source history, but is not used by this revision. The pole-f SVG is original project artwork.

## Desktop widget walkthrough

widget-walkthrough.mp4 captures the actual FRI 0.7.0 Electron window and widget with synthetic appointments. Its window frames are presented on a neutral virtual desktop to avoid recording or interrupting the user's desktop. Creation uses the native selection overlay; movement/resizing updates the native widget bounds; Done and removal use its actual controls. No account data, user desktop content or audio is included. This video demonstrates Fri UI behavior, not Explorer icon reflow. The latter is covered separately by the desktop integration checks.

Regenerate with `node website/capture-widget-demo.cjs` after building the Windows app. The capture helper uses isolated local data and hidden windows. `widget-poster.jpg` is a frame from that recording.

The widget walkthrough is also supplied as VP9 WebM, with H.264 MP4 as a fallback.

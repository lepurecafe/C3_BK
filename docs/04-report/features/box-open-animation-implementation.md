# Box Open Animation Implementation

Last updated: 2026-05-21
Feature: box-open-animation
Status: Implemented, build-verified, device verification required

---

## 1. What Changed

`BoxVolumeView` now treats the travel case as an interactive object.

Implemented behavior:

1. Load `TravelCaseScene` through `Entity(named:in:)`.
2. Scale the entity to fit inside the volumetric window.
3. Add `InputTargetComponent` to the entity hierarchy.
4. Generate collision shapes so the entity can receive targeted tap gestures.
5. Store the loaded entity and first available animation in `@State`.
6. Tap the box to play the open animation.
7. Tap again to close the box by manually scrubbing the same animation backward.
8. Ignore additional taps while an animation is already running.

---

## 2. Asset Evidence

The current `1890s_Travel_Case.usdz` contains an embedded skeletal animation:

```text
SkelAnimation "Open"
startTimeCode = 2
endTimeCode = 400
timeCodesPerSecond = 120
```

This means the asset already has an opening motion. The app code only needed to expose tap input and drive that animation.

---

## 3. Implementation Notes

Target file:

```text
DesktopOrganizer/Views/BoxVolumeView.swift
```

Important state:

```swift
@State private var boxEntity: Entity?
@State private var openAnimation: AnimationResource?
@State private var animationController: AnimationPlaybackController?
@State private var isOpen = false
@State private var isAnimating = false
```

Tap handling:

```swift
TapGesture()
    .targetedToAnyEntity()
    .onEnded { _ in
        toggleBoxOpenState()
    }
```

Animation policy:

- closed -> open: `speed = 1`, `time = 0`
- open -> closed: manually step `time` from `duration` to `0`
- while animating: ignore tap

Why close uses manual time scrubbing:

- Device testing showed that `speed = -1` did not reliably reverse imported skeletal animation playback.
- The second tap replayed the opening animation from the beginning instead.
- Manual time scrubbing keeps the imported `Open` animation asset, but drives the controller's `time` backward frame by frame.

---

## 4. Remaining Device Checks

This implementation builds, but the real interaction must be checked on Vision Pro.

- [ ] The box receives gaze + pinch tap input.
- [ ] Tap does not conflict with drag rotation.
- [ ] First tap opens the case.
- [ ] Second tap closes the case by visibly reversing the opening motion.
- [ ] Animation starts and ends at clean poses.
- [ ] Repeated fast taps do not break the state.
- [ ] Collision shape feels large enough to select the object comfortably.

If manual scrubbing is visually uneven on device, create or export a separate `Close` animation from the asset pipeline and play that instead.

---

## 5. Product Intent Note

Box opening is not meant to be a general "ready to receive memo" state indicator.

The intended uses are:

1. **Memo insertion performance**
   - Drag a memo toward the box.
   - When the memo touches the box, the box opens.
   - When the user releases the memo, the memo disappears into the box.
   - The box then closes.

2. **Memo lookup performance**
   - Click a box that already contains memos.
   - The box opens.
   - A window-like memo list appears above the box.
   - The box can close again after lookup.

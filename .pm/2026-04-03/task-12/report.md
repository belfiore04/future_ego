# Task 12 Report: CallingOverlay -> fullScreenCover

## Status: Done

## Changes

### ContentView.swift
- Removed the `ZStack` wrapper around `TabView` + `CallingOverlay`
- Removed the `if isCalling { CallingOverlay ... }` block and its `.transition(.opacity)`
- Removed `.animation(.easeInOut(duration: 0.35), value: isCalling)`
- Added `.fullScreenCover(isPresented: $isCalling)` on the `TabView` with `CallingOverlay { isCalling = false }` as content
- Simplified `onStartCalling` callback: plain `isCalling = true` without `withAnimation` wrapper

### CallingOverlay.swift
- Removed `@State private var overlayVisible` (no longer needed -- fullScreenCover handles presentation)
- Replaced manual background (Rectangle + .ultraThinMaterial + Color.black.opacity) with `Color.black.ignoresSafeArea()`
- Removed `.opacity(overlayVisible ? 1 : 0)` from the body
- Simplified `startCall()`: removed the `overlayVisible` fade-in animation, kept only the AI greeting after 1s delay
- Simplified hang-up button: calls `onHangUp()` directly, removed `DispatchQueue.main.asyncAfter` delay and `overlayVisible = false` fade-out

### CurrentTabView.swift
- No changes needed. The `onStartCalling` callback works as-is.

## What this achieves
- Uses iOS native `.fullScreenCover()` for modal presentation, which provides built-in slide-up/slide-down transitions
- No manual animation state management for showing/hiding the overlay
- TabBar is automatically hidden when fullScreenCover is presented
- Cleaner separation of concerns: CallingOverlay no longer manages its own visibility

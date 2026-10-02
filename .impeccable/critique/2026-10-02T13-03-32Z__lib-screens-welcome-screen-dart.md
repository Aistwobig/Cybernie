---
target: the Welcome screen
total_score: 22
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 3
target_identity: "file:D:\\APPDEV\\Cybernie\\lib\\screens\\welcome_screen.dart"
target_fingerprint: "sha256:a9bd33cf7a2d5e0088c0c683a080e2fecd74b8416111423aa68bda95140e9a82"
target_path: "D:\\APPDEV\\Cybernie\\lib\\screens\\welcome_screen.dart"
timestamp: 2026-10-02T13-03-32Z
slug: lib-screens-welcome-screen-dart
---
Method: dual-agent (A: design review, B: detector + deterministic measurements)

## Design Health Score
| # | Heuristic | Score | Key Issue |
|---|---|---|---|
| 1 | Visibility of System Status | 2 | "Player" flashes before the real name; blank sprite while loading; no presence/room status |
| 2 | Match System / Real World | 3 | "CHARACTER PREVIEW" is UI jargon; hamburger implies a menu but holds only Sign out |
| 3 | User Control and Freedom | 3 | Clean back/tab behaviour; one-tap sign out (recoverable) |
| 4 | Consistency and Standards | 2 | Three different bottom navs; Welcome uses pushNamed not AppNav; preview ignores chosen character |
| 5 | Error Prevention | 3 | Few destructive actions |
| 6 | Recognition Rather Than Recall | 3 | Labelled nav; Sign out hidden behind generic icon |
| 7 | Flexibility and Efficiency | 1 | JOIN ROOM -> one-room picker -> second JOIN |
| 8 | Aesthetic and Minimalist Design | 3 | Restrained; ~130px dead space around frame; label adds noise |
| 9 | Error Recovery | 1 | Profile load errors swallowed; sprite load failure leaves empty frame |
| 10 | Help and Documentation | 1 | No first-timer guidance on rooms/friends |
| Total | | 22/40 | Acceptable |

## Design Specificity Verdict
Half authored, half template: parchment/ink, Cinzel, notched dividers, corner brackets and the crisp walking sprite read as fantasy manuscript, but nothing reads tavern, cozy or social. No people on Home. Skeleton is a stock game-lobby (greeting, hero, CTA, 3-tab nav).
Deterministic scan: impeccable detect returned [] (exit 0) because it does not parse Dart/Flutter (verified working on a CSS fixture). Manual measurements: all tap targets >= 48dp; contrast failures: CHARACTER PREVIEW label ink@0.5 = 3.29:1 at 11px (line 86); inactive nav label ink@0.4 = 2.47:1 at 10px (291/306); inactive nav icon 2.47:1 (<3:1 non-text). Inter used for all UI labels (82,126,186,302) - detector's overused-font rule would fire on web.
Visual overlays: none (no browser automation; Flutter canvas).

## Priority Issues
- [P1] Character Preview hard-codes menanim.png (welcome_screen.dart:268), ignores Profile characterIndex; frame not tappable. Fix: relabel "YOUR ADVENTURER", show chosen name, tap -> Profile; load characterIndex once sheets exist. Commands: clarify, onboard.
- [P1] Home has no social presence; JOIN ROOM adds a one-room picker step. Fix: "ENTER BERNIE'S TAVERN · N / 20 inside" straight to /rooms/tavern; "Friends here now" avatar row / "Find friends ->". Commands: layout, bolder.
- [P1] Accessibility: contrast failures above; no Semantics on nav (selected), sprite (image label), greeting (header); sprite Timer ignores reduce-motion and runs offstage. Fix: solid muted ink ~#5E574C at >=12px; Semantics wrappers; static frame when disableAnimations; Ticker/AnimationController. Commands: audit, harden.
- [P2] Loading/error states: "Player" flash, blank sprite, unhandled sprite decode failure. Fix: seed name from auth metadata; fade-in; try/catch fallback to static image. Command: harden.
- [P2] Bottom nav built three ways (heights 60/58, label 10/9px, inactive alpha 0.4/0.5, different top edges; Welcome not on AppNav). Fix: shared CybernieBottomNav widget via AppNav. Command: polish.

## Persona Red Flags
Jordan: unclear "preview", JOIN ROOM gives no context, hamburger holds only Sign out, no path to friends when friendless.
Casey: perpetual animation competes; friend status two taps away; blank sprite on slow networks.
Sam: sprite invisible to screen readers; tabs announce no selection; greeting not a heading; contrast failures; default purple focus colour (app_theme.dart:16); 200% text nearly overflows fixed 60px nav; non-scrolling Column can overflow in landscape.

## Minor Observations
Long names truncate on the name (~12 chars); non-integer 0.82 sprite scale shimmers; corner brackets too faint (8px @45%); mixed radii vs pixel art; JOIN text pure white; AppImages.characterMen -> missing men.png; Sign out has no icon/confirm; re-tapping Home does nothing.

## Questions to Consider
- Should Home be a doorway into the tavern (live dimmed peek + who's inside) instead of a mirror?
- Why menu -> picker -> second JOIN instead of one tap into the tavern?
- Where is the cozy? Would one warm accent (candle amber) earn its place?

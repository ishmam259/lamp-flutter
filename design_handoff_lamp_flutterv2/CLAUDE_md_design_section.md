## Design system (authoritative — read before touching any UI)

Rules: `docs/DESIGN_SYSTEM.md`. Enforced by `test/design_lint_test.dart`.

- Colour only via `context.lamp.*` (`lib/core/constants/palette.dart`). The brand colour is near-white in dark themes and `#0B5D42` in light themes. Mint `#3DDC97` = `verified` only. There are three states (confirmed/pending/refused) and no chain blue.
- Type only via `LaMPType.*` (`typography.dart`): Anek Latin/Bangla sans + IBM Plex Mono for money, ids and labels. Weights 400/500/600, minimum size 11.
- Spacing is `Gap.*`, radii are `LaMPRadius.*`, and icons are `IconSize.*`.
- Seat chrome: `LampSeatTitle` + `LampBlockPip` (`lib/widgets/ui/lamp_ledger_ui.dart`). Ledger writes use `LampReceiptCard`, counts use `LampTickBar`, and state uses `LampStateDot`.
- Logo: `LampMark` (brightness-aware assets `logo-mark-dark/light/white.png`).
- A new screen follows the checklist in `docs/DESIGN_SYSTEM.md` §6.

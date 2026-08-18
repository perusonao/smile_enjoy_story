# UI image assets

Character/event/location crops taken from a user-provided S.E.S. UI
material design composite image (17 assets total: 8 characters, 5
events, 4 locations). Text labels, buttons, badges, gauges and icon sets
were intentionally not cropped — these are portrait/scene art only.

Reference these via `lib/ui/asset_paths.dart`'s `AssetPaths` constants,
not by writing the path strings out at call sites.

As of this import, nothing in the app renders these images yet — no
event modal, no character/location wiring into `Applicant`/`Engineer`,
no `portraitId` persistence. That wiring is planned for later PRs; this
import only makes the files loadable Flutter assets.

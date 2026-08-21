---
id: SES-UI-002
title: Dialog image headers must be clipped to the Dialog's actual shape
scope: project
category: flutter-ui
status: candidate-pattern
confidence: medium
observations: 1
last_verified: 2026-08-19
---

## Problem / Context

An image header can visually escape rounded Dialog geometry if it is not
clipped by the final Dialog shape.

## Evidence

`8df0d3d` changed only `lib/ui/widgets/founding_dialogs.dart` to clip the
image header to the Dialog's actual shape.

## Decision / Pattern

When adding media to `AlertDialog`/Dialog content, verify the rendered shape
and clip at the geometry owner rather than assuming child layout constrains it.

## When to use

Image-bearing dialogs, rounded modal surfaces, and responsive aspect layouts.

## When NOT to use

Do not add `IntrinsicWidth` or force `AspectRatio` merely to solve clipping;
choose constraints from the actual design and verify on target sizes.

## Related files

`lib/ui/widgets/founding_dialogs.dart`.

## Related PR/commit

`8df0d3d` (PR #24 review response).

## Regression protection

Widget/render screenshot test when this dialog layout is edited again.

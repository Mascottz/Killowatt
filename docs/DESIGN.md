# Design notes

How killowatt should look and sound, so it never drifts back into generic saas.

## Mood

Calm. this is a tool that watches money burn, so it should feel like the opposite of fire; quiet, certain, unhurried. nothing flashes, nothing bounces. motion is short and eased, or it does not exist.

## Palette

Deep spruce ground, copper for intent, bone for words. no pure black, no pure white, no indigo, no startup blue.

| name | hex | use |
| --- | --- | --- |
| spruce | `#0D1A15` | page ground |
| panel | `#13221C` | surfaces |
| panel raised | `#182A22` | hover, raised surfaces |
| hairline | `#24382E` | borders, dividers |
| bone | `#ECE7DB` | primary text |
| moss | `#9FB6A7` | secondary text |
| copper | `#C98E5F` | intent, accents, the wordmark spark |
| copper bright | `#E3AE7C` | emphasis |
| ember | `#E2794F` | trip state only; if ember is on screen, something tripped |

The rule that keeps it calm; ember appears nowhere in the resting ui. a calm screen is spruce, copper, bone. ember is reserved for the one moment that matters.

## The mark

The trace k. the initial routed like a pcb trace; a vertical stem, two arms bent at exactly 45 degrees, terminal pads at every open end, and a ring node where the arms meet the stem. copper hairlines on spruce, always; no fills where a line will do.

Weight scales with size; at favicon sizes the joint node drops out and the strokes and pads go heavier so it stays legible at 16px. source files live in `logo/`; `mark.svg`, `mark-16.svg`, `lockup.svg`. the studies that lost were retired from the tree when the trace k won; they live on in git history, in the commit that added them.

## Shape language

Rectangles with four matching corners are banned. every surface carries one 45 degree cut or one oversized radius, and all cuts share the same angle so the family stays coherent.

- Breaker seal; a squircle, the one shape with no corners at all
- Primary cards; opposite corners cut at 45 degrees, like pcb pads
- Secondary cards; petal radii, large on opposite corners, tight on the others
- Corner cards; a single folded corner cut, like a ticket
- Tags and statuses; hex cuts on both ends instead of pills
- Primary button; full capsule on the leading edge, squared on the trailing edge

One shape vocabulary, different silhouettes per section. nothing repeats its neighbor exactly.

## Type

Restrained, bookish, slightly old fashioned.

- Display and headings; iowan old style → palatino → georgia; normal weight, let the size and spacing do the work
- Labels; small caps in a quiet sans, letterspaced wide
- Numbers and logs; the platform mono, tabular where possible

## Punctuation

No em dashes anywhere, in ui copy, docs, or commit messages. use a ; or a , or an arrow → where a break is needed. a plain hyphen only survives in hyphenated words like hard-stop.

## Motion

- 150 To 250ms, ease-out
- Fade and rise of 6 to 10px for sections on load
- Counters tick, they do not jump
- The trip is the only state change allowed to feel dramatic; ring goes ember, seal flips to open

# design notes

how killowatt should look and sound, so it never drifts back into generic saas.

## mood

calm. this is a tool that watches money burn, so it should feel like the opposite of fire; quiet, certain, unhurried. nothing flashes, nothing bounces. motion is short and eased, or it does not exist.

## palette

deep spruce ground, copper for intent, bone for words. no pure black, no pure white, no indigo, no startup blue.

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

the rule that keeps it calm; ember appears nowhere in the resting ui. a calm screen is spruce, copper, bone. ember is reserved for the one moment that matters.

## the mark

the trace k. the initial routed like a pcb trace; a vertical stem, two arms bent at exactly 45 degrees, terminal pads at every open end, and a ring node where the arms meet the stem. copper hairlines on spruce, always; no fills where a line will do.

weight scales with size; at favicon sizes the joint node drops out and the strokes and pads go heavier so it stays legible at 16px. source files live in `logo/`; `mark.svg`, `mark-16.svg`, `lockup.svg`, with the studies that lost in `gallery.html`.

## shape language

rectangles with four matching corners are banned. every surface carries one 45 degree cut or one oversized radius, and all cuts share the same angle so the family stays coherent.

- breaker seal; a squircle, the one shape with no corners at all
- primary cards; opposite corners cut at 45 degrees, like pcb pads
- secondary cards; petal radii, large on opposite corners, tight on the others
- corner cards; a single folded corner cut, like a ticket
- tags and statuses; hex cuts on both ends instead of pills
- primary button; full capsule on the leading edge, squared on the trailing edge

one shape vocabulary, different silhouettes per section. nothing repeats its neighbor exactly.

## type

restrained, bookish, slightly old fashioned.

- display and headings; iowan old style → palatino → georgia; normal weight, let the size and spacing do the work
- labels; small caps in a quiet sans, letterspaced wide
- numbers and logs; the platform mono, tabular where possible

## punctuation

no em dashes anywhere, in ui copy, docs, or commit messages. use a ; or a , or an arrow → where a break is needed. a plain hyphen only survives in hyphenated words like hard-stop.

## motion

- 150 to 250ms, ease-out
- fade and rise of 6 to 10px for sections on load
- counters tick, they do not jump
- the trip is the only state change allowed to feel dramatic; ring goes ember, seal flips to open

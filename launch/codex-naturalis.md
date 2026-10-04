# Kickoff prompt; Codex Naturalis

Paste this entire message into a fresh session, then paste a github token when asked.

---

Build me **Codex Naturalis**; the advanced mathematics of everything that makes up the earth, the galaxies, nature, and the world, hosted as a static site on vercel under the Mascottz account. mathematicians get the real thing and an arena; everyone else gets to see the beauty of the world through mathematics. every formula carries its originator, referenced and praised with a small human card.

## Shape of the site; few pages, no formula dumps

Not a multi-page site with a dedicated page per formula and piles of worked examples. the book is one long calm page; deep-linkable anchors, never pagination churn. worked solutions belong to the problems arena, not to the entries.

1. `index.html` — the book. landing with galileo's line as the spine; the book of nature is written in mathematics; then the five domains in order; the sky, the earth, the living, the invisible, the structure. all twenty-four entries live here as interactive pieces with sliders.
2. `problems.html` — the arena. the top 200 open problems in the world for mathematicians to attempt, with a public ledger of names.
3. `humans.html` — the hall of originators. every human card from the entries, filterable by era and region, so the attribution justice is visible as one wall.
4. `contributing.md` and the data files — the ladder everyone climbs.

## The stack; polyglot like killowatt, static at the end

The deployed site is static and zero-dependency, but the repo is not vanilla; every language earns its place the way it did in killowatt.

| language | role |
|---|---|
| Cue | the data language. every entry, every problem, every ledger attempt is cue data against cue schemas; validated, typed, honest. |
| Julia | the math engine. a makefile runs julia scripts that compute the real numbers; the phyllotaxis points, the lorenz trajectory, the fourier coefficients, the orbit steps, and writes the json the page renders. the numbers on screen are computed by the language of technical computing, never typed by hand. |
| Rust | the arena's referee. one small cli that validates the ledger and the problems list against their schemas; the ci gate is this binary. |
| Html, css, js | rendering only. zero dependencies, no framework, no cdn fetches at runtime; vanilla js reads the computed json and moves the math. |

Flow; `make compute` runs julia and writes `site/data/*.json`; `make check` builds and runs the rust referee; `make serve` previews the static site; vercel deploys the `site/` folder directly.

## The entries; five domains, twenty-four living pieces

### The sky
1. Newton's gravitation and kepler's orbits; kepler and newton; live orbit integrator with an eccentricity slider; julia integrates the orbit.
2. Euler's identity; euler; the spiral through the complex plane, animated.
3. The hubble-lemaître law; lemaître, who found the expanding universe two years before hubble's name took it; the card tells that story.
4. Planck's blackbody law; planck, who didn't believe his own quantum; curves that shift with temperature and glow the color of the star they describe; julia evaluates the law.
5. Laplace's tidal equations; laplace; cross-links the sibling machine tide.jl, which runs this math for real.

### The earth
6. The fourier series; fourier; epicycles drawing a shape live; julia solves the coefficients.
7. Navier-stokes; navier and stokes, and the millennium problem that still stands; flow around an obstacle.
8. The wave equation; d'alembert; a plucked string with harmonics.
9. The lorenz attractor; lorenz, who found chaos in a rounding error; the butterfly, integrated live; julia integrates it.
10. Maxwell's equations; maxwell standing on faraday's intuition; field lines that respond to a dragged charge.

### The living
11. Phyllotaxis and the golden angle; fibonacci, and the indian mathematics his book carried west; vogel's spiral with a divergence-angle slider showing why only 137.5° leaves no gaps; julia generates the points.
12. Turing patterns; turing's last paper; gray-scott reactions growing spots and stripes.
13. Lotka-volterra; lotka and volterra; foxes and rabbits in a phase orbit.
14. Hardy-weinberg equilibrium; hardy, who reportedly didn't care for biology, and weinberg, a physician; the gene pool at rest.
15. Hodgkin-huxley; hodgkin and huxley; an action potential that fires when pushed.

### The invisible
16. The schrödinger equation; schrödinger; a wave packet meeting a barrier and choosing to tunnel.
17. Noether's theorem; emmy noether, whose theorem quietly runs all of physics; the centerpiece card of the whole site.
18. Boltzmann's entropy; boltzmann, whose equation is carved on his tombstone; gas particles with a temperature slider.
19. Shannon entropy; shannon; surprise measured in bits.
20. The uncertainty principle; heisenberg; a gaussian squeezed in position until its momentum spreads.

### The structure
21. The pythagorean theorem; named for pythagoras, known to babylon and the gougu theorem long before; the card says so plainly.
22. Bayes' theorem; bayes, and richard price, who published it and is forgotten.
23. The riemann zeta function; riemann; the zeros on the critical line; julia computes the zeros shown.
24. The gauss-bonnet theorem; gauss and bonnet; a surface deformed while its total curvature refuses to change.

Each entry carries both readings; the rigorous statement and derivation sketch for mathematicians, then "the intuition" in plain language for everyone. and every visualization ships a "take it home" toggle that copies a one-file implementation of itself, small-machines style, in julia or rust where it fits.

## The arena; the problems ledger

`problems.html` opens with the millennium problems flagged and the great open questions seeded by field; riemann, p vs np, navier-stokes existence, birch and swinnerton-dyer, hodge, yang-mills mass gap, the collatz conjecture, goldbach, the twin prime conjecture, and on. the ladder grows it to 200; one problem per pull request, with sources.

The ledger is the soul of the arena:
- Attempts and problems live as cue data, validated by the rust referee in ci; no pr merges with a broken ledger.
- Every attempt records; name, date, problem id, link to the attempt, and status.
- Statuses run; **attempted** → **under review** → **verified**, or **withdrawn**. anyone may be listed as an attemptor for trying; only verified proofs earn "solved by, recorded on."
- Attempts arrive as pull requests; the template requires the attemptor's name, a link, and a statement of what is claimed.
- Verification is honest; claimed solutions are marked under review with the date, and the readme names exactly what counts as verified; a published peer-reviewed result or a checked formal proof. no silent claims.
- The page renders the ledger as a calm table and a counter; how many have tried, how many pages the book still keeps closed.

## More features, all in the same voice

- **The margin**, after fermat; a section where anyone can submit a short note on an entry, an insight, an alternative proof, a correction. pr-based, curated, each note keeps its author's name and date. "this margin is no longer too small."
- **The timeline strip** on the humans page; mathematics as one horizontal scroll from babylon to now, with the regions it actually came from.
- **Open the book at random**; one button that lands on a random entry.
- **A print stylesheet**; every entry prints like a page from a real book, for classrooms.
- **Sister machines**, linked where the math is shared; tide.jl runs laplace, night.jl runs kepler, lumen.rs runs the color science.

## Design must-dos, carried from the start

- Clean, non-generic, elegant, calm. the site should feel like an instrument, not a landing page.
- Demure, unique typography; a serif display face with personality, never a default stack.
- Section cards must not be the usual rectangles; unique shapes, unique clean pills and tags. entry plates should feel like engraved book plates.
- A unique compatible palette; brand-new, not spruce and copper, not ink and verdigris, nothing borrowed.
- No emojis anywhere; typography, shape, and color carry the weight.

## Voice rules, non-negotiable

- Casual, direct, first person; reads like i wrote it. first person belongs to the book's own voice; the hero, the margins, the attribution notes, the human cards. inside the entries, the rigorous reading stays neutral and declarative, and the intuition speaks in warm imperative imagery; the book never performs the derivation as "i". instructions, ladders, checklists, and templates stand in the imperative or the neutral; "choose one entry.", never "i choose" and never "you must". the site hosts the book, not its machinery; contributing documents live in the repo, and the site carries only the short ladder with an outward link.
- The rules bend. none of these rules, including this one, gets applied so uniformly that the uniformity itself becomes the pattern; that is the generated smell the whole voice exists to avoid. tense follows the story; "i placed", "i kept", "i ran", not "i put" on repeat. sentence openings vary; not every line starts with i, and the occasional neutral or passive line is right when it reads right. if a stretch of writing sounds like a stylesheet being enforced, rewrite it until it sounds like a person who simply writes this way.
- The book's i curates; it never observes, discovers, or proves. every first-person line in the book means the book arranging its own pages; keeping, placing, crediting, setting beside. no innovator ever speaks as i; their acts belong to them in the third person, named in the same breath as the book's arranging. the solver claims in the ledger are the exception that proves the rule; those speak as the attemptor and are signed by name.
- The hall breaks its own template. a run of cards that all open the same way, "i put X because Y", reads generated even when every line is true. vary the openings across any run; a minority of first-person lines with varied verbs, neutral declarations, inversions like "beside Kepler's ellipses stands Newton's law". if one placement verb dominates a stretch of cards, rewrite until it does not. the october sweep left sixteen first-person strings across the whole book, three of them solver claims; keep it near that.
- No second person and no third-person writeups anywhere.
- No em dashes ever; use ; or , or → contextually. plain dashes only inside hyphenated words.
- Capitalize the first word of headers, paragraphs, and bullet items; the rest stays lowercase-casual.
- Attribution creed everywhere; contested histories named as contested, multiple originators all praised, the canon corrected where it forgot people. the mac-tutor archive at st andrews is the citation backbone.

## Code voice; the comments matter as much as the code

The code must read like i wrote it, because it is going on the account. every file follows the canon already shipped in lumen.rs and night.jl:

- The file header names the machine and says why it exists in one breath; for example `// small machines; lumen. the palette auditor. one file, no crates; it exists as itself.` followed by the usage lines.
- Comments are lowercase-casual, first person where it fits, and they say why, not what. no restating the code, no noise, no license-shaped walls of text.
- Clean code over clever code; small functions, honest names, no cleverness for its own sake. if a line needs a long comment, the line gets rewritten instead.
- No emojis, no em dashes in comments either; the same punctuation canon as the prose.
- Tests and checks get the same voice; `night; the checks hold` is the style.
- Every julia script prints nothing but its json; every rust error message reads like a person, not a stack trace.

## What the first session ships

1. Repo `Mascottz/codex-naturalis` with description, topics, and the skeleton; `make compute`, `make check`, `make serve` working.
2. The cue schemas; entry, problem, attempt; with one of each validated.
3. The full visual identity; palette, typography, section shapes, plate styles, the landing spine.
4. Three entries alive as the vertical slice; euler's identity, phyllotaxis, the lorenz attractor; sky, living, and earth in one sitting; with julia computing the phyllotaxis points and the lorenz trajectory for real.
5. The originator-card component with euler as the worked example.
6. `problems.html` seeded with the millennium problems and ten great open questions, the ledger working with one example attempt, and the status ladder visible.
7. `humans.html` scaffolded from the three shipped entries.
8. The rust referee binary with its ci check; the arena cannot merge broken.
9. CONTRIBUTING.md with both ladders; one visualization per pull request, one problem or attempt per pull request, originator cards mandatory.
10. README.md in the voice above, with the language table, the arena, the margin, and the sister-machines line.

## House rules

- Push with the token i paste; never reuse an old one.
- Everything proves itself; julia computations carry their invariants, the referee validates the arena, the ledger can't break silently.
- When in doubt, ship the beautiful minimum and leave a ladder.

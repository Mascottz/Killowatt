# Session message; Codex Naturalis, the third sitting

Paste this entire message into the session that owns the repo.

Context; `Mascottz/codex-naturalis`, live on vercel from main. main was recently walked backwards by this session's platform between pushes; before committing anything, fetch main first, and never push to main. push only to the working branch `arena/01a1078e-codex-naturalis`. every commit carries author and committer `Mascottz <175293202+Mascottz@users.noreply.github.com>` and no `Co-authored-by` trailer naming arena-agent or any bot. the merge into main happens elsewhere.

---

## Part one; the desk

The arena gets a solving room. a new page, `solve.html`, linked from the arena and the hero, where anyone can take a shot at any open problem on the site. the feel is a desk laid out with everything needed, not a form.

1. **The roll.** at the top of the desk sit two ways to choose a problem, and both are toys in their own right. a die that rolls and lands on a random open problem from the full ledger, world problems and house problems together; and a small rubik's cube that scrambles itself and settles on a random problem as its "solved state". either one runs the same scramble animation and then opens the desk for that problem. pick one at random on load if the visitor arrives cold.
2. **The desk itself.** once a problem is chosen, the desk lays out everything needed to attempt it, in five blocks. the full statement, with field, status, and sources; the definitions the statement leans on, pulled from the book's entries with deep links; the related plates in the book, linked; the take it home machines relevant to the problem where they exist, with rerun commands; and the ledger as it stands, attempts shown as dated notes on the desk, like comments that keep their authors' names.
3. **The submission.** the site is static, so the desk composes the attempt instead of receiving it. a small form asks for the attemptor's name, the claim in one line, and a link to the work. one button, "bring it to the ledger ↗", opens a prefilled github issue on the repo with the attempt template, name, date, problem id, claim, and link already written in. the page states the rest honestly; the issue lands on the desk as an attempted note once the ledger pull request merges, and verification follows the arena ladder. no silent claims, no backend, no accounts.
4. **The cube's explanation.** the cube on the desk links into the book's rubik entry, part two below, so the toy and the mathematics meet.

## Part two; the cube and its graphs

A new plate on the structure shelf.

**The rubik's cube group.** `|G| = 43,252,003,274,489,856,000`, the positions of the cube as a subgroup of the permutations of its stickers. the rigorous reading names the generators, the constraints that make most permutations unreachable, and god's number twenty as the diameter of the position graph under the face-turn metric. the intuition turns the cube into a landscape; every position is a place, every move is a step, and solving is finding the way home. humans; ernő rubik, who built the machine to teach geometry; morwen thistlethwaite, whose subgroup ladder made fast solving structural; and tomas rokicki with gene cooperman, daniel kunkle, and john welborn, whose computers proved twenty moves always suffice. the source line cites the group order's derivation and the god's number proof.

The visualization shows the graph-theoretic heart; the cube's cayley graph drawn small and schematic, vertices as positions, edges as moves, thistlethwaite's subgroup chain as nested layers of the walk home. beside it, a working toy-shelf cube; scramble and counter, so a visitor can feel the state space before reading why it has that exact size. this toy is the same cube the desk rolls, one implementation reused.

The framing paragraph says plainly what the cube has to do with graph theory; positions are vertices, moves are edges, algorithms are paths, and god's number is a diameter. nothing mystical, all structure.

## Part three; the sky grows

Five new plates in the sky, advanced and computed where the math allows.

1. **Galaxy rotation curves.** `v(r)² = G M(r) / r`, and the flatness that should not be there. the rigorous reading derives the expected keplerian fall-off and shows what a constant velocity implies about unseen mass. the intuition spins a galaxy with a slider between visible mass only and a halo, and the outer stars refuse to slow down. humans; vera rubin and kent ford, with the card honest about the nobel that never came; fritz zwicky named the missing mass decades earlier. julia computes both curves.
2. **The three-body problem.** newton's system with no closed answer, and poincaré's proof that no general one exists. the rigorous reading states the equations and poincaré's non-integrability; the intuition runs the figure-eight choreography that chenciner and montgomery found in 2000, three equal masses chasing one another forever. the visualization integrates the figure-eight live and lets a small perturbation grow into chaos, which is the whole lesson. julia integrates.
3. **The jeans mass.** the threshold above which a gas cloud collapses under its own gravity instead of breathing apart. the rigorous reading balances pressure against gravity and reads off the critical mass; the intuition squeezes a cloud with a temperature and density slider until it decides to become a star. humans; james jeans, and the card notes how long his estimate stood before observation caught up. julia evaluates the mass across the slider range.
4. **The eddington luminosity.** the brightness at which radiation pressure stops matter falling in. the rigorous reading equates the outward photon force on an electron with gravity and reads the limit; the intuition feeds an accreting object and watches the inflow stall at the ceiling. humans; arthur eddington, who also carried einstein's theory to the english-speaking world and tested it against an eclipse.
5. **The schechter luminosity function.** `φ(L) dL = φ* (L/L*)^α e^(−L/L*) dL/L*`, the census of galaxies by brightness. the rigorous reading names each parameter and the faint-end slope's weight; the intuition draws the distribution and lets α bend, so the visitor sees how many faint galaxies the universe keeps hidden. the card belongs to paul schechter, and the page links onward to the hubble-lemaître plate.

## Part four; advanced problems for the arena

New open problems for the ledger, astronomy and prediction where the fields allow, each with a source and stated precisely.

1. **The hubble tension.** the early-universe and late-universe measurements of H₀ disagree beyond their error bars. question; is the disagreement new physics, a systematic, or a statistic? status open, sources; the clay-adjacent reviews are not needed, cite the sh0es and planck results directly.
2. **The long-term stability of the solar system.** laskar's integrations show the orbits are chaotic on million-year scales. question; prove bounded stability or exhibit a rigorous instability channel for the inner planets over five billion years. status open.
3. **The dark halo's shape.** simulations grow cusped profiles; galaxies often show cores. question; settle the cusp-core problem from first principles of baryonic feedback or particle physics. status open.
4. **The lazy scrambler's horizon.** a house problem, C6, joining C1 through C5. type; computation with certified bounds. a scramble chooses uniformly random face moves, never repeating a face twice in a row; find the least n at which the resulting distribution over positions is within total variation one quarter of uniform, or certify the tightest interval. the retirement clause applies as written.
5. **The figure-eight's family.** a house problem, C7. type; proof. prove or disprove that the chenciner-montgomery figure-eight orbit is the unique minimal-period choreography for three equal masses up to rotation and scaling, or exhibit a second.

The desk rolls over these the same day they land; new rows in the problems data, new cards in the arena, and the ledger counter moves.

## Part five; the canon, unchanged

Voice; the book reflects in first person, exposition stays neutral and declarative, instructions stay imperative. no second person, no emojis, no em dashes, first word of headers, paragraphs, and bullets capitalized. and the rules bend; nothing gets repeated so uniformly that the uniformity itself reads as generated. tense follows the story, "i placed" and "i kept" where the past is the right shape, sentence openings vary, and any passage that sounds like a stylesheet being enforced gets rewritten until it sounds like a person. design; the desk and the new plates keep the site's own palette and serif face, unique section shapes, no rectangle soup, no borrowed identity. every new visualization holds a computed invariant where feasible, julia computes what is mathematical, the referee still passes, and `make check` holds before the push.

## House rules

- Fetch main before committing; push only to the arena branch; never to main.
- Commit identity is Mascottz with the noreply email; no bot trailers, ever.
- When in doubt, ship the beautiful minimum and leave a ladder.

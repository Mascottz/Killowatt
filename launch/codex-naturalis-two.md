# Session message; Codex Naturalis, the second sitting

Paste this entire message into the session that owns the repo.

Context; the repo is now `Mascottz/codex-naturalis` (renamed, old urls redirect), the site is live on vercel and auto-deploys from main. build straight onto main with small commits. all voice rules from the kickoff still hold; first-person casual, no second person, no em dashes, no emojis, first word of headers, paragraphs, and bullets capitalized.

---

## Part one; the fix list, first

Before any new feature, clear these five:

1. Every link in the site source still says `codex-naturalis-` with the trailing hyphen; the margin's issue link, the arena's pull links. replace all of them with `codex-naturalis`.
2. The hall has a corrupted slug; lémaître and hubble link to `#hubblem-lemaitre` and the link text reads "hubblem lemaitre". fix the generator and the anchor.
3. The arena's problem rows all begin "i ask whether..."; these are the world's problems and they should stand in their own voice. "does every nontrivial zero of the zeta function have real part one half." first person belongs to the book's reflections, not to riemann's question.
4. The hall's cards whisper when they should praise. the noether card is the register; "i put noether's theorem at the center because symmetry and conservation deserve a center." sweep every card to that warmth; originators get praised, not catalogued.
5. The long-view strip is not chronological; hubble sits before laplace. sort it as a timeline or rename it as a constellation.
6. The first-person rule was over-applied inside the entries. "i write the scale factor as a(t)", "i sum capacitive current", "i squeeze a gaussian" reads as if the book is doing the derivation itself, and that is the wrong register for exposition. sweep every entry: the rigorous reading becomes neutral, declarative mathematics prose; "the scale factor a(t) is differentiated, and the local recession rate reads as H(t)d." the intuition becomes warm imperative imagery; "picture raisins moving apart in rising bread." first person stays only where the book is genuinely reflecting; the hero, the margins, the attribution notes, the human cards. if a sentence in an entry starts with "i" and it is not the book praising or reflecting, rewrite it.

## Part two; the toy shelf

A fourth page, `toys.html`, small and deliberate, where the book keeps its toys. zero dependencies, canvas and svg only, and every toy links back to the entry it secretly explains, so the fun is load-bearing.

1. **Buffon's needles**; drop needles on ruled paper, watch π crawl out of the randomness; the slider sets the needle count and the page keeps a running estimate. links to the structure shelf.
2. **The galton board**; beads fall through pegs and chaos settles into the bell curve, drawn live as a histogram. links to boltzmann's entropy.
3. **The chaos game**; one point jumping halfway toward random corners, drawing a sierpinski triangle out of nothing. links to the lorenz attractor.
4. **Hilbert's hotel**; a tiny game where the guest arrives and the guest always gets a room, because infinity has one; animate the shift, keep the wonder. links to noether and the structure shelf.

## Part three; listen to the math

A small speaker toggle on the lorenz and fourier entries, using the browser's own web audio; no libraries, nothing fetched. the attractor's z-coordinate hums and drifts as it orbits; the fourier series plays its harmonics as it draws. the copy around it is one line; "the butterfly has a sound."

## Part four; ex libris

On every entry plate, a bookplate generator; type a name, and the site lays out a real bookplate ready for the print stylesheet. the formula engraved at the top, "this page of the book of nature belongs to", the originator's names, and the date. classrooms are the audience; make it beautiful enough to frame.

## Part five; the duel wall

A slim section of margin notes about mathematics' great feuds, each told in three sentences with the formula they fought about, and the ending stated honestly:

1. **Tartaglia against cardano**; the cubic formula, a sworn secret, and a publication that broke the oath. `x³ + px = q`
2. **The bernoulli brothers**; the brachistochrone, a challenge posted publicly and solved over night. the cycloid.
3. **Newton against leibniz**; the calculus, two notations, and a priority fight that cost both sides decades. `dy/dx` versus fluxions.
4. **Ferrari against del ferro's heirs**; the quartic, solved in a duel of letters. `x⁴` reduced to the cubic.

## Part six; the closed pages

`solved.html`, the page for problems the world has already closed. twelve entries, each carrying the solver's name, the year, and one line about how the closing was verified; where a formal proof exists, say so. keep the tone; a closed page is not a dead page.

1. Fermat's last theorem; andrew wiles with richard taylor, 1995.
2. The poincaré conjecture; grigori perelman, 2003, who declined the prize; formal verification followed.
3. The four color theorem; appel and haken, 1976, the first computer-assisted closing.
4. The kepler conjecture; thomas hales, 1998, with the flyspeck formalization completed in 2014.
5. The weil conjectures; pierre deligne, 1974, finishing grothendieck's program.
6. The classification of finite simple groups; many hands, completed around 2004.
7. The weak goldbach conjecture; harald helfgott, 2013.
8. The prime number theorem; hadamard and de la vallée poussin, 1896, independently.
9. The basel problem; euler, 1734, `Σ 1/n² = π²/6`.
10. The quintic's refusal; ruffini 1799 and abel 1824, no formula in radicals.
11. The continuum hypothesis; gödel 1940 and cohen 1963, independence in both directions.
12. The irrationality of e; euler, 1737.

Solver names link into the hall where a card exists; where the solver deserves a card and has none, add it.

## Part seven; the codex problems

The book issues its own challenges; five house problems, advanced and meant to be hard, stated precisely, each with a type and a way in. they live on the arena page under their own heading, and they run on the same ledger as the world's problems; attempted → under review → verified.

The honesty clause goes in the copy, verbatim in spirit; these problems belong to the book, the difficulty claims are the book's, and if a house problem turns out to have been solved before, the ledger records the source and the problem retires with honors.

**C1 · The crooked needle.** Type; proof. buffon's noodle: among all plane curves of total length 1 dropped on ruled paper of spacing 1, the expected number of crossings is fixed, but the probability of at least one crossing is not. find the curve that maximizes it, and prove optimality.

**C2 · The silent board.** Type; proof with computational witness. on a galton board of n rows, pegs may be removed. classify every removal pattern for which the beads land exactly uniformly across the bins; state for which n such a pattern exists at all, and prove the classification. the witness is a julia script that brute-forces small n and agrees.

**C3 · The pile's memory.** Type; proof or verified computation. in the identity element of the abelian sandpile on the 2n × 2n grid, let f(n) be the fraction of sites holding exactly two grains. prove that f(n) converges as n grows and find the limit, or produce a rigorous numerical value to six digits with an error bound.

**C4 · The butterfly's period.** Type; verified computation. for the lorenz system with σ = 10 and β = 8/3, find the smallest ρ at which a periodic orbit of period three exists, to six digits, with a verified enclosure of the orbit; interval arithmetic or equivalent, so the referee can re-run it.

**C5 · The duelist's dice.** Type; proof or exhaustive search with proof of exhaustiveness. construct two six-sided dice with distinct positive integer faces such that the non-transitive cycle a beats b, b beats c, and c beats a holds with probability exactly two thirds, or prove that no such pair exists.

Solutions live on the site, not just in a ledger somewhere else:

- Every problem carries a solutions area directly beneath it. a submission arrives as a pull request that adds both the ledger entry and the solution file itself, under `solutions/{problem-id}/`.
- Proof solutions are written as markdown in the pull request; when verified, the full proof renders on the problem page under the solver's name, with the line "solved by, recorded on" and a verification stamp.
- Computational witnesses are the one-file julia or rust source, embedded in the page with a copy button and the exact command to re-run it; the verified output is shown beside it so a reader can check the number without leaving the browser.
- Attempted submissions get their own card on the problem page; name, date, the claim in one line, and the status stamp. trying is visible on the site, not just recorded.
- Status stamps render in three registers; attempted is quiet, under review carries its date openly, verified gets the full engraving.
- The rust referee's ci validates the ledger and the solution files' shape on every pull request, so the page can never render broken.
- A verified house problem earns "solved by, recorded on", the solution stays published on the site permanently, and the solver's name joins the closed pages.

## House rules

- Commit identity is mine, always. configure git before any commit; user.name `Mascottz`, user.email `175293202+Mascottz@users.noreply.github.com`, and when committing through the api, pass the same author and committer explicitly. no bot names, no sandbox defaults, ever. the contributor list must read one name.
- Push with the token i paste; never reuse an old one.
- Every new page keeps the design creed; unique section shapes, the site's own palette and serif face, no emojis, no rectangle soup.
- Every new visualization holds a computed invariant where feasible, and the referee still passes.
- When in doubt, ship the beautiful minimum and leave a ladder.

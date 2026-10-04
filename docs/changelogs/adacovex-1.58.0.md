# adacovex 1.58.0

Date: _2026-10-04_

Version bumped 1.57.0 -> 1.58.0.

## Changes

### C1: The SimpleEnglish skill is now a named third-party component in both notices

The skill is the one third-party work that adacovex vendors into its own
source tree, and neither notices file presented it that way. `docs/CREDITS.md`
gave it a single sentence under a heading named Technical writing guidance, and
`docs/THIRD_PARTY_NOTICES.md` did not mention it at all. A reader who wanted to
know what the documentation rules came from, and under what licence, had to
find `skills/simple-english/` unassisted. The attribution existed, and it was
too quiet to serve as a licence notice.

Both files now carry the skill as a named component with the same detail in
each:

- `docs/CREDITS.md` replaces the Technical writing guidance section with a
  `## SimpleEnglish skill` section placed above the third-party component
  summary. It names the upstream project, the vendored path, the four files the
  directory holds, the MIT licence, and the link to the licence terms.
- `docs/THIRD_PARTY_NOTICES.md` gains a `## Vendored agent skill: SimpleEnglish`
  section ahead of the toolchain section, in the table shape the rest of the
  file uses. The row states the version (1.3.0, ASD-STE100 Issue 9 of
  2025-01-15), the MIT licence with its URL, and the use.
- Both files now state the two project overrides outside `AGENTS.md`:
  British English spelling replaces the American spelling that rule 1.14 names,
  and a paragraph holds at most four sentences, not the six of rule 6.6.
- Both files now point at the controlled list of Technical Names, which is where
  a writer goes before using a word that the standard does not define.

The two notices differ in purpose, so they differ in emphasis. The credits page
tells a reader what shapes the documentation. The notices page tells a
distributor what licence covers a directory in the tree, and it says that the
copy is unmodified upstream text that ships at every checkout, so the notice
covers every reader of the tree and not only the built binary. Both pages state
that the skill governs prose only: it is not linked into the binary, it runs no
code at build time, and no generated file comes from it.

The sibling Ada_CRDT project received the same change in crdt 1.17.0, so the
two trees describe the vendored skill the same way.

## Test Suite

1756 tests across 25 categories, the same counts as 1.57.0. The change set is
two documentation pages plus the release metadata that `make bump-version`
writes, so no Ada source, no test, and no test category changed.

The gate that covers this change is `make docs-check`, together with
`make link-check` and `make changelog-check`. All three pass on the edited
pages: the new sections keep every paragraph within the four-sentence rule, the
relative links resolve (217 markdown files checked), and this file matches the
canonical changelog format.

## Proof Results

Unchanged at **Platinum**, 0 unproved, 0 justified, **884 of 884 VCs across 66
analysed units** under gnatprove 16.1.0 at `--level=4`. No Ada source,
contract, pragma, or aspect changed, so the figures were read from the
verification campaign of 1.57.0 rather than re-run, and no proof metric moved.

The version constant in `src/adacovex_version_info.ads` did change, because
`make bump-version` regenerates it. That unit is a generated string constant
with no verification condition, so the proof-input hash is unaffected in every
respect that carries a check.

## Traceability

The HLR tags are unchanged, and no tag is added or removed. `docs/CREDITS.md`
and `docs/THIRD_PARTY_NOTICES.md` are documentation artifacts, and no `HLR-*`
tag covers a documentation page: the tags name Ada packages and subprograms.
`AGENTS.md` requires that each third-party project is noted in both files, and
C1 is the change that brings the one vendored work into line with that rule.
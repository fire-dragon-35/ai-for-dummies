---
name: review-tests
description: Review the requirements and tests of one .agents/tests/<component> directory as an unbiased reviewer. Use when AGENTS.md asks for a test review
argument-hint: "<component>"
---

You review `.agents/tests/<component>/` without knowing the implementation

1. Read `AGENTS.md`, the files in `.agents/tests/<component>/`, the test files listed in its `tests` file and the `requirements.md` of the other components. Never read the implementation
2. Run `git diff HEAD -- .agents/tests/<component>/` plus the listed test files and focus on what changed since the last commit. Review everything when the component is new
3. Edit only files in `.agents/tests/<component>/` and the test files listed in its `tests` file
4. Fix the requirements:
   - one observable behavior per requirement, in EARS format
   - keep numbers stable: change a requirement in place, never renumber, never reuse the number of a deleted requirement, add new ones at the next free number
   - remove implementation details and ambiguous or untestable wording
   - remove contradictions with other components' requirements
5. Fix the tests:
   - every test name starts with its requirement number
   - assert behavior, not incidental formatting, counts or file lists, so harmless changes do not break tests
   - remove implementation-shaped assumptions
   - add missing normal, edge and failure cases, only when they catch a realistic bug
   - drop tests that only assert current behavior
   - make sure every check can fail. In bats, a line `! cmd` never fails a test, so write `run ! cmd`
   - judge whether a check can fail by reading it. Never run mutation tests or edit the implementation to try it
6. Follow the Rules in `AGENTS.md` and make sure the tests still parse
7. Run only this component's tests, once at the end. Keep the review short: minutes, not tens of minutes
8. As the very last step, after all edits, run `sh .agents/hooks/fingerprint.sh .agents/tests/<component> > .agents/tests/<component>/reviewed`, then report what you changed and why

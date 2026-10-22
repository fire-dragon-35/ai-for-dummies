# Git hooks
Quality checks run in the background and their results show on every commit, so no commit or push ever waits for them or fails because of them

Checked file: a tracked file, or an untracked file that is not ignored, that exists in the working tree and is not under `.agents/skills/`. Shell file: a checked file ending in `.sh` or in `.agents/hooks/`. Module file: a checked file ending in `.mjs`. Comment line: in a shell file a line whose first non-blank character is `#`, except a `#!` first line and a `# shellcheck` directive; in a module file a line whose first non-blank characters are `//` or `/*`, except a `#!` first line. Check line: a line on standard error with a mark (`✓` passed, `✗` failed), a check name and a detail. Test component: a directory directly inside `.agents/tests/`. Fingerprinter: `.agents/hooks/fingerprint.sh`, run as `sh fingerprint.sh <component>`. QA run: `sh .agents/hooks/qa.sh`. Post-commit hook: `.agents/hooks/post-commit`. Test command file: `.agents/test-command`, one line with the command that runs the project's own tests. Tests file: the file `tests` of a test component, listing test files outside the component, one path from the repository root per line.

## QA run
- R1: When every check passes, the QA run shall print a check line marked `✓` for `reviewed tests`, `no comments`, `line limit` and `shellcheck`, and exit with status 0
- R2: If a checked shell or module file has a comment line, then the QA run shall name the file in a check line marked `✗` for `no comments` and exit with a non-zero status
- R3: If a checked file has more than 400 lines, then the QA run shall name the file in a check line marked `✗` for `line limit` and exit with a non-zero status
- R4: If a checked shell file has shellcheck findings, then the QA run shall print a check line marked `✗` for `shellcheck` and exit with a non-zero status
- R5: The QA run shall judge the working tree content of a file, staged or not
- R6: The QA run shall change no file in the working tree and no staged file
- R8: When standard error is not a terminal, the hooks shall print no terminal escape sequences
- R13: When `.agents/tests/` exists, the QA run shall run every test in it and exit with a non-zero status if a test fails
- R15: When GNU parallel is installed and more than one processor is online, the QA run shall run tests of different test components concurrently
- R16: While the QA run runs the tests, it shall print one progress mark per finished test on standard error, `.` for passed, `F` for failed and `s` for skipped, and no name of a passed test
- R17: When a test fails, the QA run shall print the name and the failure output of that test after the progress marks
- R18: When the tests finish, the QA run shall print a summary line `<passes> pass, <fails> fail, <skips> skip` on standard error that is no check line
- R22: While a QA run is active, a second QA run shall exit with status 0 without running the checks and tests itself, and the active run shall run the checks and tests once more when it finishes
- R24: When the test command file exists and its command, run from the repository root, exits with status 0, the QA run shall print a check line marked `✓` for `project tests`
- R25: When the test command file does not exist, the QA run shall print no check line for `project tests`
- R26: If the command of the test command file exits with a non-zero status, then the QA run shall print a check line marked `✗` for `project tests` followed by the last line of the command's output, and exit with a non-zero status
- R23: When the QA run is started with the environment of a git hook, such as `GIT_INDEX_FILE` or `GIT_DIR` of another repository, its checks and tests shall act on the repository it runs in and not on that other repository

## Reviewed tests
- R9: The fingerprinter shall print one line that changes when a file of the component other than `reviewed` is added, removed, renamed or changed, including files in subdirectories, and when a file listed in its tests file changes or the list changes
- R10: If a test component has no `reviewed` file holding its fingerprint, then the QA run shall name the component in a check line marked `✗` for `reviewed tests` and exit with a non-zero status

## Post-commit
- R19: When the post-commit hook runs, it shall exit with status 0 and return before the QA run it started has finished, also when checks or tests fail
- R20: When the post-commit hook runs, it shall start a QA run in the background that finishes and logs its results
- R21: When the post-commit hook runs, it shall print the brief metrics report of the repository, with the results of the earlier QA run, before it starts the QA run

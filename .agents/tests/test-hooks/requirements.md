# Git hooks
The opt-in hooks keep every commit within the rules and every push tested, while adding as little time as possible

Checked file: a staged file that is added or modified and is not under `.agents/skills/`. Shell file: a file ending in `.sh` or a file in `.agents/hooks/`. Module file: a file ending in `.mjs`. Comment line: in a shell file a line whose first non-blank character is `#`, except a `#!` first line and a `# shellcheck` directive; in a module file a line whose first non-blank characters are `//` or `/*`, except a `#!` first line. Check line: a line on standard error with a mark (`✓` passed, `✗` failed), a check name and a detail. Test component: a directory directly inside `.agents/tests/`. Fingerprinter: `.agents/hooks/fingerprint.sh`, run as `sh fingerprint.sh [--staged] <component>`.

## Pre-commit
- R1: When every check passes, the pre-commit hook shall print a check line marked `✓` for `reviewed tests`, `no comments`, `line limit` and `shellcheck`, and exit with status 0
- R2: If a checked shell or module file has a comment line, then the pre-commit hook shall name the file in a check line marked `✗` for `no comments` and exit with a non-zero status
- R3: If a checked file has more than 400 lines, then the pre-commit hook shall name the file in a check line marked `✗` for `line limit` and exit with a non-zero status
- R4: If a checked shell file has shellcheck findings, then the pre-commit hook shall print a check line marked `✗` for `shellcheck` and exit with a non-zero status
- R5: The pre-commit hook shall judge the staged content of a file, not its working tree content
- R6: The pre-commit hook shall change no file in the working tree and no staged file
- R7: When `.agents/backlog.md` has non-blank lines, the pre-commit hook shall print them after the check lines without changing its exit status
- R8: When standard error is not a terminal, the hooks shall print no terminal escape sequences

## Reviewed tests
- R9: The fingerprinter shall print one line that changes when a file of the component other than `reviewed` is added, removed, renamed or changed, including files in subdirectories
- R10: If a test component touched by the staged changes has no staged `reviewed` file holding the staged fingerprint, then the pre-commit hook shall name the component in a check line marked `✗` for `reviewed tests` and exit with a non-zero status
- R11: When the staged changes delete every file of a test component, the pre-commit hook shall not reject the commit because of that component
- R14: When run with `--staged`, the fingerprinter shall use the staged files of the component and ignore their working tree state

## Pre-push
- R12: The pre-push hook shall run shellcheck on every tracked shell file and print a check line for `shellcheck`, and if it has findings, exit with a non-zero status without running the tests
- R13: When `.agents/tests/` exists, the pre-push hook shall run every test in it and exit with a non-zero status if a test fails
- R16: While the pre-push hook runs the tests, it shall print one progress mark per finished test on standard error, `.` for passed, `F` for failed and `s` for skipped, and no name of a passed test
- R17: When a test fails, the pre-push hook shall print the name and the failure output of that test after the progress marks
- R18: When the tests finish, the pre-push hook shall print a summary line `<passes> pass, <fails> fail, <skips> skip` on standard error that is no check line
- R15: When GNU parallel is installed and more than one processor is online, the pre-push hook shall run tests of different test components concurrently

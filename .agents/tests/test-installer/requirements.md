# Installer
Any repository gets the agent setup with one command, adds only what it asks for, and keeps it current without losing its own files

Installer: `install.sh`, run as `sh install.sh [--update] [--hooks] [--metrics] [--ci] <target>`. Target: the top-level directory of a git repository. Block: the lines of `AGENTS.md` from `<!-- ai-for-dummies:start -->` to the next `<!-- ai-for-dummies:end -->`. CLAUDE block: the start marker, the line `@AGENTS.md` and the end marker. Installed target: a target whose `AGENTS.md` has the block. Core files: every `SKILL.md` in this repository's `.agents/skills/` except the `metrics` skill, `.agents/repository-context/generate.sh`, `.agents/repository-context/skills.sh` and `.agents/web-sources.md`. Hook files: every file in `.agents/hooks/`. Metrics files: every file in `.agents/metrics/` and the `metrics` skill. CI file: `.github/workflows/agents.yml`

## Install
- R1: When run on a target, the installer shall copy the core files with identical content, append the block to `AGENTS.md` and the CLAUDE block to `CLAUDE.md` (creating each file if missing and keeping its lines), write the repository map and skills table, and exit with status 0
- R2: When run without `--hooks`, `--metrics` or `--ci`, the installer shall copy no hook, metrics or CI file and change nothing inside `.git/`
- R3: When run with `--hooks` on a target without `.agents/hooks/pre-commit`, the installer shall also copy the hook files, keeping executable files executable, and set the target's local `core.hooksPath` to `.agents/hooks`
- R4: If run with `--hooks` on a target without `.agents/hooks/pre-commit` whose local git config sets `core.hooksPath` or whose `.git/hooks/` has a file not ending in `.sample`, then the installer shall name it on standard error, exit with a non-zero status and change nothing
- R5: When run with `--metrics`, the installer shall also copy the metrics files, keeping executable files executable
- R6: When run with `--ci` and `--hooks`, the installer shall also copy the CI file
- R14: If run with `--ci` but without `--hooks` on a target without `.agents/hooks/pre-commit`, then the installer shall exit with a non-zero status and change nothing
- R7: When the installer succeeds, each file under the target's `.agents/skills/` shall be readable with identical content under `.claude/skills/`
- R8: If the target is missing, not a git repository or not its top-level directory, or, without `--update`, a file to copy or the block already exists, then the installer shall name the problem on standard error, exit with a non-zero status and change nothing
- R9: When the installer succeeds, it shall print a line that names the target and the command `git add . && git commit`
- R10: If an option is unknown or the target is missing from the arguments, then the installer shall print its usage on standard error and exit with status 2

## Update
- R11: When run with `--update` on an installed target, the installer shall replace the block with this repository's block, keep every line outside it, copy the core files except `.agents/web-sources.md`, the hook files when the target has `.agents/hooks/pre-commit`, the metrics files when it has `.agents/metrics/`, and the CI file when it has one, plus the parts named by options, and exit with status 0
- R12: When run with `--update`, the installer shall keep the target's `.agents/tests/`, `.agents/backlog.md`, `.agents/scout.md`, `.agents/web-sources.md`, its own skills and, when it has `.agents/hooks/pre-commit`, its `core.hooksPath`
- R13: If run with `--update` on a target that is not installed, then the installer shall exit with a non-zero status and change nothing

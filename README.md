# ai-for-dummies
Agent setup for any git repository: shared rules, skills, a repository map and tests-first workflow

## Install
```sh
git clone https://github.com/fire-dragon-35/ai-for-dummies.git
sh ai-for-dummies/install.sh [--hooks] [--metrics] [--ci] <target-repository>
```
Adds `.agents/`, `.claude/skills` and a marked block in `AGENTS.md` and `CLAUDE.md`. Stops if anything it adds already exists

| Option | Adds | Needs |
|---|---|---|
| `--hooks` | rule check on commit, shellcheck and tests on push (concurrent with GNU parallel) | no existing git hooks |
| `--metrics` | usage, cost, energy and verdict report | Node |
| `--ci` | the push checks in GitHub Actions | `--hooks` |

Update: `git -C ai-for-dummies pull && sh ai-for-dummies/install.sh --update <target-repository>`. Your tests, notes and skills are kept

Remove: delete `.agents/`, `.claude/skills` and the marked blocks; with hooks, `git config --unset core.hooksPath`

## Skills
Claude Code: `/<skill>`. Other agents: ask by name

| Skill | Does |
|---|---|
| `context` | regenerates and loads the repository map |
| `scout` | checks toplists and news for new MCP servers, skills and AI tech |
| `grilling` | interviews you about a plan |
| `review-tests` | reviews one test component as a subagent |
| `metrics` | reports usage, cost, energy and verdicts (`--metrics`) |

## Metrics
`node .agents/metrics/metrics.mjs [--html]` prints the report or writes `.git/ai-for-dummies/dashboard.html`. With hooks, every push writes it

- Usage: read from Claude Code session files in `~/.claude/projects`
- Cost: LiteLLM list prices, cached weekly
- Energy: [EcoLogits](https://github.com/mlco2/ecologits) minimum estimate, cached weekly
- Style: `.agents/metrics/tokens.css`

## Files
| Place | Holds | Committed |
|---|---|---|
| `.agents/skills/`, `hooks/`, `metrics/`, `repository-context/*.sh` | the setup, replaced by `--update` | yes |
| `.agents/tests/`, `backlog.md`, `scout.md`, `web-sources.md` | yours | yes |
| `.git/ai-for-dummies/` | verdict log, caches, dashboard | no |

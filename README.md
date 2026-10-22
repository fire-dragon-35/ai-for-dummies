# ai-for-dummies
Agent setup for any git repository: shared rules, skills, a repository map and tests-first workflow

## Install
```sh
git clone https://github.com/fire-dragon-35/ai-for-dummies.git
sh ai-for-dummies/install.sh [--hooks] <target-repository>
```
Adds `.agents/`, `.claude/skills` and a marked block in `AGENTS.md` and `CLAUDE.md`. Stops if anything it adds already exists

| Option | Adds | Needs |
|---|---|---|
| `--hooks` | a `post-commit` git hook that prints the stats and starts the quality checks and tests in the background, plus the usage, cost and energy report | Node, no existing `post-commit` hook, no `core.hooksPath` |

Nothing ever blocks or slows a commit or push. There are no other git hooks and no GitHub Actions. Agents run `sh .agents/hooks/qa.sh` in the background while they work. It also runs the project's own tests when `.agents/test-command` holds their command, such as `npm test`

Update: `git -C ai-for-dummies pull && sh ai-for-dummies/install.sh --update <target-repository>`. Your tests, notes and skills are kept

Remove: delete `.agents/`, `.claude/skills` and the marked blocks; with hooks, delete `.git/hooks/post-commit`

## Skills
Claude Code: `/<skill>`. Other agents: ask by name

| Skill | Does |
|---|---|
| `context` | regenerates and loads the repository map |
| `scout` | checks toplists and news for new MCP servers, skills and AI tech |
| `grilling` | interviews you about a plan |
| `review-tests` | reviews one test component as a subagent |
| `metrics` | reports usage, cost, energy and verdicts (`--hooks`) |
| `benchmark` | compares the same prompt with and without the setup (this repository only) |

## Metrics
Every commit prints a short summary from the previous background run: prompts and active time with the token mix, daily graphs of tokens, cost and energy, the checks and the tests, with failures named. `NO_COLOR` turns the colors off, `FORCE_COLOR` keeps them in a pipe. `node .agents/metrics/metrics.mjs [--brief]` prints the full report or the summary

- Usage: read from Claude Code session files in `~/.claude/projects`
- Cost: LiteLLM list prices, cached weekly
- Energy: [EcoLogits](https://github.com/mlco2/ecologits) minimum estimate, cached weekly

## Files
| Place | Holds | Committed |
|---|---|---|
| `.agents/skills/`, `hooks/`, `metrics/`, `repository-context/*.sh` | the setup, replaced by `--update` | yes |
| `.agents/tests/`, `test-command`, `backlog.md`, `scout.md`, `web-sources.md` | yours | yes |
| `.git/ai-for-dummies/` | verdict log, caches | no |

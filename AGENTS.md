# AGENTS.md

<!-- ai-for-dummies:start -->
## Rules
- No overengineering
- No duplicated code functionality
- No band-aid solutions
- No comments: clean code should be self-explanatory
- Consistent wording: no synonyms
- Keep each file under ~400 lines
- Never store secrets
- Clean up after yourself: don't leave dead code lying around
- Don't commit (git)
- Plan first for larger changes
- Run independent parts in parallel subagents: subagents that edit files run in worktree isolation and you merge their changes into the checkout

## `.agents/`
All agent related work lives here. Create what is missing. Outside it, only files that tools require at fixed paths: `AGENTS.md`, `CLAUDE.md`, `.claude/skills` and `.github/workflows/agents.yml`. Metrics data lives in `.git/ai-for-dummies/` and is never committed

### `.agents/tests/`
One directory per component, named `test-<component>`, such as `test-installer/` or `test-hooks/`, each with a `requirements.md` and its tests. Write or change them before implementing a feature or bug fix
1. Add requirements to the component the change touches, or create a new `test-<component>` directory whose `requirements.md` starts with `# <Component>` and one sentence on why it exists
2. Write requirements in EARS format ("When <trigger>, the <system> shall <response>."), one observable behavior each, no implementation details. Number them R1, R2... within the component. Change a requirement in place, never renumber, and never reuse the number of a deleted one
3. Write runnable tests with the requirement number in each test name. Assert behavior such as exit status, created files and names in output, not incidental formatting, counts or file lists
4. Spawn a subagent that runs the `review-tests` skill on the component. It writes the component's fingerprint to `reviewed`. With hooks, the pre-commit hook rejects test changes without a fresh review
5. Iterate until all tests pass. Never change tests to make them pass. If stuck, stop and report the failing tests

### `.agents/repository-context/`
Directory tree of the repository in `directories.md`. Read it instead of scanning the repository
`generate.sh` writes it and `skills.sh` writes the Skills table below. The `context` skill runs both and loads the map

### `.agents/backlog.md`
Backlog: things to fix later, not in the current task. One item per line: what is wrong, why it matters, how to fix it
1. When you find something to fix outside the current task, add an item instead of fixing it
2. When an item is fixed, remove it

### `.agents/scout.md`
Items judged by the `scout` skill, in the sections of `web-sources.md`, each with its `last checked` date, newest first. One item per line: date, item, verdict (adopt, consider), reason, link
Move an item to `web-sources.md` when it is installed. Remove it when the user rejects it

### `.agents/skills/`
Skills in the Agent Skills format, one `<name>/SKILL.md` per skill, where the directory name must equal the skill's `name` (unlike the `test-<component>` directories), listed in the Skills table below. `.claude/skills` links here for Claude Code. Add new skills here, never in `.claude/`, then run the `context` skill

## Skills
Read a skill's file when its use matches the task

| Skill | Use it when | File |
|---|---|---|
| context | Regenerate the repository map and the skills table and load the map. Use at the start of a task or after directories or skills change | `.agents/skills/context/SKILL.md` |
| grilling | Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases. | `.agents/skills/grilling/SKILL.md` |
| metrics | Report token usage, cost, energy, time per prompt, tools, MCP servers and check and test verdicts of this repository, as text or as a dashboard. Use when the user asks about usage, cost, speed or which checks and tests fail | `.agents/skills/metrics/SKILL.md` |
| review-tests | Review the requirements and tests of one .agents/tests/<component> directory as an unbiased reviewer. Use when AGENTS.md asks for a test review | `.agents/skills/review-tests/SKILL.md` |
| scout | Check the web sources for new MCP servers, skills and AI news relevant to this repository. Use when the user asks for toplists, new tools, latest news or trends | `.agents/skills/scout/SKILL.md` |
<!-- ai-for-dummies:end -->

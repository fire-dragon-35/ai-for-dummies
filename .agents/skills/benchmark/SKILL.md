---
name: benchmark
description: Compare cost, time, tokens, lines written and code quality for the same prompt in fresh repositories with and without this agent setup. Use when the user wants to measure the effect of a change to the setup
---

1. Run `sh .agents/skills/benchmark/run.sh [--task <task>] [--runs <n>] [--prompt <text>] [--claude <command>]` in the background. Tasks are in `tasks/`: `todo` (default, cost only) and `webapp` (adds hidden acceptance tests, a blind review and ESLint and duplication metrics). It runs `claude -p` once per repository with permissions skipped, so it spends real tokens: tell the user the number of runs first
2. Report the per-side lines: averages first, then the ranges, and what differs most. For quality tasks also summarize `acceptance.md` and `review.md` in the printed directory
3. Name the directory it printed so the user can inspect the runs

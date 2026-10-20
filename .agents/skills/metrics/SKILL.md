---
name: metrics
description: Report token usage, cost, energy, time per prompt, tools, MCP servers and check and test verdicts of this repository, as text or as a dashboard. Use when the user asks about usage, cost, speed or which checks and tests fail
---

1. Run `node .agents/metrics/metrics.mjs`. Usage comes from the adapters in `.agents/metrics/adapters/`, verdicts from the hooks
2. Summarize the output: totals first, then what stands out, such as the most expensive area, the most used tools and the checks and tests that fail most
3. `cost` is the API list price of the tokens, not a bill, and `energy` is an EcoLogits estimate from output tokens, the minimum of its range. Mention `unpriced` and `unmodelled` models when listed
4. Report an adapter error from standard error as it is. Never guess usage for an agent without an adapter
5. For a dashboard, run `node .agents/metrics/metrics.mjs --html` and give the user the printed path to open in a browser

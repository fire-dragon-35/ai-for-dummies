---
name: scout
description: Check the web sources for new MCP servers, skills and AI news relevant to this repository. Use when the user asks for toplists, new tools, latest news or trends
argument-hint: "[mcp-servers | agent-skills | latest-news]"
---

1. Read `.agents/web-sources.md` and `.agents/scout.md`. If the user passed a section name, check only that section
2. Fetch each source of the section. Keep only items newer than the section's `last checked` date in `.agents/scout.md`, or from the last 30 days if the section or date is missing
3. Skip items marked adopted in `.agents/web-sources.md`, items already in `.agents/scout.md`, items built into the agent, items duplicating something the repository has, and items for unrelated domains
4. Judge each remaining item against `AGENTS.md`, `README.md` and `.agents/repository-context/directories.md` with a verdict: adopt or consider
5. Report in the reply, one table per section: item, verdict, one-line reason, source link. List skipped items in one line, not a table
6. Add each adopt and consider item to the top of its section in `.agents/scout.md`
7. Set the section's `last checked` date in `.agents/scout.md` to today, creating the file and section if missing
8. Never install anything without the user's approval. When an item is installed, add it to its section in `.agents/web-sources.md` with where it is installed and remove it from `.agents/scout.md`

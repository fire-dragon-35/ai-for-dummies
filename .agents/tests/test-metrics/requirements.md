# Metrics
Users see what their agents spend, how long prompts take and which checks and tests fail, read straight from where the data already lives, without copying it

Log: the file `ai-for-dummies/metrics.jsonl` inside the common git directory of the repository. Verdict record: one JSON line in the log with `time`, `kind`, `name`, `result` and `detail`. Logger: `.agents/metrics/log.sh`, run as `sh log.sh <kind> <name> <result> [detail] [source]`. Reporter: `.agents/metrics/metrics.mjs`, run as `node metrics.mjs [repository] [--brief]`. Brief report: the output of the reporter with `--brief`. Visible length: the length of a line without terminal escape sequences. Adapter: an executable file in `.agents/metrics/adapters/`, run as `<adapter> <repository>`, that prints one usage record per line with the fields of R31. Price source: a JSON file in the format of LiteLLM's `model_prices_and_context_window.json`, at the URL in `AI_FOR_DUMMIES_PRICES_URL` (`http`, `https` or `file`) or the file of the LiteLLM repository. Price cache: `ai-for-dummies/prices.json` inside the common git directory. Model data: a JSON file in the format of `ecologits/data/models.json` of the EcoLogits repository. Model data store: `ai-for-dummies/ecologits.json` inside the common git directory. QA run: `sh .agents/hooks/qa.sh`

## Report
- R1: When adapters print usage records, the reporter shall print a `prompts` line with their count and the count per `agent`, `wall` and `active` lines with the sums of `wall_ms` and `active_ms` in the time format of R73 ignoring null values, a `tokens` line with the sums of `input`, `output`, `cache_read` and `cache_write` over `tokens` and `subagent_tokens`, and a `subagents` line with the sum of `subagents`, and exit with status 0
- R2: The reporter shall print `tools`, `mcp servers` and `commands` lines with the five most used names as `<name> <count>`, in descending order of count and then ascending order of name, and no such line when there is no name
- R3: The reporter shall print one line per check name with the mark `✓` or `✗` of its latest result and its latest detail, a `tests` line with the mark `✗` when the latest result of any test is a fail and otherwise `✓`, and `<passes> pass, <fails> fail, <skips> skip` counting each test name of the latest run once by its latest result, where the latest run is the test records with the `detail` of the last test record, and, when a test's latest result is a fail, a `failing` line with up to five of those test names
- R4: When there is no usage record and no verdict record, the reporter shall print `no metrics yet` and exit with status 0
- R5: If an adapter exits with a non-zero status, then the reporter shall write the adapter name and its message on standard error and still report everything else
- R6: The reporter shall use the repository argument, relative or absolute, for the adapters and the log, and the current directory without one
- R7: The reporter shall print no text of prompts, replies or tool inputs
- R111: When the repository has test components with a `requirements.md` in `.agents/tests/` and there are records, the reporter shall print a `coverage` line with `<component> <tested>/<total>` for every component, where a requirement is tested when `R<number>:` starts at least one test name in a bats file of the component directory or in a file listed, one path from the repository root per line, in the component's `tests` file
- R127: If a component's `tests` file lists a path that does not exist, then the reporter shall count the tests of the other files of the component and exit with status 0
- R112: When `.agents/backlog.md` has non-blank lines and there are records, the reporter shall print a `backlog` line with their count
- R73: The reporter shall write an active or wall time below 60 seconds as seconds with one decimal and `s`, below 60 minutes as minutes with one decimal and `min`, and from 60 minutes as hours with one decimal and `h`
- R103: The reporter shall count a verdict record of kind `check` only when its `source` names an existing file of the repository
- R113: The reporter shall print terminal escape sequences only when standard output is a terminal or the environment variable `FORCE_COLOR` is set, and never when `NO_COLOR` is set

## Brief report
- R117: When there are usage records, the brief report shall print a `usage` line as its first line with the number of prompts, the sum of `active_ms` in the format of R73 and `since <day>` with the earliest UTC day of the usage records as `YYYY-MM-DD`, and no other figures
- R118: When there are verdict records of kind `check`, the brief report shall print a `checks` line with the mark `✓` or `✗` of the latest result and the name of every check, and, for every check whose latest result is a fail, a line with its name and its latest detail
- R119: When there are verdict records of kind `test`, the brief report shall print a `tests` line with a bar of 20 cells, `█` for passes, `▓` for fails and `░` for skips of the latest run, and `<passes> pass`, followed by `<fails> fail` and `<skips> skip` when not zero, and a line for each of the first three failing test names, followed by a line `and <n> more` when more tests fail
- R126: When there are verdict records of kind `duration`, the brief report shall end the `checks` line with the time of the latest one named `checks` and the `tests` line with the time of the latest one named `tests`, each `result` read as seconds and written in the format of R73, and add no time to a line without such a record
- R121: When `.agents/backlog.md` has non-blank lines and there are records, the brief report shall print a `backlog` line with their count
- R122: When there is no usage record and no verdict record, the brief report shall print `no metrics yet` and exit with status 0
- R124: When there are usage records, the brief report shall print a `tokens` line, a `cost` line when price data is available and an `energy` line when model data is available, each with one block of `▁▂▃▄▅▆▇█` for every day of the window of R58, the highest day being `█`, a day with the value 0 `▁` and every other block at least `▂` and not lower than that of a smaller day, followed by the total over all records and, on the `tokens` line only, the share of each token type as `in <share> · out <share> · cache read <share> · cache write <share>` for input, output, cache read and cache write, a share being a percentage with one decimal from 1%, `<1%` below 1% and `0%` when the type has no tokens, and no other figure, the tokens of a day being the sum of the four token sums of R1 for that day, written in the formats of R72, R106 and R14
- R58: The window shall be the UTC days from the later of the first day of the usage records and 29 days before the latest day of the usage records, up to the latest day, so that it has at most 30 days
- R72: The brief report shall write a number of tokens below 1000 as a whole number, from 1000 with one decimal and `k`, and from 1000000 with one decimal and `M`
- R106: The reporter shall write a cost as `$` followed by the amount with one decimal
- R123: Every line of the brief report shall have a visible length of at most 100 characters, shortening a longer text with `…`

## Cost
- R8: The reporter shall print a `cost` line with the sum, in the format of R106, over all records and models in `models` of each token sum times the rate of its model
- R9: The rates of a model shall come from the entry of the price source whose `litellm_provider` is `anthropic` and whose key is the model id or else the model id without a trailing `-` and eight digits, using `input_cost_per_token`, `output_cost_per_token`, `cache_read_input_token_cost` and `cache_creation_input_token_cost`
- R10: When a model has tokens of a type without a rate, the reporter shall list its id in an `unpriced` line and leave all tokens of that model out of the cost
- R11: When no price data is available, the `cost` line shall say `unavailable` and show no amount
- R12: The reporter shall use a price cache younger than 7 days without fetching, and otherwise fetch the price source and store it in the price cache
- R13: If a fetch fails or the price source has no `anthropic` entry, then the reporter shall use the price cache if there is one, keep its prices and not fetch again within one hour of the failure

## Energy
- R14: When there are usage records and model data, the reporter shall print an `energy` line `about <energy> (minimum estimate)`, with the sum of R92 written in Wh with one decimal below 1000 Wh and from 1000 Wh in kWh with one decimal
- R92: The energy of a usage record shall be, for each model of its `models`, the output tokens of the model times the energy per output token that the EcoLogits method gives for the model, from its active parameters, its time to first token and tokens per second, the GPUs its total parameters need and the PUE of the data centre, with the minimum of the ranges, summed over all records and models; input, cache read and cache write tokens add none
- R93: The reporter shall find the model data of a model, among the entries whose provider is `anthropic`, by its id, by an alias of the model data, or by its id without a trailing `-` and eight digits
- R94: When a model has no entry in the model data, the reporter shall list its id in an `unmodelled` line and leave its tokens out of the energy
- R95: The reporter shall read the EcoLogits model data from the address in `AI_FOR_DUMMIES_MODELS_URL` or else from the EcoLogits repository and store it in the model data store
- R98: The reporter shall use a model data store younger than 7 days without fetching, otherwise fetch the model data, and if the fetch fails, keep using the older store
- R97: When no model data is available, the `energy` line shall say `unavailable` and show no amount

## Logging
- R23: When the logger runs inside a git repository with a kind, a name and a result, it shall append one verdict record whose fields equal the arguments, with the current UTC `time` as `YYYY-MM-DDTHH:MM:SSZ` and the fourth argument or an empty `detail`, as valid JSON for any text, print nothing and exit with status 0
- R100: When the logger gets a fifth argument, it shall add it to the verdict record as `source`
- R24: The logger shall write to the log of the main repository from a linked worktree, and if it runs outside a git repository or with fewer than three arguments, it shall exit with a non-zero status and write no log
- R25: When the QA run prints a check line, it shall append a verdict record of kind `check` with its check name, `pass` or `fail` and its detail
- R101: When the QA run logs a check, the verdict record shall have the path of the QA run, `.agents/hooks/qa.sh`, as `source`
- R26: When the QA run ran the tests, it shall append a verdict record of kind `test` for every test with `pass`, `fail` or `skip` and the same `detail` for all tests of the run, different from the `detail` of every earlier run
- R108: When the QA run ran the checks and the tests, it shall append a verdict record of kind `duration`, name `checks` and as `result` the whole seconds the checks took, and one with name `tests` and the whole seconds the test suite took
- R29: The skill `.agents/skills/metrics/SKILL.md` shall tell the agent to run `node .agents/metrics/metrics.mjs`

## Claude adapter
Token usage, time per prompt, tools, MCP servers and commands exist only in each agent's own session files, so an adapter turns the Claude Code session files of a repository into neutral usage records
Adapter: `.agents/metrics/adapters/claude.mjs`, an executable file run as `claude.mjs [repository]`. Repository: the argument, or the current directory, as an absolute path. Config directory: the value of `CLAUDE_CONFIG_DIR`, or `~/.claude` when it is not set. Session file: a `*.jsonl` file directly inside a project folder `<config directory>/projects/<name>`. Matching project folder: a project folder whose session entries record a working directory (`cwd`) that is the repository or a directory below it. Human prompt: a session entry of type `user` whose message content is text and that either has the `origin.kind` `human` or, from a non-interactive run, has the `entrypoint` `sdk-cli` and no `origin` and no `isMeta`. Prompt: a human prompt and every following entry of its session file, in file order, up to the next human prompt. Message: an `assistant` entry's `message.id`, which several entries can share. Tool call: a `tool_use` content block of an `assistant` entry, with an `id` and a `name`. Subagent file: `<session>/subagents/agent-*.jsonl` next to a session file, with a `.meta.json` file of the same name holding the `toolUseId` that launched it. Record: one JSON line per prompt
- R30: When the repository has session files with human prompts, the adapter shall print one record per human prompt on standard output, one JSON object per line, and exit with status 0
- R31: Each record shall have exactly the fields `agent` (the text `claude`), `session` (the session file name without `.jsonl`), `prompt` (the `promptId` of the human prompt), `start` (the timestamp of the human prompt), `wall_ms`, `active_ms`, `tokens`, `subagent_tokens`, `subagents`, `tools`, `mcp_servers`, `commands` and `models`
- R32: The `tokens` field shall hold the sums of `input_tokens` as `input`, `output_tokens` as `output`, `cache_read_input_tokens` as `cache_read` and `cache_creation_input_tokens` as `cache_write` over the distinct messages of the prompt, counting a message once however many entries carry it and counting zero for a message without usage
- R33: The `wall_ms` field shall be the milliseconds from the timestamp of the human prompt to the timestamp of the last `assistant` entry of the prompt, with millisecond precision
- R34: The `active_ms` field shall be the sum of `durationMs` of the `system` entries of subtype `turn_duration` in the prompt, or null when the prompt has none
- R35: The `tools` field shall count the tool calls of the prompt by tool name
- R36: The `mcp_servers` field shall count the tool calls of the prompt whose tool name is `mcp__<server>__<tool>` by `<server>`
- R37: The `commands` field shall list, in order, the command names found in `<command-name>` tags of the text of the human prompt
- R38: The `subagents` field shall count the subagent files whose `toolUseId` equals the id of a tool call in the prompt, and the `subagent_tokens` field shall hold the sums, in the form of R32, over the distinct messages of those subagent files
- R39: The adapter shall start no prompt at a `user` entry that is not a human prompt, including peer messages and local commands, and shall attribute no entry to a prompt that precedes the first human prompt of its session file
- R40: The adapter shall print the records in ascending order of `start`, across all session files
- R41: The adapter shall print no text of prompts, replies, thinking, tool inputs or tool results
- R42: The adapter shall read only the session files of matching project folders, and no session files of other directories, including directories whose path merely starts with the repository path
- R43: When `CLAUDE_CONFIG_DIR` is not set, the adapter shall read the session files under `~/.claude/projects`
- R44: If the config directory has no `projects` directory or no matching project folder, then the adapter shall print nothing on standard output and exit with status 0
- R45: If a session file has no human prompt, then the adapter shall print no record for it
- R46: If a line of a session file is not valid JSON, then the adapter shall ignore that line and print the records of the other lines
- R47: When the adapter gets a repository argument, it shall use that repository, relative or absolute, instead of the current directory
- R48: The `models` field shall hold, for each model id found in `message.model`, the sums in the form of R32 over the distinct messages of the prompt and of the subagent files counted in R38
- R49: A message without a `message.model` shall count under the model id `unknown`
- R50: The `models` field shall not list a model whose four sums are all zero

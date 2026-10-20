# Metrics
Users see what their agents spend, how long prompts take and which checks and tests fail, read straight from where the data already lives, without copying it

Log: the file `ai-for-dummies/metrics.jsonl` inside the common git directory of the repository. Verdict record: one JSON line in the log with `time`, `kind`, `name`, `result` and `detail`. Logger: `.agents/metrics/log.sh`, run as `sh log.sh <kind> <name> <result> [detail]`. Reporter: `.agents/metrics/metrics.mjs`, run as `node metrics.mjs [repository] [--html [file]]`. Adapter: an executable file in `.agents/metrics/adapters/`, run as `<adapter> <repository>`, that prints one usage record per line with the fields of R31. Price source: a JSON file in the format of LiteLLM's `model_prices_and_context_window.json`, at the URL in `AI_FOR_DUMMIES_PRICES_URL` (`http`, `https` or `file`) or the file of the LiteLLM repository. Price cache: `ai-for-dummies/prices.json` inside the common git directory. Model data: a JSON file in the format of `ecologits/data/models.json` of the EcoLogits repository. Model data store: `ai-for-dummies/ecologits.json` inside the common git directory. Dashboard: the HTML file the reporter writes with `--html`, by default `ai-for-dummies/dashboard.html` inside the common git directory

## Report
- R1: When adapters print usage records, the reporter shall print a `prompts` line with their count and the count per `agent`, `wall` and `active` lines with the sums of `wall_ms` and `active_ms` in the time format of R73 ignoring null values, a `tokens` line with the sums of `input`, `output`, `cache_read` and `cache_write` over `tokens` and `subagent_tokens`, and a `subagents` line with the sum of `subagents`, and exit with status 0
- R2: The reporter shall print `tools`, `mcp servers` and `commands` lines with the five most used names as `<name> <count>`, in descending order of count and then ascending order of name, and no such line when there is no name
- R3: The reporter shall print one line per check name as `<name> <passes> pass, <fails> fail`, a `tests` line `<passes> pass, <fails> fail, <skips> skip`, and, when a test failed, a `failing` line with the five most failed test names and their counts
- R4: When there is no usage record and no verdict record, the reporter shall print `no metrics yet` and exit with status 0
- R5: If an adapter exits with a non-zero status, then the reporter shall write the adapter name and its message on standard error and still report everything else
- R6: The reporter shall use the repository argument, relative or absolute, for the adapters and the log, and the current directory without one
- R7: The reporter shall print no text of prompts, replies or tool inputs

## Cost
- R8: The reporter shall print a `cost` line that starts with `$` and the sum, with one decimal, over all records and models in `models` of each token sum times the rate of its model
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
- R96: In the header of the energy column of the table of R69, the word `estimated` shall open, when clicked, a drop down `how is energy estimated` with a link to the EcoLogits source, whose text says that only output tokens count, that the parameters of the models are estimates and that the minimum estimate is used, with no browser hover text on the word
- R97: When no model data is available, the `energy` line shall say `unavailable` and show no amount, and every energy cell of the table shall show `-`

## Dashboard
- R17: When run with `--html`, the reporter shall write the dashboard to the given file or the default path, creating missing directories and replacing an existing file, print the path of the file and exit with status 0
- R18: The dashboard shall load nothing from the network
- R19: The dashboard shall show the top tools, MCP servers and commands, and the most failing tests of the report
- R21: The dashboard shall show names as text, so that markup in a name is not interpreted
- R22: When there is no usage record and no verdict record, the dashboard shall say `no metrics yet`
- R51: The dashboard shall contain every custom property of `.agents/metrics/tokens.css`, the design tokens, with its value
- R52: The checks table of R79 shall mark the box of a passed run with a check icon and the accessible label `pass`, and the box of a failed run with a different cross icon and the accessible label `fail`, each as well as with a color
- R53: The dashboard shall switch off its transitions when the reader prefers reduced motion
- R54: The dashboard shall start with a navbar that shows the name `AI for dummies 😵‍💫`, also when there are no records
- R55: The navbar shall show the short hash of the commit that `HEAD` of the repository points to, or `no commits yet` when the repository has no commit
- R56: The navbar shall show the time the dashboard was generated as `YYYY-MM-DD HH:MM UTC`
- R57: When there are usage records, the first section after the navbar shall be a usage section, an element with `data-chart` set to `usage`, with four charts in the order tokens, cost, time and prompts, each a `figure` with `data-figure` set to its name and a title naming it, the title of the cost chart being `estimated true cost`
- R58: The chart shall cover the UTC days from the later of the first day of the usage records and 29 days before the latest day of the usage records, up to the latest day, so that at most 30 days are shown
- R59: The usage charts shall have bars, elements with `data-series`, `data-day` and `data-value`, for every day of the window in ascending order: in the tokens chart for `cache_read`, `output` and `input_write` (input plus cache write tokens), each summed over `tokens` and `subagent_tokens`; in the cost chart for `cost`; in the time chart for `active` and `wall`, the sums of `active_ms` and `wall_ms`; and in the prompts chart for `prompts`, the number of usage records. A day without usage records has the value 0
- R60: Each chart shall use one scale for all its bars: the height of every bar is proportional to its value divided by the chart's top tick, a bar with the value 0 has no height, and the highest day of the chart reaches at least 40 % of the plot height
- R62: When no price data is available, the cost chart shall have no bar, its title shall say `unavailable`, and every cost cell of the table shall show `-`
- R63: The energy column of the table shall be headed `estimated energy`
- R64: Each chart shall have `role="img"` and an `aria-label` that names its title and the window
- R65: When there are no usage records, the dashboard shall show no usage chart and no table of R69
- R67: The dashboard shall have no page title heading and shall name the repository only in the navbar
- R68: Each bar shall carry its day, its series name (`estimated true cost` for the cost series) and its formatted value as tooltip text, as `<day> <series>: <value>`
- R69: Directly below the usage section, the dashboard shall show a table with one row for every day of the window in ascending order, followed by a `total` row, and the columns day, prompts, input tokens, output tokens, cache read tokens, cache write tokens, estimated true cost, estimated energy, active time and wall time. A day cell of a charted metric shall show exactly the value text of the tooltip of its bar, the other cells the formatted value of that day, and every total cell the sum of its column over the window in the same format
- R70: The table of R69 shall come before any other section after the chart section
- R71: Under the bars of every chart, the chart shall show one label per day of the window: the day of the month, preceded by the abbreviated English month name, as in `Oct 16`, on the first day of the window and on the first day of every month, and no other date text
- R72: The dashboard shall write a count or a number of tokens below 1000 as a whole number, from 1000 with one decimal and `k`, and from 1000000 with one decimal and `M`
- R73: The reporter and the dashboard shall write an active or wall time below 60 seconds as seconds with one decimal and `s`, below 60 minutes as minutes with one decimal and `min`, and from 60 minutes as hours with one decimal and `h`
- R74: The dashboard shall show usage figures only in the usage section and its table: no separate totals, no subagent count, no models table and no slowest prompts
- R79: When there are verdict records of kind `check`, the dashboard shall show a checks table with one row per check name in ascending order, with a box for each of its last 10 runs in ascending order of time, each carrying the day and the result of its run as tooltip text `<day> <result>`, and the day of the last fail or `-`, and no other column
- R102: The checks table of R79 shall show for each check the distinct `source` values of its verdict records in ascending order
- R103: The reporter and the dashboard shall count a verdict record of kind `check` only when its `source` names an existing file of the repository
- R80: When the repository has test components with a `requirements.md` in `.agents/tests/`, the dashboard shall show a coverage table with one row per component in ascending order, with a box for each requirement in ascending order of number, carrying `R<number>` as tooltip text, marked with a check icon and the accessible label `tested` when the number starts at least one test name and otherwise empty with the accessible label `untested`, and the number of tests, and no other column
- R81: When the repository has `.agents/scout.md`, the dashboard shall show a scout section with each of its sections, its `last checked` date and its items, each with its date, its name as a link to its URL that opens in a new tab, its verdict and its reason
- R82: Each chart shall have a linear y axis whose labels are 0 and the multiples of one step up to its top tick, written in the chart's format, with at most 5 steps and a top tick that is at least the highest value of the chart
- R83: A chart with two or more series shall have a legend with one button for each series, in the order of the series, that names the series next to a swatch of its color, and every bar of a series shall have that color
- R84: The navbar shall show the absolute path of the repository
- R85: The charts shall color their bars only with custom properties defined in the design tokens file `.agents/metrics/tokens.css`
- R104: All table cells of the dashboard shall have the same font size and the same padding
- R105: The dashboard shall end with a footer that shows `AI for dummies 😵‍💫` and a link to `https://github.com/fire-dragon-35/ai-for-dummies` that opens in a new tab, centered on the page, also when there are no records
- R106: The dashboard shall write a cost as `$` followed by the amount with one decimal, and an energy in the format of R14
- R107: The dashboard shall show all text in the system font of the device
- R109: The dashboard shall show `last run <time>`, in the format of R73, in the checks section for the latest verdict record of kind `duration` named `checks`, and in the coverage section for the latest one named `tests`
- R110: The coverage section of R80 shall come before the checks section of R79

## Logging
- R23: When the logger runs inside a git repository with a kind, a name and a result, it shall append one verdict record whose fields equal the arguments, with the current UTC `time` as `YYYY-MM-DDTHH:MM:SSZ` and the fourth argument or an empty `detail`, as valid JSON for any text, print nothing and exit with status 0
- R100: When the logger gets a fifth argument, it shall add it to the verdict record as `source`
- R24: The logger shall write to the log of the main repository from a linked worktree, and if it runs outside a git repository or with fewer than three arguments, it shall exit with a non-zero status and write no log
- R25: When the metrics and hooks are installed, the hooks shall append a verdict record of kind `check` for every check line with its check name, `pass` or `fail` and its detail
- R101: When the hooks log a check, the verdict record shall have the path of the hook that ran the check as `source`
- R26: When the metrics and hooks are installed, the pre-push hook shall append a verdict record of kind `test` for every test with `pass`, `fail` or `skip`
- R27: When the metrics and hooks are installed and the tests ran, the pre-push hook shall write the dashboard and print a line with a `file://` link to it with spaces written as `%20`, and if the dashboard cannot be written, keep its exit status
- R108: When the metrics and hooks are installed, the pre-commit hook shall append a verdict record of kind `duration`, name `checks` and as `result` the whole seconds the hook took, and the pre-push hook one with name `tests` and the whole seconds the test suite took
- R28: When the metrics are not installed, the hooks shall write no log and no dashboard
- R29: The skill `.agents/skills/metrics/SKILL.md` shall tell the agent to run `node .agents/metrics/metrics.mjs` and `node .agents/metrics/metrics.mjs --html`

## Claude adapter
Token usage, time per prompt, tools, MCP servers and commands exist only in each agent's own session files, so an adapter turns the Claude Code session files of a repository into neutral usage records
Adapter: `.agents/metrics/adapters/claude.mjs`, an executable file run as `claude.mjs [repository]`. Repository: the argument, or the current directory, as an absolute path. Config directory: the value of `CLAUDE_CONFIG_DIR`, or `~/.claude` when it is not set. Session file: a `*.jsonl` file directly inside a project folder `<config directory>/projects/<name>`. Matching project folder: a project folder whose session entries record a working directory (`cwd`) that is the repository or a directory below it. Human prompt: a session entry of type `user` whose message content is text and whose `origin.kind` is `human`. Prompt: a human prompt and every following entry of its session file, in file order, up to the next human prompt. Message: an `assistant` entry's `message.id`, which several entries can share. Tool call: a `tool_use` content block of an `assistant` entry, with an `id` and a `name`. Subagent file: `<session>/subagents/agent-*.jsonl` next to a session file, with a `.meta.json` file of the same name holding the `toolUseId` that launched it. Record: one JSON line per prompt
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
- R86: The usage charts shall show the bars of the series of a day side by side, and every chart shall have a legend row that holds no button when the chart has one series
- R87: When the dashboard is loaded, every legend button shall be pressed, shown by `aria-pressed` set to `true`, and every bar shall be visible
- R88: When a legend button is clicked, the chart shall hide the bars of its series and rescale the y axis and the heights of the visible bars to the remaining visible series, and when it is clicked again, show them again
- R89: When the last visible series of a chart is clicked, the chart shall keep it visible
- R90: When the pointer is over a bar, the dashboard shall show the tooltip text of R68 next to that bar
- R91: In the header of the estimated true cost column of the table of R69, the word `estimated` shall open, when clicked, a drop down `how is cost estimated` whose text states the token counts used, the rates with a link to their source, and the calculation of the cost from the four token types and their rates, with no browser hover text on the word, and no chart shall have a drop down

# Repository context
Agents read the repository map and the skills table instead of scanning the repository, so both must be complete and current

## Repository map
Depth: a directory at the repository root has depth 1, its subdirectories depth 2, and so on
- R1: When run inside a git repository, the generator shall write the map to `.agents/repository-context/directories.md` relative to the repository root and exit with status 0
- R2: The generator shall start the map with the line `# Repository structure` followed by an empty line
- R3: The generator shall list each file at the repository root as the line `<name>`
- R4: The generator shall list each directory of any depth as the line `<name>/`
- R5: The generator shall not list files below the repository root
- R6: The generator shall indent each entry by two spaces per enclosing directory
- R7: The generator shall not list paths ignored by git, including rules from nested `.gitignore` files
- R8: The generator shall list untracked paths that are not ignored
- R9: The generator shall not list the `.agents/` directory at the repository root or any path under it
- R10: When run from a subdirectory, the generator shall produce the same map as when run from the repository root
- R11: If run outside a git repository, then the generator shall write an error message to standard error, exit with a non-zero status and write no map
- R12: The generator shall place each directory's contents directly after it
- R13: The generator shall list directories named `.agents` that are not at the repository root
- R14: The generator shall not list the `.git` directory
- R15: The generator shall show each name exactly as in the file system, including spaces and non-ASCII characters
- R16: When the map already exists, the generator shall replace its content
- R17: If the repository has no listable paths, then the generator shall write only the header line and the empty line
- R18: The generator shall list a directory only when it contains, at any depth, a file that is not ignored by git
- R23: The generator shall order sibling entries by the byte order of their names

## Skills table
Skill: a directory in `.agents/skills/` that contains a `SKILL.md`. Block: the lines of `AGENTS.md` from a line that is exactly `<!-- ai-for-dummies:start -->` through the first line after it that is exactly `<!-- ai-for-dummies:end -->`, the end marker line. Skills table: the lines inside the block of `AGENTS.md` from a line that is exactly `## Skills` up to the end marker line. Generator: `.agents/repository-context/skills.sh`
- R19: When the generator runs in a repository whose `AGENTS.md` has the block, it shall make the block end with a skills table containing one row per skill with the `name` and `description` from its `SKILL.md` frontmatter and the path to its `SKILL.md` relative to the repository root
- R20: The generator shall change no line of `AGENTS.md` outside the skills table
- R21: When the generator runs in a repository whose `AGENTS.md` is missing or has no block, it shall change nothing and exit with status 0
- R22: The skills table in this repository's `AGENTS.md` shall equal what the generator produces for this repository

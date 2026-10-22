You review a Node.js web app for shared shopping lists that someone else wrote. Its code is in this directory. Read the code; do not change files, do not install packages and do not start the app.

Score each criterion from 1 (poor) to 10 (excellent), judging the code as a senior engineer would in a code review:
- correctness: the app does what a shopping list app with the documented JSON API needs, including edge cases
- structure: responsibilities are separated sensibly for the size of the app, without overengineering
- readability: names, flow and size of functions make the code easy to follow
- error handling: invalid input, missing data, file errors and failed requests are handled
- security: no injection, unescaped user content or unsafe file handling
- maintainability: the code is easy and safe to change, for example thanks to automated tests, small modules and no duplication

Answer with only one JSON object and nothing else, in this form:
{"correctness": {"score": 7, "note": "one sentence"}, "structure": {...}, "readability": {...}, "error handling": {...}, "security": {...}, "maintainability": {...}}

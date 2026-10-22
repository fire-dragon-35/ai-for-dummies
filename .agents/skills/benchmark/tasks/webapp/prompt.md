Build a web app for shared shopping lists in Node.js. You may use npm packages.

`npm install` and then `npm start` run it. It listens on the port in the environment variable `PORT` and stores its data in the JSON file named by the environment variable `DATA_FILE`.

The page at `/` lets users create and delete lists and, in a list, add items with a name and a quantity, check items off, edit them and delete them. The page uses this JSON API:

- `GET /api/lists` answers `[{id, name}]`
- `POST /api/lists` with `{name}` answers 201 and `{id, name}`
- `DELETE /api/lists/:id` answers 204
- `GET /api/lists/:id/items` answers `[{id, name, quantity, done}]`
- `POST /api/lists/:id/items` with `{name, quantity}` answers 201 and the item
- `PATCH /api/items/:id` with any of `{name, quantity, done}` answers the item
- `DELETE /api/items/:id` answers 204

Names must not be empty after trimming. The quantity is a positive whole number and is 1 when not given. Invalid input answers 400 and `{error}`, an unknown id answers 404 and `{error}`.

# Repository Guidelines

## Project Structure & Module Organization
- `app/` — Rails MVC and jobs: `controllers/`, `models/`, `views/`, `jobs/`.
- `config/` — environment, routes, and initializers. Credentials live in `config/credentials.yml.enc`.
- `db/` — migrations and schema; use Rails tasks to manage.
- `bin/` — project executables (e.g., `dev`, `rails`, `jobs`, `rubocop`, `brakeman`, `importmap`).
- `public/`, `storage/`, `log/`, `tmp/` — runtime assets and artifacts.
- Docs/utilities: `FACE_DETECTION.md`, `bin/detect_faces.swift`.

## Build, Test, and Development Commands
- `bin/setup` — install gems, prepare DB, and app setup.
- `bin/dev` — run app locally (server on `:4000`), Tailwind watcher, and Solid Queue jobs.
- `bin/rails db:prepare` — create/migrate DB for the current env.
- `bin/rubocop` — lint; add `-A` to auto-correct where safe.
- `bin/brakeman --no-pager` — security static analysis for Rails.
- `bin/importmap audit` — audit JS dependencies.
- `bin/rails server -p 4000` — run only the web server.

## Coding Style & Naming Conventions
- Ruby: 2-space indentation, no tabs; follow RuboCop Rails Omakase (`.rubocop.yml`).
- Files: `snake_case.rb`; Classes/Modules: `CamelCase`.
- Rails: follow conventional names/paths (`UsersController`, `app/views/users/...`).
- Prefer service objects or jobs for long-running or background work.

## Testing Guidelines
- Preferred: Minitest under `test/`, mirroring `app/` structure; name files `*_test.rb`.
- Run tests with `bin/rails test`. Add system tests for UI flows where applicable.
- Use fixtures or factories consistently; keep tests deterministic and fast.

## Commit & Pull Request Guidelines
- Use Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`.
  - Example: `feat: add face-only thumbnail generation`.
- PRs: include a clear summary, linked issues (e.g., `Closes #123`), and screenshots for UI changes.
- Ensure CI passes (Brakeman, Importmap audit, RuboCop) and DB migrations apply cleanly.

## Security & Configuration Tips
- Manage secrets via Rails credentials: `bin/rails credentials:edit`.
- Don’t commit `.env` or secrets; review `.gitignore`.
- Validate uploads and user input; prefer background jobs (`bin/jobs`) for heavy processing.

# Thread Export

Thread Export is a Rails pet project for turning a public Threads post into a
readable unrolled HTML page. The app accepts a Threads URL, fetches the page,
extracts the post chain, downloads attached images, renders a standalone page,
and updates the browser in real time through Turbo Streams.

The goal of the project is to demonstrate a small production-shaped Rails app:
background jobs, external page parsing, PostgreSQL persistence, generated file
lifecycle, WebSocket updates, and focused RSpec coverage.

## Features

- Submit a Threads post URL and track export status on a dedicated show page.
- Fetch Threads HTML with `Mechanize`.
- Parse Threads pagelets and JSON payloads with `Nokogiri`/Ruby JSON.
- Unroll extracted posts into a single generated HTML page.
- Download post images into the export directory and reference local copies.
- Download post videos and embed them with native HTML video controls.
- Run export work asynchronously with Sidekiq.
- Stream status changes and the generated page preview with Turbo Streams.
- Publish generated pages for a limited time, then unpublish and remove files.
- Use UUID primary keys for public export URLs.

## Stack

- Ruby on Rails 8
- PostgreSQL
- Redis + Sidekiq
- Hotwire: Turbo Streams
- Mechanize
- Nokogiri
- Dockerfile for production image builds
- RSpec

## Architecture

The main flow is intentionally split into small service objects:

- `ThreadExport` stores the submitted URL, status, generated path, post count,
  and publication state.
- `Threads::Fetcher` fetches the source page and image assets.
- `Threads::Extractor` parses pagelet HTML and falls back to embedded JSON when
  Threads changes the visible markup.
- `Threads::Renderer` writes `public/exports/<uuid>/index.html` and stores
  downloaded images under the same export directory.
- `ExportThreadJob` coordinates fetching, extraction, rendering, persistence,
  and Turbo Stream broadcasts.
- `UnpublishThreadExportJob` removes generated files after the publish window.

## Local Setup

Requirements:

- Ruby 3.2+
- PostgreSQL
- Redis

Create local databases and run migrations:

```bash
bundle install
bin/rails db:create db:migrate
```

Start Rails:

```bash
bin/rails server
```

Start Sidekiq in another terminal:

```bash
bundle exec sidekiq
```

Open:

```text
http://localhost:3000
```

Example URL:

```text
https://www.threads.com/@vitalifrance/post/DaLdoU7DEm1
```

## Docker Image

The repository includes a multi-stage `Dockerfile` for building a production
Rails image. It installs system dependencies, bundles gems, precompiles assets,
and runs the app as a non-root user.

Build the image:

```bash
docker build -t thread-export .
```

Run it against external PostgreSQL and Redis services:

```bash
docker run --rm -p 3000:3000 \
  -e RAILS_MASTER_KEY=... \
  -e SECRET_KEY_BASE=... \
  -e DATABASE_URL=postgres://user:password@host:5432/database \
  -e REDIS_URL=redis://host:6379/0 \
  thread-export
```

Sidekiq should be started from the same image with:

```bash
docker run --rm \
  -e RAILS_MASTER_KEY=... \
  -e SECRET_KEY_BASE=... \
  -e DATABASE_URL=postgres://user:password@host:5432/database \
  -e REDIS_URL=redis://host:6379/0 \
  thread-export bundle exec sidekiq -C config/sidekiq.yml
```

## Configuration

Database defaults are development-friendly and can be overridden with
environment variables:

```bash
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=thread_export
POSTGRES_PASSWORD=thread_export
POSTGRES_DB=thread_export_development
POSTGRES_TEST_DB=thread_export_test
```

Production uses:

```bash
DATABASE_URL=postgres://user:password@host:5432/database
REDIS_URL=redis://host:6379/0
```

## Tests

Run the full test suite:

```bash
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec
```

The specs cover:

- URL validation and UUID ids
- export job orchestration and Turbo broadcasts
- cleanup job behavior
- Threads HTML and JSON extraction paths
- generated HTML rendering
- status/show view behavior

## Notes

Threads markup can change without notice. The extractor is built with diagnostics
and a JSON fallback to make parser failures easier to investigate, but this kind
of scraper still needs maintenance when the source site changes.

Generated exports are plain files under `public/exports`. The app is designed so
that those files are temporary and can be removed safely after the export expires.

## Roadmap

- Add retry/backoff rules for transient Threads fetch failures.
- Add authenticated or rate-limited export creation.
- Move generated files to object storage for multi-server deployment.
- Add a deployment profile for a small VPS.

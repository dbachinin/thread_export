# Thread Export

Rails 8 application that fetches a Threads post URL, extracts the thread from
`data-pagelet="threads_post_page_1"`, unrolls posts into a single HTML page, and
publishes the download link through Turbo Streams.

## Run

```bash
docker compose up --build
```

Open http://localhost:3000 and submit a URL like:

```text
https://www.threads.com/@vitalifrance/post/DaLdoU7DEm1
```

The app runs four services:

- `web`: Rails server
- `sidekiq`: background export worker
- `redis`: Sidekiq and Action Cable backend
- `db`: PostgreSQL database

Exports are written under `public/exports/<id>/index.html`; downloaded images
are copied into the export folder and referenced from the generated HTML.

## Test

```bash
docker compose run --rm web bash -lc 'bundle install && export RAILS_ENV=test && ./bin/rails db:prepare && bundle exec rspec'
```

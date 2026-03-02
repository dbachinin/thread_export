require "rails_helper"

RSpec.describe ExportThreadJob, type: :job do
  it "exports a thread and broadcasts Turbo Stream status updates" do
    thread_export = ThreadExport.create!(source_url: "https://www.threads.com/@alice/post/root")
    page = instance_double(Mechanize::Page, body: "<html>threads</html>")
    post = Threads::Post.new(
      url: "https://www.threads.com/@alice/post/root",
      author: "alice",
      published_at: "2026-06-29T18:01:24.000Z",
      paragraphs: ["Hello"],
      images: []
    )
    extracted = Threads::ExtractedThread.new(
      source_url: thread_export.source_url,
      author: "alice",
      posts: [post]
    )

    fetcher = instance_double(Threads::Fetcher, fetch: page)
    extractor = instance_double(Threads::Extractor, call: extracted)
    renderer = instance_double(Threads::Renderer, call: "exports/#{thread_export.id}/index.html")

    allow(Threads::Fetcher).to receive(:new).and_return(fetcher)
    allow(Threads::Extractor).to receive(:new).with(page.body, thread_export.source_url).and_return(extractor)
    allow(Threads::Renderer).to receive(:new).with(thread_export, extracted).and_return(renderer)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)

    described_class.perform_now(thread_export)

    expect(thread_export.reload).to have_attributes(
      status: "finished",
      published: true,
      result_path: "exports/#{thread_export.id}/index.html",
      posts_count: 1
    )
    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).twice
  end
end

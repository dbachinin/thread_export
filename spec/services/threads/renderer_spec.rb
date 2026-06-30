require "rails_helper"

RSpec.describe Threads::Renderer do
  describe "#call" do
    it "renders a clean unroll without per-post source links" do
      thread_export = ThreadExport.create!(source_url: "https://www.threads.com/@alice/post/root")
      post = Threads::Post.new(
        url: "https://www.threads.com/@alice/post/continuation",
        author: "alice",
        published_at: "2026-06-29T18:01:24.000Z",
        paragraphs: ["First paragraph", "Second paragraph"],
        images: [],
        videos: []
      )
      extracted = Threads::ExtractedThread.new(
        source_url: thread_export.source_url,
        author: "alice",
        posts: [post]
      )

      result_path = described_class.new(thread_export, extracted).call
      html = Rails.root.join("public", result_path).read

      expect(html).to include("First paragraph")
      expect(html).not_to include("Пост 1")
      expect(html).not_to include(post.url)
    ensure
      FileUtils.rm_rf(Rails.root.join("public", "exports", thread_export&.id.to_s)) if thread_export&.id
    end

    it "downloads and embeds videos" do
      thread_export = ThreadExport.create!(source_url: "https://www.threads.com/@alice/post/root")
      post = Threads::Post.new(
        url: "https://www.threads.com/@alice/post/root",
        author: "alice",
        published_at: "2026-06-29T18:01:24.000Z",
        paragraphs: ["Video paragraph"],
        images: [],
        videos: [Threads::Video.new(url: "https://cdn.example/video.mp4", poster_url: nil, alt: "Demo video")]
      )
      extracted = Threads::ExtractedThread.new(
        source_url: thread_export.source_url,
        author: "alice",
        posts: [post]
      )
      fetcher = instance_double(Threads::Fetcher)
      response = instance_double(Mechanize::File, body: "video-bytes", response: { "content-type" => "video/mp4" })

      allow(fetcher).to receive(:download).with("https://cdn.example/video.mp4").and_return(response)

      result_path = described_class.new(thread_export, extracted, fetcher: fetcher).call
      html = Rails.root.join("public", result_path).read

      expect(html).to include("<video controls playsinline preload=\"metadata\"")
      expect(html).to include("<source src=\"assets/video-")
      expect(Rails.root.glob("public/exports/#{thread_export.id}/assets/video-*.mp4")).not_to be_empty
    ensure
      FileUtils.rm_rf(Rails.root.join("public", "exports", thread_export&.id.to_s)) if thread_export&.id
    end
  end
end

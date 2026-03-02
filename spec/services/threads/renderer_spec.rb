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
        images: []
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
  end
end

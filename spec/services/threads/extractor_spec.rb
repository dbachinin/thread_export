require "rails_helper"

RSpec.describe Threads::Extractor do
  let(:source_url) { "https://www.threads.com/@alice/post/root" }

  it "extracts posts, text, links and non-profile images from the Threads pagelet" do
    html = <<~HTML
      <main>
        <div data-pagelet="threads_post_page_1">
          <div data-pressable-container="true">
            <a href="/@alice"><span translate="no" dir="auto">alice</span></a>
            <a href="/@alice/post/one"><time datetime="2026-06-29T18:01:24.000Z"></time></a>
            <div class="x1a6qonq">
              <div><span dir="auto">First paragraph</span></div>
              <div><span dir="auto">Second paragraph</span></div>
            </div>
            <img width="36" height="36" alt="Profile photo alice" src="https://cdn.example/avatar.jpg">
            <img width="640" height="480" alt="Chart" src="https://cdn.example/chart.jpg">
          </div>
          <div data-pressable-container="true">
            <a href="/@alice"><span translate="no" dir="auto">alice</span></a>
            <a href="/@alice/post/two"><time datetime="2026-06-29T18:02:24.000Z"></time></a>
            <div class="x1a6qonq">
              <div><span dir="auto">Third paragraph</span></div>
            </div>
          </div>
        </div>
      </main>
    HTML

    extracted = described_class.new(html, source_url).call

    expect(extracted.author).to eq("alice")
    expect(extracted.posts.size).to eq(2)
    expect(extracted.posts.first.url).to eq("https://www.threads.com/@alice/post/one")
    expect(extracted.posts.first.paragraphs).to eq(["First paragraph", "Second paragraph"])
    expect(extracted.posts.first.images.map(&:url)).to eq(["https://cdn.example/chart.jpg"])
    expect(extracted.posts.second.paragraphs).to eq(["Third paragraph"])
  end

  it "raises when the Threads pagelet is missing" do
    expect { described_class.new("<html></html>", source_url).call }
      .to raise_error(/threads_post_page_1/)
  end

  it "normalizes binary HTML before diagnostics and parsing" do
    html = <<~HTML
      <html>
        <head><title>Threads</title></head>
        <body>
          <div data-pagelet="threads_post_page_1">
            <div data-pressable-container="true">
              <a href="/@alice"><span translate="no" dir="auto">alice</span></a>
              <a href="/@alice/post/root"><time datetime="2026-06-29T18:01:24.000Z"></time></a>
              <div class="x1a6qonq">
                <div><span dir="auto">Привет из бинарного body</span></div>
              </div>
            </div>
          </div>
        </body>
      </html>
    HTML
    html = html.b

    extracted = described_class.new(html, source_url).call

    expect(extracted.posts.first.paragraphs).to eq(["Привет из бинарного body"])
  end

  it "falls back to the ScheduledServerJS JSON payload when pagelets are missing" do
    payload = {
      "require" => [
        [
          "ScheduledServerJS",
          "handle",
          nil,
          [
            {
              "__bbox" => {
                "result" => {
                  "data" => {
                    "thread_items" => [
                      { "post" => json_post("root", "alice", "Root text\n\nSecond paragraph", 1_782_756_090, ["https://cdn.example/root.jpg"]) },
                      { "post" => json_post("second", "alice", "Continuation", 1_782_756_091) },
                      { "post" => json_post("reply", "bob", "A reply", 1_782_756_092) }
                    ]
                  }
                }
              }
            }
          ]
        ]
      ]
    }
    html = <<~HTML
      <html>
        <body>
          <script type="application/json">#{JSON.generate(payload)}</script>
        </body>
      </html>
    HTML

    extracted = described_class.new(html, "https://www.threads.com/@alice/post/root").call

    expect(extracted.posts.map(&:url)).to eq([
      "https://www.threads.com/@alice/post/root",
      "https://www.threads.com/@alice/post/second"
    ])
    expect(extracted.posts.first.paragraphs).to eq(["Root text", "Second paragraph"])
    expect(extracted.posts.first.images.map(&:url)).to eq(["https://cdn.example/root.jpg"])
  end

  def json_post(code, username, text, taken_at, image_urls = [])
    {
      "code" => code,
      "pk" => code,
      "taken_at" => taken_at,
      "user" => { "username" => username },
      "caption" => { "text" => text },
      "image_versions2" => { "candidates" => image_urls.map { |url| { "url" => url } } }
    }
  end
end

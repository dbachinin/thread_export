module Threads
  class Renderer
    EXPORT_ROOT = Rails.root.join("public", "exports")

    def initialize(thread_export, extracted_thread, fetcher: Fetcher.new)
      @thread_export = thread_export
      @thread = extracted_thread
      @fetcher = fetcher
      @export_dir = EXPORT_ROOT.join(@thread_export.id.to_s)
      @assets_dir = @export_dir.join("assets")
    end

    def call
      FileUtils.mkdir_p(@assets_dir)
      html = render_html
      File.write(@export_dir.join("index.html"), html)

      "exports/#{@thread_export.id}/index.html"
    end

    private

    def render_html
      downloaded = download_images
      ERB.new(template).result_with_hash(thread: @thread, downloaded: downloaded, generated_at: Time.current)
    end

    def download_images
      @thread.posts.each_with_object({}) do |post, index|
        index[post.object_id] = post.images.each_with_index.filter_map do |image, image_index|
          download_image(image, image_index)
        end
      end
    end

    def download_image(image, image_index)
      response = @fetcher.download(image.url)
      extension = extension_for(response, image.url)
      filename = "image-#{Digest::SHA256.hexdigest(image.url)[0, 16]}-#{image_index}#{extension}"
      target = @assets_dir.join(filename)
      File.binwrite(target, response.body)

      { path: "assets/#{filename}", alt: image.alt.presence || "Thread image" }
    rescue StandardError
      { path: image.url, alt: image.alt.presence || "Thread image" }
    end

    def extension_for(response, url)
      content_type = response.response["content-type"].to_s
      return ".png" if content_type.include?("png")
      return ".webp" if content_type.include?("webp")
      return ".gif" if content_type.include?("gif")

      File.extname(URI.parse(url).path).presence || ".jpg"
    end

    def template
      <<~HTML
        <!doctype html>
        <html lang="ru">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Unrolled Threads post</title>
          <style>
            body { margin: 0; font: 18px/1.6 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #171717; background: #f4f4f2; }
            main { max-width: 760px; margin: 0 auto; padding: 40px 20px 64px; background: #fff; min-height: 100vh; }
            header { border-bottom: 1px solid #ddd; margin-bottom: 28px; padding-bottom: 18px; }
            h1 { font-size: 28px; line-height: 1.2; margin: 0 0 8px; }
            .meta { color: #666; font-size: 14px; }
            article { margin: 0 0 34px; padding-bottom: 28px; border-bottom: 1px solid #e7e7e7; }
            article:last-child { border-bottom: 0; }
            p { margin: 0 0 16px; }
            .images { display: grid; gap: 12px; margin-top: 18px; }
            img { display: block; max-width: 100%; height: auto; border-radius: 8px; }
            a { color: #0b5cad; }
          </style>
        </head>
        <body>
          <main>
            <header>
              <h1>Unrolled Threads post</h1>
              <div class="meta">
                Автор: <%= ERB::Util.html_escape(thread.author || "unknown") %><br>
                Источник: <a href="<%= ERB::Util.html_escape(thread.source_url) %>"><%= ERB::Util.html_escape(thread.source_url) %></a><br>
                Сгенерировано: <%= ERB::Util.html_escape(generated_at.iso8601) %>
              </div>
            </header>

            <% thread.posts.each do |post| %>
              <article>
                <% post.paragraphs.each do |paragraph| %>
                  <p><%= ERB::Util.html_escape(paragraph) %></p>
                <% end %>

                <% if downloaded[post.object_id].present? %>
                  <div class="images">
                    <% downloaded[post.object_id].each do |image| %>
                      <img src="<%= ERB::Util.html_escape(image[:path]) %>" alt="<%= ERB::Util.html_escape(image[:alt]) %>">
                    <% end %>
                  </div>
                <% end %>
              </article>
            <% end %>
          </main>
        </body>
        </html>
      HTML
    end
  end
end

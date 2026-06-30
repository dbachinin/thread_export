module Threads
  class Renderer
    EXPORT_ROOT = Rails.root.join("public/exports")

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
      downloaded = download_media
      ERB.new(template)
        .result_with_hash(
          thread: @thread,
          downloaded: downloaded,
          generated_at: Time.current
        )
    end

    def download_media
      @thread.posts.each_with_object({}) do |post, index|
        index[post.object_id] = {
          images: download_images(post),
          videos: download_videos(post)
        }
      end
    end

    def download_images(post)
      post.images.each_with_index.filter_map do |image, image_index|
        download_asset(image.url, "image", image_index, image.alt.presence || "Thread image")
      end
    end

    def download_videos(post)
      post.videos.each_with_index.filter_map do |video, video_index|
        video_asset = download_asset(video.url, "video", video_index, 
          video.alt.presence || "Thread video")
        next unless video_asset

        poster_asset = download_poster(video.poster_url, video_index)
        video_asset.merge(poster: poster_asset&.fetch(:path, nil))
      end
    end

    def download_image(image, image_index)
      download_asset(image.url, "image", image_index, image.alt.presence || "Thread image")
    end

    def download_poster(url, index)
      return if url.blank?

      download_asset(url, "poster", index, "Video poster")
    end

    def download_asset(url, prefix, index, alt)
      response = @fetcher.download(url)
      extension = extension_for(response, url)
      filename = "#{prefix}-#{Digest::SHA256.hexdigest(url)[0, 16]}-#{index}#{extension}"
      target = @assets_dir.join(filename)
      File.binwrite(target, response.body)

      { path: "assets/#{filename}", alt: alt }
    rescue StandardError
      { path: url, alt: alt }
    end

    def extension_for(response, url)
      content_type = response.response["content-type"].to_s
      return ".mp4" if content_type.include?("mp4") || content_type.include?("video/")
      return ".png" if content_type.include?("png")
      return ".webp" if content_type.include?("webp")
      return ".gif" if content_type.include?("gif")

      extension = File.extname(URI.parse(url).path)
      return extension if extension.present?

      content_type.include?("video") ? ".mp4" : ".jpg"
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
            .media { display: grid; gap: 12px; margin-top: 18px; }
            img, video { display: block; width: 100%; max-width: 100%; height: auto; border-radius: 8px; background: #111; }
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

                <% if downloaded[post.object_id][:images].present? || downloaded[post.object_id][:videos].present? %>
                  <div class="media">
                    <% downloaded[post.object_id][:images].each do |image| %>
                      <img src="<%= ERB::Util.html_escape(image[:path]) %>" alt="<%= ERB::Util.html_escape(image[:alt]) %>">
                    <% end %>
                    <% downloaded[post.object_id][:videos].each do |video| %>
                      <video controls playsinline preload="metadata"<% if video[:poster].present? %> poster="<%= ERB::Util.html_escape(video[:poster]) %>"<% end %>>
                        <source src="<%= ERB::Util.html_escape(video[:path]) %>" type="video/mp4">
                      </video>
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

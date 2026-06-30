module Threads
  class Extractor
    THREAD_PAGELET = '[data-pagelet="threads_post_page_1"]'.freeze
    POST_LINK = 'a[href*="/post/"]'.freeze
    PROFILE_IMAGE = /\A(?:Фото профиля|Profile photo)/i

    def initialize(html, source_url)
      @html = normalize_html(html)
      @document = Nokogiri::HTML5(@html)
      @source_uri = URI.parse(source_url)
    end

    def call
      log_input_summary

      posts = extract_from_pagelets
      Rails.logger.info("[threads.extract] pagelet_posts=#{posts.size}")

      posts = extract_from_json_payload if posts.empty?
      Rails.logger.info("[threads.extract] final_posts=#{posts.size} author=#{posts.first&.author}") if posts.any?

      if posts.empty?
        Rails.logger.warn("[threads.extract] failed diagnostics=#{failure_diagnostics.inspect}")
        raise "Can't found block #{THREAD_PAGELET} or JSON payload Threads"
      end

      Threads::ExtractedThread.new(
        source_url: @source_uri.to_s,
        author: posts.first.author,
        posts: posts
      )
    end

    private

    def normalize_html(html)
      html.to_s.dup.force_encoding(Encoding::UTF_8).encode(
        Encoding::UTF_8,
        invalid: :replace,
        undef: :replace,
        replace: ""
      )
    end

    def log_input_summary
      Rails.logger.info(
        "[threads.extract] source=#{@source_uri} bytes=#{@html.bytesize} title=#{page_title.inspect} " \
        "pagelets=#{all_pagelet_names.inspect} app_json_scripts=#{json_script_count} " \
        "scheduled_server_js=#{@html.include?('ScheduledServerJS')} login=#{login_page?} challenge=#{challenge_page?}"
      )
    end

    def extract_from_pagelets
      Rails.logger.info(
        "[threads.extract.pagelets] selected=#{pagelet_nodes.map do |node|
          node['data-pagelet']
        end.inspect}"
      )

      pagelet_nodes.flat_map do |pagelet|
        nodes = post_nodes(pagelet)
        Rails.logger.info(
          "[threads.extract.pagelets] pagelet=#{pagelet['data-pagelet']} post_nodes=#{nodes.size} " \
          "text_preview=#{pagelet.text.squish.first(120).inspect}"
        )
        nodes.filter_map { |node| extract_post(node) }
      end.uniq { |post| post.url || post.paragraphs.join("\n") }
    end

    def pagelet_nodes
      @document.css("[data-pagelet]").select do |node|
        node["data-pagelet"].to_s.match?(/\Athreads_post_page_\d+\z/)
      end.sort_by { |node| node["data-pagelet"].to_s[/\d+\z/].to_i }
    end

    def post_nodes(pagelet)
      pagelet.css('[data-pressable-container="true"]').select do |node|
        node.at_css(POST_LINK) && node.at_css("time")
      end.uniq
    end

    def extract_post(node)
      post_url = absolute_url(node.at_css(POST_LINK)&.[]("href"))
      author = node.at_css('a[href^="/@"] span[translate="no"], a[href^="/@"] span[dir="auto"]')&.text&.squish
      published_at = node.at_css("time")&.[]("datetime")
      paragraphs = extract_paragraphs(node)
      images = extract_images(node)
      videos = extract_videos(node)

      return if paragraphs.empty? && images.empty? && videos.empty?

      Threads::Post.new(
        url: post_url,
        author: author,
        published_at: published_at,
        paragraphs: paragraphs,
        images: images,
        videos: videos
      )
    end

    def extract_paragraphs(node)
      text_container = node.at_css("div.x1a6qonq") || node
      paragraphs = text_container.css("div").filter_map do |div|
        next if div.css("svg, img, [role='button']").any?

        text = div.css('span[dir="auto"], a[role="link"]').map(&:text).join(" ").squish
        next if text.blank?
        next if chrome_text?(text)

        text
      end

      if paragraphs.empty?
        paragraphs = text_container.css('span[dir="auto"]').map do |span|
          span.text.squish
        end
      end
      paragraphs.reject { |text| chrome_text?(text) }.uniq
    end

    def extract_images(node)
      node.css("img[src]").filter_map do |image|
        src = image["src"]
        alt = image["alt"].to_s.squish
        next if src.blank?
        next if alt.match?(PROFILE_IMAGE)
        next if small_image?(image)

        Threads::Image.new(url: src, alt: alt)
      end.uniq
    end

    def extract_videos(node)
      node.css("video[src], video source[src]").filter_map do |video|
        url = video["src"]
        next if url.blank?

        video_node = video.name == "video" ? video : video.ancestors("video").first
        Threads::Video.new(
          url: url,
          poster_url: video_node&.[]("poster"),
          alt: "Thread video"
        )
      end.uniq
    end

    def small_image?(image)
      width = image["width"].to_i
      height = image["height"].to_i
      width.positive? && height.positive? && width <= 96 && height <= 96
    end

    def chrome_text?(text)
      text.in?(["Автор", "Поставить \"Нравится\"", "Комментировать", "Сделать репост",
"Поделиться", "Ещё"]) ||
        text.match?(/\A\d+[\s\u00a0]*(ч\.|мин\.|дн\.|нед\.)\z/)
    end

    def absolute_url(href)
      return if href.blank?

      URI.join("#{@source_uri.scheme}://#{@source_uri.host}", href).to_s
    end

    def extract_from_json_payload
      json_posts = json_post_hashes
      Rails.logger.info(
        "[threads.extract.json] raw_posts=#{json_posts.size} source_shortcode=#{source_shortcode.inspect} " \
        "source_username=#{source_username.inspect} first_codes=#{json_posts.first(8).map do |post|
          post['code']
        end.inspect}"
      )
      return [] if json_posts.empty?

      start_index = json_posts.index { |post| post["code"] == source_shortcode } || 0
      root_username = source_username || json_posts[start_index].dig("user", "username")

      posts = json_posts[start_index..].take_while do |post|
        post.dig("user", "username") == root_username
      end.filter_map { |post| build_json_post(post) }
      Rails.logger.info("[threads.extract.json] selected_posts=#{posts.size} root_username=#{root_username.inspect}")
      posts
    end

    def json_post_hashes
      posts = []
      parse_errors = 0
      walker = lambda do |value|
        case value
        when Hash
          posts << value["post"] if value["post"].is_a?(Hash)
          value.each_value { |child| walker.call(child) }
        when Array
          value.each { |child| walker.call(child) }
        end
      end

      @document.css('script[type="application/json"]').each do |script|
        walker.call(JSON.parse(script.text))
      rescue JSON::ParserError
        parse_errors += 1
        next
      end

      Rails.logger.info("[threads.extract.json] scripts=#{json_script_count} parse_errors=#{parse_errors}")
      posts.uniq { |post| post["pk"] || post["code"] }
    end

    def build_json_post(post)
      username = post.dig("user", "username")
      code = post["code"]
      paragraphs = json_paragraphs(post)
      images = json_images(post)
      videos = json_videos(post)
      return if paragraphs.empty? && images.empty? && videos.empty?

      Threads::Post.new(
        url: code.present? && username.present? ? absolute_url("/@#{username}/post/#{code}") : nil,
        author: username,
        published_at: json_published_at(post),
        paragraphs: paragraphs,
        images: images,
        videos: videos
      )
    end

    def json_paragraphs(post)
      text = post.dig("caption", "text").presence || json_text_fragments(post).join
      text.to_s.split(/\n{2,}/).map(&:squish).reject(&:blank?)
    end

    def json_text_fragments(post)
      post.dig("text_post_app_info", "text_fragments", "fragments").to_a.filter_map do |fragment|
        fragment["plaintext"]
      end
    end

    def json_images(post)
      media = post["carousel_media"].presence || [post]
      media.filter_map do |item|
        candidate = item.dig("image_versions2", "candidates").to_a.first
        url = candidate&.dig("url")
        next if url.blank?

        Threads::Image.new(url: url, alt: item["accessibility_caption"].to_s.squish)
      end.uniq
    end

    def json_videos(post)
      media = post["carousel_media"].presence || [post]
      media.filter_map do |item|
        url = video_url_from_json(item)
        next if url.blank?

        Threads::Video.new(
          url: url,
          poster_url: item.dig("image_versions2", "candidates").to_a.first&.dig("url"),
          alt: item["accessibility_caption"].to_s.squish.presence || "Thread video"
        )
      end.uniq
    end

    def video_url_from_json(item)
      item.dig("video_versions", 0, "url").presence ||
        item["video_url"].presence
    end

    def json_published_at(post)
      taken_at = post["taken_at"].to_i
      return if taken_at <= 0

      Time.at(taken_at).utc.iso8601
    end

    def source_username
      @source_uri.path[%r{\A/@([^/]+)/post/}, 1]
    end

    def source_shortcode
      @source_uri.path[%r{/post/([^/?#]+)}, 1]
    end

    def all_pagelet_names
      @document.css("[data-pagelet]").map { |node| node["data-pagelet"].to_s }.uniq
    end

    def json_script_count
      @document.css('script[type="application/json"]').size
    end

    def page_title
      @document.at_css("title")&.text&.squish
    end

    def login_page?
      @html.match?(/Log in|Войти|login|checkpoint/i)
    end

    def challenge_page?
      @html.match?(/challenge|Please wait|Подождите|captcha/i)
    end

    def failure_diagnostics
      {
        pagelets: all_pagelet_names,
        json_scripts: json_script_count,
        og_title: @document.at_css('meta[property="og:title"]')&.[]("content"),
        og_description_present: @document.at_css('meta[property="og:description"]')&.[]("content").present?,
        og_image_present: @document.at_css('meta[property="og:image"]')&.[]("content").present?,
        body_preview: @document.at_css("body")&.text&.squish&.first(500),
        html_preview: @html.to_s.squish.first(500)
      }
    end
  end
end

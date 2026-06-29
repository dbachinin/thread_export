module Threads
  class Fetcher
    USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " \
                 "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36".freeze
    CHROME_HEADERS = {
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
      "Accept-Language" => "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7",
      "Cache-Control" => "no-cache",
      "Pragma" => "no-cache",
      "Sec-Ch-Ua" => '"Google Chrome";v="126", "Chromium";v="126", "Not/A)Brand";v="99"',
      "Sec-Ch-Ua-Mobile" => "?0",
      "Sec-Ch-Ua-Platform" => '"Windows"',
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Site" => "none",
      "Sec-Fetch-User" => "?1",
      "Upgrade-Insecure-Requests" => "1"
    }.freeze

    def initialize(agent: Mechanize.new)
      @agent = agent
      @agent.user_agent = USER_AGENT
      @agent.request_headers = CHROME_HEADERS
      @agent.redirect_ok = true
      @agent.open_timeout = 15
      @agent.read_timeout = 30
    end

    def fetch(url)
      page = @agent.get(url)
      log_fetch(url, page)
      page
    end

    def download(url)
      @agent.get(url)
    end

    private

    def log_fetch(url, page)
      Rails.logger.info(
        "[threads.fetch] url=#{url} final_uri=#{page.uri} status=#{page.code} " \
        "content_type=#{page.response['content-type']} bytes=#{page.body.to_s.bytesize}"
      )
    end
  end
end

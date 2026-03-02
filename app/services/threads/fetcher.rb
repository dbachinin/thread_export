module Threads
  class Fetcher
    def initialize(agent: Mechanize.new)
      @agent = agent
    end

    def fetch(url)
      @agent.get(url)
    end

    def download(url)
      @agent.get(url)
    end
  end
end

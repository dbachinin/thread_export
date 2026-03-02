require "rails_helper"

RSpec.describe Threads::Fetcher do
  class FakeMechanizeAgent
    attr_reader :requested_url

    def get(url)
      @requested_url = url
      "page"
    end
  end

  describe "#fetch" do
    it "loads the requested page with Mechanize" do
      agent = FakeMechanizeAgent.new
      fetcher = described_class.new(agent:)

      page = fetcher.fetch("https://www.threads.com/@alice/post/root")

      expect(page).to eq("page")
      expect(agent.requested_url).to eq("https://www.threads.com/@alice/post/root")
    end
  end
end

require "rails_helper"

RSpec.describe Threads::Fetcher do
  class FakeMechanizeAgent
    attr_accessor :user_agent, :request_headers, :redirect_ok, :open_timeout, :read_timeout
  end

  describe "#initialize" do
    it "configures Mechanize to look like Google Chrome" do
      agent = FakeMechanizeAgent.new

      described_class.new(agent:)

      expect(agent.user_agent).to include("Google Chrome").or include("Chrome/")
      expect(agent.user_agent).to include("Windows NT 10.0")
      expect(agent.request_headers["Sec-Ch-Ua"]).to include("Google Chrome")
      expect(agent.request_headers["Sec-Ch-Ua-Platform"]).to eq('"Windows"')
      expect(agent.request_headers["Accept-Language"]).to include("ru-RU")
      expect(agent.request_headers["Upgrade-Insecure-Requests"]).to eq("1")
      expect(agent.redirect_ok).to be(true)
    end
  end
end

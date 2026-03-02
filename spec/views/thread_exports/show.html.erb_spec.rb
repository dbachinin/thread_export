require "rails_helper"

RSpec.describe "thread_exports/show", type: :view do
  it "renders a home link at the bottom" do
    assign(:thread_export, ThreadExport.create!(source_url: "https://www.threads.com/@alice/post/root"))

    render

    expect(rendered).to include('class="page-footer-nav"')
    expect(rendered).to include('href="/"')
    expect(rendered).to include(">Home</a>")
  end
end

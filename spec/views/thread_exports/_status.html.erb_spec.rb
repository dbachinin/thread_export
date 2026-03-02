require "rails_helper"

RSpec.describe "thread_exports/_status", type: :view do
  it "renders the generated page instead of a download button" do
    thread_export = ThreadExport.create!(
      source_url: "https://www.threads.com/@alice/post/root",
      status: "finished",
      published: true,
      posts_count: 2
    )
    thread_export.update!(result_path: "exports/#{thread_export.id}/index.html")

    render partial: "thread_exports/status", locals: { thread_export: thread_export }

    expect(rendered).to include("Extracted 2 posts")
    expect(rendered).to include('<iframe')
    expect(rendered).to include('class="export-preview"')
    expect(rendered).to include("src=\"/exports/#{thread_export.id}/index.html\"")
    expect(rendered).to include('class="export-page-link"')
    expect(rendered).to include("data-copy-text=\"http://test.host/exports/#{thread_export.id}/index.html\"")
    expect(rendered).to include("navigator.clipboard.writeText")
    expect(rendered).not_to include("data-controller")
    expect(rendered).not_to include("data-action")
    expect(rendered).not_to include("Download HTML")
    expect(rendered).not_to include("download=")
  end
end

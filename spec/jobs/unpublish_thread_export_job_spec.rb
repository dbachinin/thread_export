require "rails_helper"

RSpec.describe UnpublishThreadExportJob, type: :job do
  it "unpublishes old exports and removes generated files" do
    thread_export = ThreadExport.create!(
      source_url: "https://www.threads.com/@alice/post/root",
      status: "finished",
      published: true
    )
    thread_export.update!(result_path: "exports/#{thread_export.id}/index.html")
    thread_export.update_column(:created_at, 4.hours.ago)
    FileUtils.mkdir_p(thread_export.export_directory)
    File.write(thread_export.export_directory.join("index.html"), "<html></html>")

    described_class.new.perform(thread_export.id)

    expect(thread_export.reload).to have_attributes(published: false, result_path: nil)
    expect(thread_export.export_directory).not_to exist
  end

  it "does not unpublish exports younger than three hours" do
    thread_export = ThreadExport.create!(
      source_url: "https://www.threads.com/@alice/post/root",
      status: "finished",
      published: true
    )
    thread_export.update!(result_path: "exports/#{thread_export.id}/index.html")

    described_class.new.perform(thread_export.id)

    expect(thread_export.reload).to be_published
  end
end

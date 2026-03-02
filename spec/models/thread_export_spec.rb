require "rails_helper"

RSpec.describe ThreadExport, type: :model do
  it "accepts threads.com post URLs" do
    export = described_class.new(source_url: "https://www.threads.com/@vitalifrance/post/DaLdoU7DEm1")

    expect(export).to be_valid
  end

  it "uses UUID primary keys" do
    export = described_class.create!(source_url: "https://www.threads.com/@vitalifrance/post/DaLdoU7DEm1")

    expect(export.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
  end

  it "rejects non-Threads URLs" do
    export = described_class.new(source_url: "https://example.com/post/DaLdoU7DEm1")

    expect(export).not_to be_valid
    expect(export.errors[:source_url]).to be_present
  end

  it "builds a public download URL after rendering" do
    export = described_class.new(published: true, result_path: "exports/12/index.html")

    expect(export.download_url).to eq("/exports/12/index.html")
  end

  it "hides download URL for unpublished exports" do
    export = described_class.new(published: false, result_path: "exports/12/index.html")

    expect(export.download_url).to be_nil
  end
end

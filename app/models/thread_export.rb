class ThreadExport < ApplicationRecord
  STATUSES = %w[pending running finished failed].freeze

  validates :source_url, presence: true, format: { with: %r{\Ahttps://www\.threads\.(?:com|net)/@[^/]+/post/} }
  validates :status, inclusion: { in: STATUSES }

  def finished?
    status == "finished"
  end

  def failed?
    status == "failed"
  end

  def download_url
    return unless published? && result_path.present?

    "/#{result_path}"
  end

  def export_directory
    Rails.root.join("public", "exports", id.to_s)
  end
end

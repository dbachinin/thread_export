class UnpublishThreadExportJob
  include Sidekiq::Job

  sidekiq_options queue: :default

  def perform(thread_export_id)
    thread_export = ThreadExport.find_by(id: thread_export_id)
    return unless thread_export
    return if thread_export.created_at > 3.hours.ago

    FileUtils.rm_rf(thread_export.export_directory)
    thread_export.update!(published: false, result_path: nil)
  end
end

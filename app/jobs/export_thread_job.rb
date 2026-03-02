class ExportThreadJob < ApplicationJob
  include ActionView::RecordIdentifier

  queue_as :default

  def perform(thread_export)
    Rails.logger.info("[threads.export] id=#{thread_export.id} source_url=#{thread_export.source_url} status=start")
    broadcast(thread_export, "running")
    thread_export.update!(status: "running", error_message: nil)

    page = Threads::Fetcher.new.fetch(thread_export.source_url)
    extracted = Threads::Extractor.new(page.body, thread_export.source_url).call
    Rails.logger.info(
      "[threads.export] id=#{thread_export.id} extracted_posts=#{extracted.posts.size} author=#{extracted.author}"
    )
    result_path = Threads::Renderer.new(thread_export, extracted).call

    thread_export.update!(
      status: "finished",
      published: true,
      result_path: result_path,
      posts_count: extracted.posts.size
    )
    Rails.logger.info("[threads.export] id=#{thread_export.id} status=finished result_path=#{result_path}")
    broadcast(thread_export, "finished")
  rescue StandardError => e
    Rails.logger.error(
      "[threads.export] id=#{thread_export.id} status=failed error_class=#{e.class.name} message=#{e.message}"
    )
    thread_export.update!(status: "failed", error_message: e.message)
    broadcast(thread_export, "failed")
    raise
  end

  private

  def broadcast(thread_export, status)
    Turbo::StreamsChannel.broadcast_replace_to(
      thread_export,
      target: dom_id(thread_export, :status),
      partial: "thread_exports/status",
      locals: { thread_export: thread_export, transient_status: status }
    )
  end
end

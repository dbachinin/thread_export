class ThreadExportsController < ApplicationController
  def new
    @thread_export = ThreadExport.new
    @recent_exports = ThreadExport.order(created_at: :desc).limit(10)
  end

  def create
    @thread_export = ThreadExport.create!(thread_export_params)
    ExportThreadJob.perform_later(@thread_export)
    UnpublishThreadExportJob.perform_in(3.hours, @thread_export.id)

    redirect_to @thread_export
  rescue ActiveRecord::RecordInvalid => e
    @thread_export = e.record
    @recent_exports = ThreadExport.order(created_at: :desc).limit(10)
    render :new, status: :unprocessable_entity
  end

  def show
    @thread_export = ThreadExport.find(params[:id])
  end

  private

  def thread_export_params
    params.require(:thread_export).permit(:source_url)
  end
end

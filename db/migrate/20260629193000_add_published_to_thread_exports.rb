class AddPublishedToThreadExports < ActiveRecord::Migration[8.0]
  def change
    add_column :thread_exports, :published, :boolean, null: false, default: false
  end
end

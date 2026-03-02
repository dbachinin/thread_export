class CreateThreadExports < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pgcrypto"

    create_table :thread_exports, id: :uuid do |t|
      t.string :source_url, null: false
      t.string :status, null: false, default: "pending"
      t.string :result_path
      t.text :error_message
      t.integer :posts_count, null: false, default: 0

      t.timestamps
    end
  end
end

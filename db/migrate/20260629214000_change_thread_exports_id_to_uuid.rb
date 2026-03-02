class ChangeThreadExportsIdToUuid < ActiveRecord::Migration[8.0]
  def up
    enable_extension "pgcrypto"

    add_column :thread_exports, :uuid_id, :uuid, default: -> { "gen_random_uuid()" }, null: false
    execute "ALTER TABLE thread_exports DROP CONSTRAINT thread_exports_pkey"
    remove_column :thread_exports, :id
    rename_column :thread_exports, :uuid_id, :id
    execute "ALTER TABLE thread_exports ADD PRIMARY KEY (id)"
  end

  def down
    add_column :thread_exports, :integer_id, :bigserial, null: false
    execute "ALTER TABLE thread_exports DROP CONSTRAINT thread_exports_pkey"
    remove_column :thread_exports, :id
    rename_column :thread_exports, :integer_id, :id
    execute "ALTER TABLE thread_exports ADD PRIMARY KEY (id)"
  end
end

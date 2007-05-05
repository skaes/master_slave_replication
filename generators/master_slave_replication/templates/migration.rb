class <%= migration_name %> < ActiveRecord::Migration
  def self.up
    create_table :replication_check do |t|
      t.column :created_at, :timestamp
    end
  end

  def self.down
    remove_table :replication_check
  end
end

desc "delete old sync ids"

task :delete_old_sync_ids => :environment do
  # set the deletion interval for old sync ids in environment.rb, e.g.
  # MasterSlaveConnectionManager.old_sync_id_interval = 3600  # seconds
  MasterSlaveConnectionManager.instance.delete_old_sync_ids
end

class MasterSlaveReplicationGenerator < Rails::Generator::NamedBase
  def initialize(runtime_args, runtime_options = {})
    runtime_args.insert(0, 'add_master_slave_replication')
    super
  end

  def manifest
    record do |m|
      m.migration_template("migration.rb", 'db/migrate',
                           :assigns => { :migration_name => "MasterSlaveReplicationSetup"},
                           :migration_file_name => "master_slave_replication_setup"
                           )
    end
  end
end

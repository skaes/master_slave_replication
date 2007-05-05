unless $:.include?(File.dirname(__FILE__) + "/lib")
  $:.unshift(File.dirname(__FILE__) + "/lib")
end

require "master_slave_connection_manager"
require "rails_extensions_for_master_slave_replication"

ActiveRecord::Base.send :include, MasterSlaveReplication::ActiveRecord
ActionController::Base.send :include, MasterSlaveReplication::ActionController

CGI::Session::ActiveRecordStore::Session.exclude_from_synchronization
SqlSession.exclude_from_synchronization if defined?(SqlSessionStore)

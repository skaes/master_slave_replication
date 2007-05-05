unless $:.include?(File.dirname(__FILE__) + "/lib")
  $:.unshift(File.dirname(__FILE__) + "/lib")
end

require "master_slave_connection_manager"
require "rails_extensions_for_master_slave_replication"

ActiveRecord::Base.include MasterSlaveReplication::ActiveRecord
ActionController::Base.include MasterSlaveReplication::ActionController

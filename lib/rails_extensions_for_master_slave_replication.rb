module MasterSlaveReplication
  # extensions for ActiveRecord::Base
  module ActiveRecord
    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do
        for method in [:create, :update, :destroy]
          alias_method_chain method, :synchronization
        end
        class << self
          # don't need to alias :destroy_all as it gets called by destroy
          for method in [:update_all, :delete_all, :transaction]
            alias_method_chain method, :synchronization
          end
        end
      end
    end

    def create_with_synchronization
      self.class.connection_manager.insert_sync_id(create_without_synchronization)
    end

    def update_with_synchronization
      self.class.connection_manager.insert_sync_id(update_without_synchronization)
    end

    def destroy_with_synchronization
      self.class.connection_manager.insert_sync_id(destroy_without_synchronization)
    end

    module ClassMethods
      def connection_manager
        MasterSlaveConnectionManager.instance
      end

      def connection
        connection_manager.connection
      end

      def update_all_with_synchronization(updates, conditions = nil)
        connection_manager.insert_sync_id(update_all_without_synchronization(updates, conditions))
      end

      def delete_all_with_synchronization(conditions = nil)
        connection_manager.insert_sync_id(delete_all_without_synchronization(conditions))
      end

      def transaction_with_synchronization(*args)
        connection_manager.insert_sync_id
        transaction_without_synchronization(*args)
      end

      def with_slave_connection(&block)
        connection_manager.force_slave_connection(&block)
      end

      def with_master_connection(&block)
        connection_manager.force_master_connection(&block)
      end
    end
  end

  # extensions for ActionController::Base
  module ActionController
    def self.included(base)
      base.prepend_around_filter :synchronize_session
    end

    def synchronize_session
      # retrieve connection manager instance and set sync id from
      # session. if sync_id is nil, reads will all go to the slave
      # database. if sync_id is not nil, then the first read will
      # try to find the sync_id on the slave. if this fails, the
      # connection is switched to the master for all subsequent
      # queries.
      cmi = MasterSlaveConnectionManager.instance
      cmi.sync_id = session[:sync_id]
      begin
        yield
      ensure
        # make sure to save the current sync id in the session. the
        # connection manager sets its sync_id attribute to nil if it
        # finds it in the slave database. if the request doesn't
        # read from the database, the sync_id remains in the
        # session.
        session[:sync_id] = cmi.sync_id
        cmi.reset
      end
    end
  end

end

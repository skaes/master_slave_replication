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
          for method in [:connection, :update_all, :delete_all, :transaction]
            alias_method_chain method, :synchronization
          end
        end
      end
    end

    def create_with_synchronization
      self.class.connection_manager.synchronize(create_without_synchronization)
    end

    def update_with_synchronization
      self.class.connection_manager.synchronize(update_without_synchronization)
    end

    def destroy_with_synchronization
      self.class.connection_manager.synchronize(destroy_without_synchronization)
    end

    module ClassMethods
      def connection_manager
        MasterSlaveConnectionManager.instance
      end

      def connection_with_synchronization
        connection_manager.connection
      end

      def update_all_with_synchronization(updates, conditions = nil)
        connection_manager.synchronize(update_all_without_synchronization(updates, conditions))
      end

      def delete_all_with_synchronization(conditions = nil)
        connection_manager.synchronize(delete_all_without_synchronization(conditions))
      end

      def transaction_with_synchronization(*args)
        connection_manager.synchronize
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

__END__

# This software is released under the MIT license
#
# Copyright (c) 2007 Stefan Kaes

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

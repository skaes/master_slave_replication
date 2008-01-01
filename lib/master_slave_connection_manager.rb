# class ConnectionManager implements all DB logic for synchronized master/slave database setups
class MasterSlaveConnectionManager
  include Singleton

  # class to store the master DB connection
  class Master < ActiveRecord::Base
    abstract_class = true
  end

  # class to store the slave DB connection
  class Slave < ActiveRecord::Base
    abstract_class = true
  end

  attr_accessor :sync_id, :write_connection, :read_connection, :logger

  # sleep +synchronization_interval+ seconds before retrying
  @@synchronization_interval = 0.2
  cattr_accessor :synchronization_interval

  # check +synchronization_retries+ times whether +sync_id+ has
  # appeared in the slave database
  @@synchronization_retries = 3
  cattr_accessor :synchronization_retries

  # clean out sync_ids after +synchronization_cleanup_interval+
  # seconds. defaults to 1 day. setting this too low will cause
  # problems.
  @@synchronization_cleanup_interval = 60 * 60 * 24 # 1 day
  cattr_accessor :synchronization_cleanup_interval

  # use Rails magic to establish master/slave connections
  def initialize
    @logger = RAILS_DEFAULT_LOGGER
    # get default connection (master) and cache it
    Master.establish_connection RAILS_ENV
    @write_connection = Master.connection_without_synchronization
    # get connection to slave DB and store it on the abstract slave class
    begin
      slave_config = "#{RAILS_ENV}_slave".to_sym
      Slave.establish_connection slave_config
      @read_connection = Slave.connection_without_synchronization
    rescue ActiveRecord::AdapterNotSpecified
      # fall back to master if no slave given specified
      logger.warn "no slave database specified for configuration #{RAILS_ENV}, add #{slave_config}" if logger
      Slave.connection = @read_connection = @write_connection
    end
  end

  # reset current connection and sync_id
  def reset
    @connection = nil
    @sync_id = nil
  end

  # switch connection to master. insert new sync_id into replication
  # check table.
  def synchronize(result=nil)
    @connection = @write_connection
    @sync_id = @connection.insert("INSERT INTO replication_check (created_at) VALUES (NOW())")
    result
  end

  # lazy connection retrieval
  def connection
    @connection ||= @sync_id ? retrieve_connection : @read_connection
  end

  # check whether current +sync_id+ is in the slave database
  def synchronized?
    return true unless @sync_id
    quoted_sync_id = @sync_id.to_i
    @read_connection.select_value("SELECT true FROM replication_check WHERE id=#{quoted_sync_id}")
  end

  def retrieve_connection
    @@synchronization_retries.times do
      if synchronized?
        # when found, clear @sync_id so that it gets cleared from the
        # session in after part of the master slave setup filter on
        # the controller.
        @sync_id = nil
        return @read_connection
      else
        sleep @@synchronization_interval
      end
    end
    @write_connection
  end

  # force slave connection for the duration of a passed in block. this
  # bypasses all synchronization checks. dangerous, but useful for
  # querying stuff which doesn't need to be up to date, like full text
  # queries on the slave.
  def force_slave_connection(&block)
    current_connection = @connection
    @connection = @read_connection
    begin
      yield
    ensure
      @connection = current_connection
    end
  end

  # force master connection for the duration of a passed in block.
  def force_master_connection(&block)
    current_connection = @connection
    @connection = @write_connection
    begin
      yield
    ensure
      @connection = current_connection
    end
  end

  # clean up old sync_ids
  def delete_old_sync_ids
    @write_connection.execute "DELETE FROM replication_check WHERE updated_at < (now() - interval '#{@@synchronization_cleanup_interval} seconds')"
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

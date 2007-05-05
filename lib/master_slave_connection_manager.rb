# class ConnectionManager implements all DB logic for synchronized master/slave database setups
class MasterSlaveConnectionManager
  include Singleton

  # class to store the slave DB connection
  class Slave < ActiveRecord::Base
    abstract_class = true
  end

  attr_accessor :sync_id, :write_connection, :read_connection

  # sleep +synchronization_interval+ seconds before retrying
  @@synchronization_interval = 0.2
  cattr_accessor :synchronization_interval

  # check +synchronization_retries+ times whether +sync_id+ has appeared in the slave database
  @@synchronization_retries = 3
  cattr_accessor :synchronization_retries

  # clean out sync_ids after +old_sync_id_interval+ seconds. defaults to 1 day.
  # setting this too low will cause problems.
  @@sync_ids_clean_interval = 60 * 60 * 24 # 1 day
  cattr_accessor :sync_ids_clean_interval

  # use Rails magic to establish master/slave connections
  def initialize
    # get default connection (master) and cache it
    @write_connection = ActiveRecord::Base.connection
    # get connection to slave DB and store it on the abstract slave class
    Slave.establish_connection "#{RAILS_ENV}_slave".to_sym
    @read_connection = Slave.connection
  end

  # reset current connection and sync_id
  def reset
    @connection = nil
    @sync_id = nil
  end

  # switch connection to master and insert new sync_id into replication check table
  def insert_sync_id(result=nil)
    @connection = @write_connection
    @sync_id = @connection.insert("INSERT INTO replication_check ( created_at ) VALUES ( NOW() )")
    result
  end

  # lazy connection retrieval
  def connection
    @connection ||= @sync_id ? retrieve_connection : @read_connection
  end

  # check whether syn
  def sync_id_in_reader_db?
    return true unless @sync_id
    @read_connection.select_value("SELECT true FROM replication_check WHERE id=#{@sync_id}")
  end

  def retrieve_connection
    @@synchronization_retries.times do
      if sync_id_in_reader_db?
        # when found, clear @sync_id so that it gets cleared from the
        # session in the controller filter
        @sync_id = nil
        return @read_connection
      else
        sleep @@synchronization_interval
      end
    end
    @write_connection
  end

  # force slave connection
  def force_slave_connection(&block)
    current_connection = @connection
    @connection = @read_connection
    begin
      yield
    ensure
      @connection = current_connection
    end
  end

  # force master connection
  def force_slave_connection(&block)
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
    @write_connection.execute "DELETE FROM replication_check WHERE updated_at < (now() - interval '#{@@sync_ids_clean_interval} seconds')"
  end
end

# frozen_string_literal: true

require 'etc'
require 'extralite'

class ::Thread
  def __eno_connection__
    self[:__eno_connection__]
  end

  def __eno_checkout__
    Eno.checkout do |db|
      self[:__eno_connection__] = db
      yield db
    ensure
      self[:__eno_connection__] = nil
    end
  end
end

module Eno
  class << self
    attr_reader :default_connection_pool

    def reset_default_connection_pool
      @default_connection_pool = nil
    end

    def connect(*)
      @default_connection_pool = ConnectionPool.new(*)
    end

    def checkout(&)
      raise "No default connection defined" if !@default_connection_pool

      @default_connection_pool.checkout(&)
    end
  end

  class ConnectionPool
    WAIT_SLEEP_TIME = 0.01

    attr_reader :size, :max_size

    def initialize(fn, max_size: Etc.nprocessors)
      @fn = fn
      @max_size = max_size

      @lock = Mutex.new
      @size = 0
      @idle_connections = []
    end
  
    def checkout(&block)
      conn = acquire
      block[conn]
    ensure
      release(conn)
    end
  
    # Returns a connection to be used
    def acquire
      loop do
        @lock.synchronize do
          return @idle_connections.shift unless @idle_connections.empty?
  
          if @size < @max_size
            conn = Extralite::Database.new(@fn)
            @size += 1
            return conn
          end
        end
        sleep WAIT_SLEEP_TIME
      end
    end
  
    def release(conn)
      @lock.synchronize do
        @idle_connections << conn
      end
    end

    def checked_out_count
      @lock.synchronize do
        @size - @idle_connections.size
      end
    end

    def idle_count
      @lock.synchronize do
        @idle_connections.size
      end
    end
  end
end

# frozen_string_literal: true

require 'etc'
require 'extralite'

module Eno
  WAIT_SLEEP_TIME = 0.01

  class ConnectionPool
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

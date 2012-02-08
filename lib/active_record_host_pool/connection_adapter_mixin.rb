module ActiveRecordHostPool
  module DatabaseSwitch
    def self.included(base)
      base.class_eval do
        attr_accessor(:_host_pool_current_database)
        alias_method_chain :execute, :switching
        alias_method_chain :drop_database, :no_switching
        alias_method_chain :create_database, :no_switching
      end
    end

    def execute_with_switching(*args)
      if _host_pool_current_database && ! @_no_switch
        _switch_connection
      end
      execute_without_switching(*args)
    end

    def drop_database_with_no_switching(*args)
      begin
        @_no_switch = true
        drop_database_without_no_switching(*args)
      ensure
        @_no_switch = false
      end
    end

    def create_database_with_no_switching(*args)
      begin
        @_no_switch = true
        create_database_without_no_switching(*args)
      ensure
        @_no_switch = false
      end
    end

    private

    def _switch_connection
      if _host_pool_current_database && (_host_pool_current_database != @_cached_current_database)
        log("select_db #{_host_pool_current_database}", "SQL") do
          raw_connection.select_db(_host_pool_current_database)
        end
        @_cached_current_database = _host_pool_current_database
      end
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandler
      def establish_connection(name, spec)
        if @class_to_pool # AR 3.2
          @connection_pools[spec] ||= ActiveRecordHostPool::PoolProxy.new(spec)
          @class_to_pool[name] = @connection_pools[spec]
        else # AR 3.1 and lower
          @connection_pools[name] = ActiveRecordHostPool::PoolProxy.new(spec)
        end
      end
    end
  end
end

ActiveRecord::ConnectionAdapters::MysqlAdapter.class_eval { include ActiveRecordHostPool::DatabaseSwitch }

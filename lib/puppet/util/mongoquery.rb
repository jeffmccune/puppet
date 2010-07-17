require 'rubygems'
require 'mongo'

class Puppet::Util::MongoQuery
    include Singleton

    def initialize
        @connected = false
    end

    # Returns just hostnames matching the query
    def find_node_names(query)
        query(query, {:fields => ["hostname"]}).map{|result| result["hostname"]}
    end

    # Finds all about nodes matching query
    def find_nodes(query)
        query(query).to_a
    end

    private
    # Checks if we're connected, reconnect if needed
    def query(q, opts={})
        tries = 0

        begin
            connect unless connected?

            @coll.find(q, opts)
        rescue
            retries += 1

            if retries == 5
                raise Puppet::ParseError, "Failed to query Mongo after 5 attempts"
            end

            connect
            retry
        end
    end

    # Are we connected?
    def connected?
        begin
            return true if @connected && @dbh.connection.connected?
        rescue Exception => e
            Puppet.notice("Not connected to mongo db: #{e}")
            return false
        end
    end

    # Connect to mongodb
    def connect
        begin
            Puppet.notice("Creating new mongo db handle")
            @dbh = Mongo::Connection.new("localhost").db("puppet")
            @coll =@dbh.collection("nodes")

            @connected = true
        rescue Exception => e
            raise Puppet::ParseError, "Failed to connect to mongo db: #{e}"
        end
    end

end

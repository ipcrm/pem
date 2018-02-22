require "#{File.dirname(__FILE__)}/../pemlogger"

class Pem
    class Data
        attr_reader :name
        attr_reader :location
        attr_reader :versions
        attr_reader :prefix

        def initialize(name,pem,prefix=nil)
            @name     = name
            @prefix   = prefix
            @location = "#{pem.data_dir}/#{name}"
            @versions = {}
            @versions[:branches] = []
            @versions[:upload] = []

            setup
        end

        def setup
            PemLogger.logit("Creating data directory for #{@name}", :debug) unless Dir.exists?(@location)
            FileUtils.mkdir(@location) unless Dir.exist?(@location)
        end

    end
end
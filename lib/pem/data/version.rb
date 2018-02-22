require "#{File.dirname(__FILE__)}/../pemlogger"

class Pem
    class Data
        class Version
            attr_reader :version
            attr_reader :location
            attr_reader :type
            attr_reader :source

            def initialize(version, location, type, source, data_name)
                @version = version
                @location = location
                @type = type
                @module = modname
                @source = @type == 'upload' ? 'Upload' : source
            end
        end
    end
end
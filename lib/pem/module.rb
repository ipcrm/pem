require "#{File.dirname(__FILE__)}/../pemlogger"

class Pem
    class Module
        attr_reader :name
        attr_reader :location
        attr_reader :versions

        def initialize(name, pem)
            validate_name(name)
            @name  = name
            @location = "#{pem.conf['mod_dir']}/#{name}"
            @versions = []
            @pem = pem
            setup
            load_versions
        end

        def validate_name(name)
            if !name.include?('-') || (!name.count('-') == 1)
                err = "Module name: #{name} is not the correct format!  Must be <author>-<name>"
                PemLogger.logit(err, :fatal)
                raise(err)
            end
        end

        def setup
            PemLogger.logit("Creating module directory for #{name}", :debug) unless Dir.exists?(@location)
            FileUtils.mkdir(@location) unless Dir.exist?(@location)
        end

        # Get versions currently deployed
        def load_versions
            begin
                @versions = []
                mods = Pathname.new(@location).children.select(&:directory?)
          
                mods.each do |m|
                    if File.exists?("#{m}/.pemversion")
                        deets = YAML.safe_load(File.open("#{m}/.pemversion"),[Symbol])
                        @versions << Pem::Module::Version.new(deets['version'],deets['location'],deets['type'],deets['source'],@name)
                    else
                        PemLogger.logit("YAML not found for #{m}")
                    end
                end

                if @versions.length > 0
                    @pem.modules[name] = self
                end
              rescue StandardError => err
                PemLogger.logit(err, :fatal)
                raise(err)
             end
        end


        # Deploy a specific version
        def deploy_version(version,type,source,fh=nil)
            location = "#{@location}/#{version}"
            ver = Pem::Module::Version.new(version,location,type,source,@name)
            if !ver.is_deployed?
                ver.deploy(fh)
            end
            @versions << ver
            load_versions
        end

        # Delete specific version, pass in version object
        def delete_version(version)
            get_version(version).delete
            load_versions
        end

        # Get version 
        def get_version(version)
            @versions.each do |v|
                if v.version == version
                    return v
                end
            end
        end

        # Find forge modules and versions
        #
        # @param [String] search_string to use when looking up modules
        # @return [Hash] hash containing names and releases {'module_name' => [x.y.z, z.y.x]}
        def self.get_forge_modules(search_string)
            modules = {}

            unless search_string =~ /^\A[-\w.]*\z/
            raise 'Invalid search_string provided'
            end

            url = "https://forgeapi.puppetlabs.com/v3/modules?query=#{search_string}"
            r = RestClient.get url, accept: 'application/json', charset: 'utf-8'

            JSON.parse(r)['results'].each do |x|
            name = x['current_release']['metadata']['name'].tr('/', '-')
            versions = x['releases'].map { |y| y['version'] }

            modules[name] = versions
            end

            modules
        end


    end
end
require "#{File.dirname(__FILE__)}/../pemlogger"
require "#{File.dirname(__FILE__)}/utils/setup"

class Pem
    class Datamodule < Pem::Module
        attr_reader :name
        attr_reader :prefix
        attr_reader :location
        attr_reader :branches
        attr_reader :versions

        def initialize(name,prefix,pem)
            @name     = name
            @prefix   = prefix
            @location = "#{pem.conf['data_dir']}/#{name}"
            @branches = []
            @versions = []
            @pem = pem

            Pem::Utils::Setup.setupmod(@location,@name)
            global_metadata
        end

        def global_metadata
            File.open("#{@location}/.pemversion", 'w+') do |file|
                file.write({
                    'prefix'   => @prefix,
                }.to_yaml)
            end
        end

        # Deploy an uploaded version
        def deploy_upload(version,fh)
            location = "#{@location}/#{version}"
            ver = Pem::Datamodule::Version.new(version,location,'upload','Upload',@name,@prefix)
            if !ver.is_deployed?
                ver.deploy(fh)
            end
            @versions << ver
            load_versions
        end

        # Deploy a git version
        def deploy_git(branch,source)
            location = "#{@location}/#{branch}"

            # CHECKOUT NEEDS TO HAPPEN HERE
            Dir.mktmpdir do |dir|
                repo = Rugged::Repository.clone_at(source, dir)
                repo.checkout("origin/#{branch}")
                ref = repo.head.target_id
      
                # Set global version
                ver = ref
                location = "#{@location}/#{ref}"

                # If we are 'refreshing' and this commit is already checked out; do nothing
                if Dir.exists?(location)
                    PemLogger.logit("Version #{ref} for #{@name} already exists, skipping checkout!", :debug)
                else
                    ver = Pem::Datamodule::Version.new(ver,location,'git',source,@name,@prefix,branch)
                    ver.deploy(dir)
                end

                @versions << ver
                load_versions

                ver.class == String ? ver : ver.version
            end
        end

        # Get versions currently deployed
        def load_versions
            begin
                @versions = []
                mods = Pathname.new(@location).children.select(&:directory?)
          
                mods.each do |m|
                    if File.exists?("#{m}/.pemversion")
                        deets = YAML.safe_load(File.open("#{m}/.pemversion"),[Symbol])
                        @versions << Pem::Datamodule::Version.new(
                            deets['version'],
                            deets['location'],
                            deets['type'],
                            deets['source'],
                            @name,
                            deets['prefix'],
                            deets['branch'],
                        )
                    else
                        PemLogger.logit("YAML not found for #{m}")
                    end
                end

                if @versions.length > 0
                    @pem.datamodules[@name] = self
                end
              rescue StandardError => err
                PemLogger.logit(err, :fatal)
                raise(err)
             end
        end


    end
end
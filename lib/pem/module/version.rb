module Pem
  class Module
    class Version
      attr_reader :version
      attr_reader :location
      attr_reader :type
      attr_reader :source

      def initialize(version, location, type, source, modname)
        @version = version
        @location = location
        @type = type
        @module = modname
        @source = type == 'forge' ? "https://forge.puppet.com/#{@module.split('-').join('/')}" : source
      end

      def is_deployed?
        return Dir.exists?(@location) ? true : false
      end

      def deploy(fh)
        case @type
        when 'forge'
          deploy_forge_module
        when 'git'
          deploy_git_module
        when 'upload'
          deploy_uploaded_module(fh)
        end

        write_metadata
      end

      def write_metadata
        File.open("#{@location}/.pemversion", 'w+') do |file|
          file.write({
            'version'  => @version,
            'location' => @location,
            'type'     => @type,
            'source'   => @source,
          }.to_yaml)
        end
      end

      def deploy_uploaded_module(fh)
        PuppetForge::Unpacker.unpack(fh.path, @location, '/tmp')
        Pem::Logger.logit("deployment of #{@module} @ #{@version} succeeded")
      end
      
      def deploy_git_module
        begin
          repo = Rugged::Repository.clone_at(@source, @location)
          repo.checkout(@version)
        rescue Rugged::InvalidError => e
          # If this is an annotated tag, we have to parse it a bit different
          atag = repo.rev_parse(@version).target.oid
          repo.checkout(atag)
        end
        Pem::Logger.logit("#{@module} @ #{@version} checked out successfully from Git source #{@source}")
      end
      
      def deploy_forge_module
        PuppetForge.user_agent = 'pem/1.0.0'
      
        release_slug = "#{@module}-#{@version}"
        release_tarball = release_slug + '.tar.gz'
        release = PuppetForge::Release.find release_slug
     
        dir = Dir.mktmpdir

        Dir.chdir(dir) do
          release.download(Pathname(release_tarball))
          release.verify(Pathname(release_tarball))
          PuppetForge::Unpacker.unpack(release_tarball, @location, dir)
        end

        Pem::Logger.logit("deployment of #{@module} @ #{@version} from the PuppetForge has succeeded")
      end

      def delete
        Pem::Logger.logit("Purging module #{@module} @ #{@version}; location #{@location}", :debug)
        FileUtils.rm_rf(@location)
        Pem::Logger.logit("Successfully purged module #{@module} @ #{@version}")
      rescue StandardError => err
        Pem::Logger.logit(err,:fatal)
        raise(err)
      end
    end 
  end
end

module Pem
  class Datamodule
    class Version < Pem::Module::Version
      attr_reader :prefix
      attr_reader :branch

      def initialize(version, location, type, source, modname, prefix, branch=nil)
        super(version, location, type, source, modname)

        @prefix = prefix
        @branch = branch
      end

      def write_metadata
        File.open("#{@location}/.pemversion", 'w+') do |file|
          file.write({
            'version'  => @version,
            'location' => @location,
            'type'     => @type,
            'source'   => @source,
            'branch'   => @branch,
            'prefix'   => @prefix,
          }.to_yaml)
        end
      end

      def deploy(fh)
        case @type
        when 'git'
          deploy_git_module(fh)
        when 'upload'
          deploy_uploaded_module(fh)
        end

        write_metadata
      end

      def deploy_git_module(fh)
        FileUtils.cp_r(fh,@location) unless Dir.exist?(@location)
        Pem::Logger.logit("#{@module} @ #{@version} checked out successfully from Git source #{@source}")
      end

    end
  end
end

module Pem
  module Utils
    module Setup
      # Build global dirs
      #
      def self.setup(pem)
        Pem::Logger.logit('Running setup...',:debug)
        # Make sure dirs exist
        begin
          FileUtils.mkdir(pem.conf['basedir']) unless Dir.exist?(pem.conf['basedir'])
          FileUtils.mkdir(pem.conf['mod_dir']) unless Dir.exist?(pem.conf['mod_dir'])
          FileUtils.mkdir(pem.conf['data_dir']) unless Dir.exist?(pem.conf['data_dir'])
          FileUtils.mkdir(pem.conf['envdir'])  unless Dir.exist?(pem.conf['envdir'])
        rescue StandardError => err
          Pem::Logger.logit(err, :fatal)
          raise(err)
        end
      end

      def self.setupmod(location,name)
        Pem::Logger.logit("Creating module directory for #{name}", :debug) unless Dir.exists?(location)
        FileUtils.mkdir(location) unless Dir.exist?(location)
      end
    end
  end
end

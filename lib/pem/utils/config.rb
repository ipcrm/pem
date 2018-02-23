module Pem
  module Utils
    module Config
      # Load config or fail if there is missing stuff
      #
      # @return [Hash] Configuration hash
      #
      def self.load_config
        conf = YAML.load_file(File.expand_path('../../../config.yml', File.dirname(__FILE__)))

        unless %w[basedir master filesync_cert filesync_cert_key filesync_ca_cert].all? { |s| conf.key?(s) && !conf[s].nil? }
        Pem::Logger.logit('Missing required settings in config.yml',:fatal)
        raise
        end

        conf['envdir']  = "#{conf['basedir']}/environments"
        conf['mod_dir'] = "#{conf['basedir']}/modules"
        conf['data_dir'] = "#{conf['basedir']}/data"

        return conf
      rescue StandardError
        err = 'Missing config file, or required configuration values - check config.yml'
        Pem::Logger.logit(err, :fatal)
        raise(err)
      end
    end
  end
end

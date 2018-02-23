require "#{File.dirname(__FILE__)}/../pemlogger"

class Pem
  class Filesync
    def initialize(conf)
      @conf = conf
    end

    # Filesync handling
    #
    # This method commits changes to the staging code dir, force-syncs, and purges env caches on the master
    #
    def deploy
      PemLogger.logit('starting filesync deploy')

      verify_ssl = true
      if @conf['verify_ssl'] == false
        PemLogger.logit('SSL verification disabled in config.yml',:debug)
        verify_ssl = false
      end

      ssl_options = {
        'client_cert' => OpenSSL::X509::Certificate.new(File.read(@conf['filesync_cert'])),
        'client_key'  => OpenSSL::PKey::RSA.new(File.read(@conf['filesync_cert_key'])),
        'ca_file'     => @conf['filesync_ca_cert'],
        'verify'      => verify_ssl,
      }

      conn = Faraday.new(url: "https://#{@conf['master']}:8140", ssl: ssl_options) do |faraday|
      faraday.request :json
      faraday.options[:timeout] = 300
      faraday.adapter Faraday.default_adapter
      end

      # TODO: We should actually do some error handling here....
      PemLogger.logit('Hitting filesync commit endpoint', :debug)
      conn.post '/file-sync/v1/commit', 'commit-all' => true
      PemLogger.logit('Done.', :debug)

      PemLogger.logit('Hitting filesync force-sync endpoint', :debug)
      conn.post '/file-sync/v1/force-sync'
      PemLogger.logit('Done.', :debug)

      PemLogger.logit('Hitting puppetserver puppet-admin-api env endpoint', :debug)
      conn.delete '/puppet-admin-api/v1/environment-cache'
      PemLogger.logit('Done.', :debug)

      PemLogger.logit('completed filesync deploy')
    end
  end
end

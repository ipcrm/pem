module Pem
  class Filesync
    def initialize(conf)
      @conf = conf
    end

    # Filesync handling
    #
    # This method commits changes to the staging code dir, force-syncs, and purges env caches on the master
    #
    def deploy
      Pem::Logger.logit('starting filesync deploy')

      verify_ssl = true
      if @conf['verify_ssl'] == false
        Pem::Logger.logit('SSL verification disabled in config.yml',:debug)
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
      Pem::Logger.logit('Hitting filesync commit endpoint', :debug)
      conn.post '/file-sync/v1/commit', 'commit-all' => true
      Pem::Logger.logit('Done.', :debug)

      Pem::Logger.logit('Hitting filesync force-sync endpoint', :debug)
      conn.post '/file-sync/v1/force-sync'
      Pem::Logger.logit('Done.', :debug)

      Pem::Logger.logit('Hitting puppetserver puppet-admin-api env endpoint', :debug)
      conn.delete '/puppet-admin-api/v1/environment-cache'
      Pem::Logger.logit('Done.', :debug)

      Pem::Logger.logit('completed filesync deploy')
    end
  end
end

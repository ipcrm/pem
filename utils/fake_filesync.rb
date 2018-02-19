require 'sinatra/base'
require 'webrick'
require 'webrick/https'
require 'openssl'
require 'json'

CERT_PATH = '.'

webrick_options = {
  Port:             8140,
  Logger:           WEBrick::Log.new($stderr, WEBrick::Log::DEBUG),
  SSLEnable:        true,
  SSLVerifyClient: OpenSSL::SSL::VERIFY_NONE,
  SSLCertificate:  OpenSSL::X509::Certificate.new(File.open(File.join(CERT_PATH, 'server.crt')).read),
  SSLPrivateKey:   OpenSSL::PKey::RSA.new(File.open(File.join(CERT_PATH, 'server.key')).read),
  SSLCertName:     [%w[CN localhost]],
}

class MyServer < Sinatra::Base

  before do
    content_type 'application/json'
  end

  post '/file-sync/v1/commit' do
    status 200
    sleep(1)
    [].to_json
  end

  post '/file-sync/v1/force-sync' do
    status 200
    sleep(1)
    [].to_json
  end

  delete '/puppet-admin-api/v1/environment-cache' do
    status 200
    sleep(1)
    [].to_json
  end
end

Rack::Handler::WEBrick.run MyServer, webrick_options

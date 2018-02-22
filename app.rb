# frozen_string_literal: true

require 'sinatra'
require 'tempfile'
require "#{File.dirname(__FILE__)}/lib/pemlogger"
require "#{File.dirname(__FILE__)}/lib/pem"
require "#{File.dirname(__FILE__)}/lib/pemenv"
require "#{File.dirname(__FILE__)}/lib/pem/module"
require "#{File.dirname(__FILE__)}/lib/pem/module/version"

# Create Pem App

class PemApp < Sinatra::Base
  # Create a new PEM instance
  pem = Pem.new

  set :public_folder, 'pem_ui'

  get '/' do
    redirect '/index.html'
  end

  get %r{/assets/(.*)} do
    filename = params[:captures].first
    fullpath = "#{File.dirname(__FILE__)}/pem_ui/#{filename}"
    send_file fullpath
  end

  # List all envs
  #
  # Request
  #   GET /api/envs
  #
  # Response
  #   {
  #     "test6": {
  #       "concat": "4.1.1",
  #       "ntp": "6.4.1",
  #       "teamx": "ced1b6"
  #     }
  #   }
  get '/api/envs' do
    content_type 'application/json'
    pem.envs.to_json
  end

  # Deploy a global module
  #
  # Request
  #  POST /api/deploy_mod
  #  {
  #     "myorg-ntp": {
  #       "version": "e93a55d",
  #       "type": "git",
  #       "source": "https://github.com/ipcrm/ipcrm-ntp.git"
  #     }
  #  }
  #
  #  {
  #     "puppetlabs-concat":{
  #       "version": "4.1.0",
  #       "type": "forge"
  #      }
  #  }
  # Response
  #   {
  #     "status":"successful"
  #   }
  #
  post '/api/deploy_mod' do
    content_type 'application/json'
    data = JSON.parse(request.body.read)

    begin
      data.each do |m, v|
        pem.deploy_mod(m, v)
      end
      { 'status' => 'successful' }.to_json
    rescue StandardError
      { 'status' => 'failed' }.to_json
    end
  end

  # Create a data registration
  #
  # Request
  #  POST /api/create_data_registration
  #  {
  #     "common": {
  #       "version": "e93a55d",
  #       "type": "git",
  #       "source": "https://github.com/myorg/common.git"
  #     }
  #  }
  #
  # Response
  #   {
  #     "status":"successful"
  #   }
  #
  post '/api/create_data_reg' do
    content_type 'application/json'
    data = JSON.parse(request.body.read)

    begin
      ver = nil
      data.each do |m, v|
        ver = pem.create_data_reg(m, v)
      end
      { 'status' => 'successful','deployed_version' => ver }.to_json
    rescue StandardError
      { 'status' => 'failed' }.to_json
    end
  end

  # Create a new data registration
  #
  # The name must be in a specific format, <registration name>-<version>
  # Optionally, the data prefix can come after the name - and should probably be URL encoded
  #   - Example Request
  #       PUT /api/upload_data_reg/<name>-<version>/path%2Ffor%2Fprefix
  # The body of the request needs to be a tar gz file of the data @ version.
  #
  # Request
  #   PUT /api/upload_data_reg/common-0.0.1
  #     Binary (tar.gz file that results from tar'ing up directory with your data)
  # Response
  #  {"status":"successful"}
  #
  put '/api/upload_data_reg/*' do

    # Auto parsing of params fails us when we urlencode the prefix
    # so we are doing manually by flattening params into a string and then splitting
    # ourselves
    parsed_param = params[:splat].join('').split('/')
    
    # First split will be name of the module <name>-<version>
    first = parsed_param[0]

    # Second will collect everything from pos 1 and that will be the prefix
    second = parsed_param[1..-1].length == 0 ? nil : parsed_param[1..-1].join('/')
    
    name, version = first.split('-')
    prefix = second.nil? ? nil : second

    begin
      tf = Tempfile.new("#{params[:name]}.tar.gz")
      tf.write(request.body.read)
      ftype = `file --brief --mime-type #{tf.path}`.strip

      if ftype == 'application/x-gzip'
        data = { 'version' => version, 'file' => tf, 'type' => 'upload', 'prefix' => prefix }
        ver = pem.create_data_reg(name, data)
        { 'status' => 'successful', 'deployed_version' => ver }.to_json
      else
        { 'status' => 'failed', 'message' => 'Invalid archive supplied, expected a tar.gz file' }.to_json
      end
    rescue StandardError => e
      { 'status' => 'failed', 'message' => e }.to_json
    end
  end

  # Upload a global module from archive
  #
  # The :name must be in a specific format, <author>-<module name>-<version>
  # The body of the request needs to be a tar gz file of the module.
  # Typically this would be the result of building the archive via `puppet module build`
  #
  # Request
  #   PUT /api/upload_mod/example-ntp-0.0.3
  #     Binary (tar.gz file that results from puppet module build)
  # Response
  #  {"status":"successful"}
  #
  put '/api/upload_mod/:name' do
    if params[:name].count('-') == 2

      author, name, version = params[:name].chomp.split('-')

      begin
        tf = Tempfile.new("#{params[:name]}.tar.gz")
        tf.write(request.body.read)
        ftype = `file --brief --mime-type #{tf.path}`.strip

        if ftype == 'application/x-gzip'
          data = { 'version' => version, 'type' => 'upload', 'file' => tf }
          pem.deploy_mod("#{author}-#{name}", data)
          { 'status' => 'successful' }.to_json
        else
          { 'status' => 'failed', 'message' => 'Invalid archive supplied, expected a tar.gz file' }.to_json
        end
      rescue StandardError => e
        { 'status' => 'failed', 'message' => e }.to_json
      end

    else
      { 'status' => 'failed', 'message' => 'Invalid name supplied, expected <author>-<module_name>-<version>' }.to_json
    end
  end

  # Delete a global module
  #
  # Request
  #  POST /api/delete_mod
  #  {
  #     "myorg-ntp": {
  #       "version": "e93a55d"
  #     }
  #   }
  # Response
  #   {
  #     "status":"successful"
  #   }
  #   {
  #     "status":"failed", "envs": ["test3"]
  #   }
  #
  post '/api/purge_mod' do
    content_type 'application/json'
    data = JSON.parse(request.body.read)

    m = data.keys[0]
    v = data[m]['version']

    begin
      mod_status = pem.check_mod_use(m, v)
      if mod_status['status']
        { 'status' => 'failed', 'envs' => mod_status['envs'] }.to_json
      else
        pem.purge_mod(m, v['version'])
        { 'status' => 'successful' }.to_json
      end
    end
  end

  # Get global modules
  #
  # Request
  #   GET /api/modules
  # Response
  #  {
  #    "fake-module": [
  #      "0.5.0"
  #      "0.5.1"
  #      "0.7.3"
  #    ],
  #    "andulla-vsphere_conf": [
  #      "0.0.9"
  #    ],
  #    "mod-fake": [
  #      "d5f324",
  #      "ae54f3"
  #    ],
  #    "aristanetworks-netdev_stdlib_eos": [
  #      "1.2.0"
  #    ]
  #  }
  get '/api/modules' do
    content_type 'application/json'
    ret = {}
    pem.modules.each do |k,v|
      ret[k] = []
      v.versions.each do |y|
        ret[k] << y.version
      end
    end

    ret.to_json
  end

  get '/api/data_registrations' do
    content_type 'application/json'
    pem.data_registrations.to_json
  end

  # Create an environment
  #
  # Request
  #   POST /api/envs/testenv/create
  #   {
  #     "myorg-teamx": "ced1b64",
  #     "puppetlabs-ntp": "6.4.1",
  #     "puppetlabs-concat": "4.1.1"
  #   }
  # Response
  #   {
  #     "status":"successful"
  #   }
  post '/api/envs/:name/create' do
    content_type 'application/json'
    data = JSON.parse(request.body.read)
    e = PemEnv.new(params[:name], pem)

    begin
      e.deploy(data)
      { 'status' => 'successful' }.to_json
    rescue StandardError
      { 'status' => 'failed' }.to_json
    end
  end

  # Get modules for configured enviornment
  #
  # Request
  #   GET /api/envs/testenv/modules
  # Response
  #   {
  #     "concat": "4.1.1",
  #     "ntp": "6.4.1",
  #     "teamx": "ced1b6"
  #   }
  get '/api/envs/:name/modules' do
    content_type 'application/json'
    e = PemEnv.new(params[:name], pem)
    e.mods.to_json
  end

  # Compare two environments
  #
  # Request
  #   GET /api/envs/compare/:env1/:env2
  # Response
  #   {
  #     "diffs": {
  #       "puppetlabs-ntp": {
  #         "test6": "6.4.1",
  #         "test7": "6.4.4"
  #       }
  #     },
  #     "shared": {
  #       "puppetlabs-concat": "4.0.0",
  #     }
  #
  get '/api/envs/compare/:env1/:env2' do
    content_type 'application/json'
    pem.compare_envs(params[:env1], params[:env2]).to_json
  end

  # Find enviornment a module is deployed to
  #
  # Request
  #  get /api/find_mod_envs/:name/:version
  #
  # Response
  #   {
  #     "status": true, "envs": [ "test1", "test2" ]
  #   }
  get '/api/find_mod_envs/:name/:version' do
    content_type 'application/json'
    pem.find_module(params[:name], params[:version]).to_json
  end

  # Download copy of environment
  #
  # Request
  #   GET /api/envs/download/:name
  # Response
  #   application/octet-stream file in tar.gz format
  #
  get '/api/envs/:name/download' do
    tmpfile = pem.create_env_archive(params[:name])
    f = File.open(tmpfile.path, 'r+')
    send_file(f, filename: "#{params[:name]}.tar.gz", type: 'Application/octet-stream')
  end

  # Delete an environment
  #
  # Request
  #  POST /api/envs/delete
  #  {"env":"<name>"}
  #
  # Response
  #  {"status": "success"}
  #
  post '/api/envs/delete' do
    content_type 'application/json'

    begin
      data = JSON.parse(request.body.read)
      e = PemEnv.new(data['env'], pem)

      raise('Invalid env supplied!') if data['env'].nil?

      e.destroy(e.location)
      { 'status' => 'successful' }.to_json
    rescue StandardError => f
      PemLogger.logit(f)

      { 'status' => 'failed' }.to_json
    end
  end

  # Get forge modules and versions for the supplied search string
  #
  # Request
  #  GET /api/find_forge_mod/:search_string
  # Response
  #  {
  #     "puppetlabs-docker":["1.0.4","1.0.3","1.0.2","1.0.1","1.0.0"],
  #     ...
  #  }
  get '/api/find_forge_mod/:search_string' do
    content_type 'application/json'
    pem.get_forge_modules(params[:search_string]).to_json
  end

end

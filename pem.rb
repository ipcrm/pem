require 'yaml'
require 'logger'
require 'puppet_forge'
require 'rugged'
require 'pathname'
require 'sinatra'
require 'openssl'
require_relative 'pem_env'

class Pem
  attr_reader :conf
  attr_reader :logger
  attr_reader :envs

  def initialize(logger)
    @conf = YAML.load_file('config.yml')
    @conf['envdir']  = "#{@conf['basedir']}/environments"
    @conf['mod_dir'] = "#{@conf['basedir']}/modules"
    @logger = logger

    setup

    @envs = get_envs_details
  end

  #
  # Build global dirs
  #
  def setup
    @logger.debug('Pem::setup') {"entering pem::setup"}
    # Make sure dirs exist
    begin
      FileUtils.mkdir(@conf['basedir']) if not Dir.exists?(@conf['basedir'])
      FileUtils.mkdir(@conf['mod_dir']) if not Dir.exists?(@conf['mod_dir'])
      FileUtils.mkdir(@conf['envdir'])  if not Dir.exists?(@conf['envdir'])
    rescue => err
      Pem::log_error(err,@logger)
      raise(err)
    end
  end

  #
  # Deploy a module
  #
  def deploy_mod(name,data)
    @logger.debug('Pem::deploy_mod') {"pem::deploy_mod deploy #{name} starting"}

    # Require a <author>-<name> scheme so that we can have multiple modules of the same name
    if !name.include?('-') or !name.count('-') == 1
      err = "Module name: #{name} is not the correct format!  Must be <author>-<name>"
      Pem::log_error(err,@logger)
      raise(err)
    end

    case data['type']
    when 'forge'
      begin
        PuppetForge.user_agent = "pem/1.0.0"

        target_dir = "#{@conf['mod_dir']}/#{name}/#{data['version']}"
        moddir = "#{@conf['mod_dir']}/#{name}"

        FileUtils.mkdir(moddir) if not Dir.exists?(moddir)
        purge_mod(name,data['version']) if Dir.exists?(target_dir)

        release_slug = "#{name}-#{data['version']}"
        release_tarball = release_slug + ".tar.gz"

        release = PuppetForge::Release.find release_slug

        Dir.chdir('/tmp') do
          release.download(Pathname(release_tarball))
          release.verify(Pathname(release_tarball))
          PuppetForge::Unpacker.unpack(release_tarball, target_dir,'/tmp')
        end

        @logger.debug('Pem::deploy_mod') {"pem::deploy_mod deploy #{name} @ #{data['version']} succeeded"}
      rescue => err
        Pem::log_error(err,@logger)
        raise(err)
      end

    when 'git'
      begin
        target_dir = "#{@conf['mod_dir']}/#{name}/#{data['version']}"
        moddir = "#{@conf['mod_dir']}/#{name}"

        FileUtils.mkdir(moddir) if not Dir.exists?(moddir)
        purge_mod(name,data['version']) if Dir.exists?(target_dir)

        repo = Rugged::Repository.clone_at(data['source'], target_dir)
        repo.checkout(data['version'])
        @logger.debug('Pem::deploy_mod') {"#{name} @ #{data['version']} checked out successfully"}
      rescue => err
        Pem::log_error(err,@logger)
        raise(err)
      end
    end
  end

  #
  # Delete a module from global module dir
  #
  def purge_mod(name,version)
    target_dir = "#{@conf['mod_dir']}/#{name}/#{version}"

    @logger.debug('Pem::purge_mod') {"Purging module #{name} @ #{version}"}

    begin
      FileUtils.rm_rf(target_dir)
    rescue => err
      Pem::log_error(err,@logger)
      raise(err)
    end

    @logger.debug('Pem::purge_mod') {"Successfully purged module #{name} @ #{version}"}
  end

  #
  # Get all available versions of a given modules
  #
  def get_mod_versions(mod)
   versions = []

    Pathname.new(mod).children.select { |f| f.directory? }.each do |m|
      versions << m.basename.to_s
    end

    versions
  end

  #
  # Retrieve all global modules that have been deployed
  #
  def get_modules
    modules = {}

    begin
      mods = Pathname.new(@conf['mod_dir']).children.select { |c| c.directory? }

      mods.each do |m|
        modules[m.basename.to_s] = get_mod_versions(m)
      end
    rescue => err
      Pem::log_error(err,@logger)
      raise(err)
    end

    modules
  end


  #
  # Retrieve all envs
  #
  def get_envs
    begin
      return Pathname.new(@conf['envdir']).children.select { |e| e.directory? }.map { |e| e.basename.to_s }
    rescue => err
      Pem::log_error(err,@logger)
      raise(err)
    end
  end

  #
  # Retrieve all envs with details
  #
  def get_envs_details
    envs = {}
    get_envs.each do |e|
      z = Pem_env.new(e,self)
      envs[e] = z.get_mods
    end

    envs
  end

  #
  # Refresh @envs instance var with latest envs
  #
  def refresh_envs
    @envs = get_envs_details
  end

  #
  # Compare Envs
  #
  def compare_envs(env1,env2)
    diffs = {}
    e1 = @envs[env1]
    e2 = @envs[env2]

    uniq_mods = e1.keys - e2.keys | e2.keys - e1.keys
    shared_mods = ((e1.keys + e2.keys) - uniq_mods).uniq

    shared_mods.each do |s|
      if e1[s] != e2[s]
        diffs[s] = { env1 => e1[s], env2 => e2[s] }
      end
    end

    uniq_mods.each do |u|
      if e1.keys.include?(u)
        diffs[u] = { env1 => e1[u], env2 => false }
      elsif e2.keys.include?(u)
        diffs[u] = { env2 => e2[u], env1 => false }
      end
    end

    diffs
  end

  #
  # Filesync handling
  #
  def filesync_deploy(logger)
    @logger.debug('Pem::filesync_deploy') {"starting filesync deploy"}

    ssl_options = {
      'client_cert' => OpenSSL::X509::Certificate.new(File.read(@conf['filesync_cert'])),
      'client_key'  => OpenSSL::PKey::RSA.new(File.read(@conf['filesync_cert_key'])),
      'ca_file'     => @conf['filesync_ca_cert']
    }

    conn = Faraday.new(:url => "https://#{@conf['master']}:8140", ssl: ssl_options) do |faraday|
      faraday.request :json
      faraday.timeout 300
      faraday.adapter Faraday.default_adapter
    end

    conn.post   '/file-sync/v1/commit', { "commit-all" => true }
    @logger.debug('Pem::filesync_deploy') {"Hitting filesync commit endpoint..."}

    conn.post   '/file-sync/v1/force-sync'
    @logger.debug('Pem::filesync_deploy') {"Hitting filesync force-sync endpoint..."}

    conn.delete '/puppet-admin-api/v1/environment-cache'
    @logger.debug('Pem::filesync_deploy') {"Hitting puppet-admin-api env endpoint..."}

    @logger.debug('Pem::filesync_deploy') {"completed filesync deploy"}
  end

  #
  # Expose global error logging method
  #
  def self.log_error(err,logger)
    logger.fatal(caller_locations(1,1)[0].label) {"Caught exception; exiting"}
    logger.fatal("\n"+err.to_s)
  end
end

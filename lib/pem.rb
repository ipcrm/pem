# frozen_string_literal: true

require 'yaml'
require 'logger'
require 'puppet_forge'
require 'rugged'
require 'pathname'
require 'sinatra'
require 'openssl'
require "#{File.dirname(__FILE__)}/pemenv"

# PEM Main class
class Pem
  attr_reader :conf
  attr_reader :logger
  attr_reader :envs

  # Initialize
  #
  # @param logger Logger Object
  # @return PEM instance
  def initialize(logger)
    @logger = logger
    @conf = load_config

    setup

    @envs = envs_details
  end

  # Load config or fail if there is missing stuff
  #
  # @return [Hash] Configuration hash
  #
  def load_config
    conf = YAML.load_file('config.yml')

    unless %w[basedir master filesync_cert filesync_cert_key filesync_ca_cert].all? { |s| conf.key?(s) && !conf[s].nil? }
      Pem.log_error('Missing required settings in config.yml', @logger)
      raise
    end

    conf['envdir']  = "#{conf['basedir']}/environments"
    conf['mod_dir'] = "#{conf['basedir']}/modules"

    return conf
  rescue StandardError
    err = 'Missing config file, or required configuration values - check config.yml'
    Pem.log_error(err, @logger)
    raise(err)
  end

  # Determine if module and version is in use in any environment
  #
  # @param [String] name the name of the module
  #

  # Build global dirs
  #
  def setup
    @logger.debug('Pem::setup') { 'entering pem::setup' }
    # Make sure dirs exist
    begin
      FileUtils.mkdir(@conf['basedir']) unless Dir.exist?(@conf['basedir'])
      FileUtils.mkdir(@conf['mod_dir']) unless Dir.exist?(@conf['mod_dir'])
      FileUtils.mkdir(@conf['envdir'])  unless Dir.exist?(@conf['envdir'])
    rescue StandardError => err
      Pem.log_error(err, @logger)
      raise(err)
    end
  end

  # Deploy a module
  # @param [String] name the name of the module.  must be <author>-<name> format
  # @param [Hash] data a hash of all the info for deploying this module.  type: forge or git. version: forge module version or git hash
  def deploy_mod(name, data)
    @logger.debug('Pem::deploy_mod') { "pem::deploy_mod deploy #{name} starting" }

    # Require a <author>-<name> scheme so that we can have multiple modules of the same name
    if !name.include?('-') || (!name.count('-') == 1)
      err = "Module name: #{name} is not the correct format!  Must be <author>-<name>"
      Pem.log_error(err, @logger)
      raise(err)
    end

    case data['type']
    when 'forge'
      begin
        PuppetForge.user_agent = 'pem/1.0.0'

        tardir = "#{@conf['mod_dir']}/#{name}/#{data['version']}"
        moddir = "#{@conf['mod_dir']}/#{name}"

        FileUtils.mkdir(moddir) unless Dir.exist?(moddir)
        purge_mod(name, data['version']) if Dir.exist?(tardir)

        release_slug = "#{name}-#{data['version']}"
        release_tarball = release_slug + '.tar.gz'

        release = PuppetForge::Release.find release_slug

        Dir.chdir('/tmp') do
          release.download(Pathname(release_tarball))
          release.verify(Pathname(release_tarball))
          PuppetForge::Unpacker.unpack(release_tarball, tardir, '/tmp')
        end

        @logger.debug('Pem::deploy_mod') { "pem::deploy_mod deploy #{name} @ #{data['version']} succeeded" }
      rescue StandardError => err
        Pem.log_error(err, @logger)
        raise(err)
      end

    when 'git'
      begin
        tardir = "#{@conf['mod_dir']}/#{name}/#{data['version']}"
        moddir = "#{@conf['mod_dir']}/#{name}"

        FileUtils.mkdir(moddir) unless Dir.exist?(moddir)
        purge_mod(name, data['version']) if Dir.exist?(tardir)

        repo = Rugged::Repository.clone_at(data['source'], tardir)
        repo.checkout(data['version'])
        @logger.debug('Pem::deploy_mod') { "#{name} @ #{data['version']} checked out successfully" }
      rescue StandardError => err
        Pem.log_error(err, @logger)
        raise(err)
      end
    end
  end

  # Delete a module from global module dir
  #
  # @param [String] name the name of the module to delete
  # @param [String] version the name of the version to delete
  #
  def purge_mod(name, version)
    tardir = "#{@conf['mod_dir']}/#{name}/#{version}"

    @logger.debug('Pem::purge_mod') { "Purging module #{name} @ #{version}; location #{tardir}" }

    begin
      FileUtils.rm_rf(tardir)
    rescue StandardError => err
      Pem.log_error(err, @logger)
      raise(err)
    end

    @logger.debug('Pem::purge_mod') { "Successfully purged module #{name} @ #{version}" }
  end

  # Get all available versions of a given modules
  #
  # @param [String] mod the name of the module to return versions of
  # @return [Array] all available global versions of module supplied
  #
  def mod_versions(mod)
    versions = []

    Pathname.new(mod).children.select(&:directory?).each do |m|
      versions << m.basename.to_s
    end

    versions
  end

  # Retrieve all global modules that have been deployed
  #
  # @return [Hash] All deployed global modules, and the versions of each
  #
  def modules
    modules = {}

    begin
      mods = Pathname.new(@conf['mod_dir']).children.select(&:directory?)

      mods.each do |m|
        modules[m.basename.to_s] = mod_versions(m)
      end
    rescue StandardError => err
      Pem.log_error(err, @logger)
      raise(err)
    end

    modules
  end

  # Retrieve all envs
  #
  # @return [Array] A list of all deployed environment names
  def show_envs
    return Pathname.new(@conf['envdir']).children.select(&:directory?).map { |e| e.basename.to_s }
  rescue StandardError => err
    Pem.log_error(err, @logger)
    raise(err)
  end

  # Retrieve all envs with details
  #
  # @return [Hash] all deployed environments and the modules (including versions) that have been deployed
  #
  def envs_details
    current_envs = {}
    show_envs.each do |e|
      z = PemEnv.new(e, self)
      current_envs[e] = z.mods
    end

    current_envs
  end

  # Refresh @envs instance var with latest envs
  #
  def refresh_envs
    @envs = envs_details
  end

  # Compare Envs
  #
  # @param [String] env1 Name of the first environment to compare the second two
  # @param [String] env2 Name of the second environment to compare to the first
  # @return [Hash] a listing of all modules with differences in the format of 'name' => ['env1' => <version, 'env2' => version]
  def compare_envs(env1, env2)
    diffs = {}
    e1 = @envs[env1]
    e2 = @envs[env2]

    uniq_mods = e1.keys - e2.keys | e2.keys - e1.keys
    shared_mods = ((e1.keys + e2.keys) - uniq_mods).uniq

    shared_mods.each do |s|
      diffs[s] = { env1 => e1[s], env2 => e2[s] } if e1[s] != e2[s]
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

  # Filesync handling
  #
  # This method commits changes to the staging code dir, force-syncs, and purges env caches on the master
  #
  def filesync_deploy
    @logger.debug('Pem::filesync_deploy') { 'starting filesync deploy' }

    ssl_options = {
      'client_cert' => OpenSSL::X509::Certificate.new(File.read(@conf['filesync_cert'])),
      'client_key'  => OpenSSL::PKey::RSA.new(File.read(@conf['filesync_cert_key'])),
      'ca_file'     => @conf['filesync_ca_cert'],
    }

    conn = Faraday.new(url: "https://#{@conf['master']}:8140", ssl: ssl_options) do |faraday|
      faraday.request :json
      faraday.options[:timeout] = 300
      faraday.adapter Faraday.default_adapter
    end

    conn.post '/file-sync/v1/commit', 'commit-all' => true
    @logger.debug('Pem::filesync_deploy') { 'Hitting filesync commit endpoint...' }

    conn.post '/file-sync/v1/force-sync'
    @logger.debug('Pem::filesync_deploy') { 'Hitting filesync force-sync endpoint...' }

    conn.delete '/puppet-admin-api/v1/environment-cache'
    @logger.debug('Pem::filesync_deploy') { 'Hitting puppet-admin-api env endpoint...' }

    @logger.debug('Pem::filesync_deploy') { 'completed filesync deploy' }
  end

  # Expose global error logging method
  #
  # @param [String] err messsage to be printed
  # @param logger logger object to print to
  def self.log_error(err, logger)
    logger.fatal(caller_locations(1, 1)[0].label) { 'Caught exception; exiting' }
    logger.fatal("\n" + err.to_s)
  end
end

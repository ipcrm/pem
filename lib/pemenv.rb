# frozen_string_literal: true

require 'yaml'
require 'logger'
require 'puppet_forge'
require 'rugged'
require 'pathname'
require 'json'
require 'r10k/puppetfile'
require "#{File.dirname(__FILE__)}/pemlogger"

# Class for managing all enviornment related activities
class PemEnv
  attr_reader :location

  # Initialize
  #
  # @param [String] name the name of the new env
  # @param [Object] pem an existing Pem object
  def initialize(name, pem)
    @conf     = pem.conf
    @location = "#{@conf['envdir']}/#{name}"
    @pem      = pem
  end

  # Set permissions on environment location
  #
  # Use to chown_R on the environment location
  #
  def set_owner
    user =  @conf['user'] || Process.uid
    group = @conf['group'] || Process.gid

    begin
      FileUtils.chown_R(user, group, @location)
    rescue StandardError => err
      Pemlogger.logit(err, :fatal)
      raise(err)
    end
  end

  # Deploy a new environment, or remove and redeploy an environment
  #
  # @param [Hash] modules a hash of modules to deploy into the new environment,
  #   format {'name' => 'version'} where version must be from the global module repository
  #
  def deploy(modules)
    if File.directory?(@location)
      begin
        PemLogger.logit("Redeploying #{@location}")
        destroy(@location, @logger)
        deploy(modules)
      rescue StandardError => err
        PemLogger.logit(err, :fatal)
        raise(err)
      end
    else
      begin
        PemLogger.logit("Creating #{@location}", :debug)
        FileUtils.mkdir(@location)
        FileUtils.mkdir("#{@location}/modules")

        modules.each do |n, m|
          PemLogger.logit("Deploying module #{n} @ version #{m}", :debug)
          deploy_mod(n, m, "#{@location}/modules")
          PemLogger.logit("Deploying module succeedded!", :debug)
        end

        # TODO: Need to add environment.conf setup

        set_owner
        @pem.filesync_deploy
        PemLogger.logit("Successfully created #{@location}!")
      rescue StandardError => err
        PemLogger.logit(err, :fatal)
        raise(err)
      end
    end

    @pem.refresh_envs
  end

  # Deploy a module from global modules into this env
  #
  # @param [String] name the name of the module to deploy
  # @param [String] version the version string (from a global module) to deploy
  # @param [String] location the location of environment to deploy to (will be set in pemenv instance)
  #
  def deploy_mod(name, version, location)
    mod_name = name.split('-')[1]

    begin
      amods = @pem.modules
      if amods.keys.include?(name) && amods[name].include?(version)
        FileUtils.cp_r("#{@conf['mod_dir']}/#{name}/#{version}", "#{location}/#{mod_name}")
        File.open("#{location}/#{mod_name}/.pemversion", 'w+') do |file|
          file.write({ 'version' => version, 'name' => name }.to_yaml)
        end
      else
        err = "Unkown module or version supplied for #{name} @ #{version} "
        PemLogger.logit(err, :fatal)
        throw(err)
      end
    rescue StandardError => err
      PemLogger.logit(err, :fatal)
      raise(err)
    end
  end

  # Determine the installed modules (and versions) in this env
  #
  # @return [Hash] a hash of all installed modules to this env, in the format {'modname' => 'version', 'modname' => 'version'}
  #
  def mods
    rmods = {}
    begin
      mods = Pathname.new("#{@location}/modules").children.select(&:directory?)
      mods.each do |m|
        md = mod_details(m.basename.to_s)
        rmods[ md['name'] ] = md['version']
      end
    rescue StandardError => err
      PemLogger.logit(err, :fatal)
      raise(err)
    end

    rmods
  end

  # Load puppetfile mods (temp method)
  #
  # Currently this method is a shim to allow easy conversion of existing environments managed by r10k
  #
  # @return [Hash] a hash of all deployed modules and their current versions in format {'modname' => 'version', ...}
  #
  def load_puppetfile_mods
    mods = {}
    puppetfile = R10K::Puppetfile.new(@location)

    begin
      modules = puppetfile.modules
      modules.each do |mod|
        mods[mod.name] = if mod.is_a? R10K::Module::Forge
                           mod.expected_version
                         else
                           mod.version
                         end
      end
    rescue StandardError => err
      PemLogger.logit(err, :fatal)
      raise(err) unless puppetfile.load
    end

    mods
  end

  # Get version for deployed module in this env
  #
  # @param [String] mod the name of the module to check version of
  # @return [String] the version string of the deployed version
  #
  def mod_details(mod)
    deets = YAML.safe_load(File.open("#{@location}/modules/#{mod}/.pemversion"))
    return { 'version' => deets['version'], 'name' => deets['name'] }
  rescue StandardError => err
    PemLogger.logit(err, :fatal)
    raise(err)
  end

  # Purge environment from staging if present, commit filesync
  #
  # @param [String] location the location of the environment to be purged
  # @param [Object] logger the logger object to write messages to
  #
  def destroy(location)
    begin
      PemLogger.logit("Removing #{location}")
      FileUtils.rm_rf(location)
    rescue StandardError => err
      PemLogger.logit(err, :fatal)
      raise(err)
    end

    @pem.filesync_deploy
    @pem.refresh_envs
  end
end

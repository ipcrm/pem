require 'yaml'
require 'logger'
require 'puppet_forge'
require 'rugged'
require 'pathname'
require 'json'
require 'r10k/puppetfile'

class Pem_env
  attr_reader :location
  attr_reader :modules

  def initialize(name,pem)
    @conf     = pem.conf
    @logger   = pem.logger
    @location = "#{@conf['envdir']}/#{name}"
    @pem      = pem
  end

  #
  # Deploy a new environment, or remove and redeploy an environment
  #
  def deploy(modules)
    unless File.directory?(@location)
      begin
        @logger.debug('Pem_env::deploy') { "pem_env::deploy creating #{@location} " }
        FileUtils.mkdir(@location)
        FileUtils.mkdir("#{@location}/modules")

        modules.each do |n,m|
          @logger.debug('Pem_env::deploy') { "pem_env::deploying module #{n} @ version #{m}" }
          deploy_mod(n,m,"#{@location}/modules")
          @logger.debug('Pem_env::deploy') { "pem_env::deploying module succeeded" }
        end

        # TODO: Need to add environment.conf setup


        @pem.filesync_deploy(@logger)
        @logger.debug('Pem_env::deploy') { "pem_env::deploy successfully created #{@location} " }
      rescue => err
        Pem::log_error(err,@logger)
        raise(err)
      end
    else
      begin
        @logger.info('Pem_env::create') { "pem_env::deploy redeploying #{@location}" }
        Pem_env.destroy(@location,@logger)
        deploy(modules)
      rescue => err
        Pem::log_error(err,@logger)
        raise(err)
      end
    end

    @pem.refresh_envs
  end


  #
  # Deploy a module from global modules into this env
  #
  def deploy_mod(name,version,location)
    mod_name = name.split('-')[1]

    begin
      amods = @pem.get_modules
      if amods.keys.include?(name) and amods[name].include?(version)
        FileUtils.cp_r("#{@conf['mod_dir']}/#{name}/#{version}","#{location}/#{mod_name}")
      else
        err = "Unkown module or version supplied for #{name} @ #{version} "
        Pem::log_error(err,@logger)
        throw(err)
      end
    rescue => err
      Pem::log_error(err,@logger)
      raise(err)
    end

  end

  #
  # Determine the installed modules (and versions) in this env
  #
  def get_mods
    rmods = {}
    begin
      mods = Pathname.new("#{@location}/modules").children.select { |c| c.directory? }
      mods.each do |m|
        rmods[m.basename.to_s] = self.get_mod_ver(m.basename.to_s)
      end
    rescue => err
      Pem::log_error(err,@logger)
      raise(err)
    end

    rmods
  end

  #
  # Load puppetfile mods (temp method)
  #
  def load_puppetfile_mods
    mods = {}
    puppetfile = R10K::Puppetfile.new(@location)

    begin
      modules = puppetfile.modules
      modules.each do |mod|
        if mod.is_a? R10K::Module::Forge
          mods[mod.name] = mod.expected_version
        else mod.is_a? R10K::Module::Git
          mods[mod.name] = mod.version
        end
      end
    rescue => err
      Pem::log_error(err,@logger)
      raise(err) unless puppetfile.load
    end

    mods
  end

  #
  # Get version for deployed module in this env
  #
  def get_mod_ver(mod)
    begin
      if File.exists?("#{@location}/modules/#{mod}/.git")
        r = Rugged::Repository.discover("#{@location}/modules/#{mod}/.git").head
        return r.target.oid[0,7]
      elsif File.exists?("#{@location}/modules/#{mod}/metadata.json")
        return JSON::load(File.read("#{@location}/modules/#{mod}/metadata.json"))['version']
      else
        # Temp workaround for testing on masters still using code-manager
        mods = load_puppetfile_mods
        return mods[mod]
      end
    rescue => err
      Pem::log_error(err,@logger)
      raise(err)
    end
  end

  #
  # Purge environment from staging if present, commit filesync
  #
  def self.destroy(location,logger)
    begin
      logger.debug('Pem_env::create') { "pem_env::deploy removing #{location}" }
      FileUtils.rm_rf(location)
    rescue => err
      Pem::log_error(err,logger)
      raise(err)
    end

    # TODO: other work to cleanup
    #   commit filesync
    #   purge caches
  end

  def self.get_manifest
    # Read deployed env (metadata or from disk?) to determine modules deployed
  end

  def self.exists?
    # Determine if this is a real, deployed env
  end

end

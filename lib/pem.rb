# frozen_string_literal: true

require 'yaml'
require 'logger'
require 'puppet_forge'
require 'rugged'
require 'pathname'
require 'sinatra'
require 'openssl'
require 'zlib'
require 'minitar'
require 'tempfile'
require 'rest-client'
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
    conf = YAML.load_file(File.expand_path('../config.yml', File.dirname(__FILE__)))

    unless %w[basedir master filesync_cert filesync_cert_key filesync_ca_cert].all? { |s| conf.key?(s) && !conf[s].nil? }
      Pem.log_error('Missing required settings in config.yml', @logger)
      raise
    end

    conf['envdir']  = "#{conf['basedir']}/environments"
    conf['mod_dir'] = "#{conf['basedir']}/modules"
    conf['data_dir'] = "#{conf['basedir']}/data"

    return conf
  rescue StandardError
    err = 'Missing config file, or required configuration values - check config.yml'
    Pem.log_error(err, @logger)
    raise(err)
  end

  # Build global dirs
  #
  def setup
    @logger.debug('Pem::setup') { 'entering pem::setup' }
    # Make sure dirs exist
    begin
      FileUtils.mkdir(@conf['basedir']) unless Dir.exist?(@conf['basedir'])
      FileUtils.mkdir(@conf['mod_dir']) unless Dir.exist?(@conf['mod_dir'])
      FileUtils.mkdir(@conf['data_dir']) unless Dir.exist?(@conf['data_dir'])
      FileUtils.mkdir("#{@conf['data_dir']}/upload") unless Dir.exist?("#{@conf['data_dir']}/upload")
      FileUtils.mkdir("#{@conf['data_dir']}/git") unless Dir.exist?("#{@conf['data_dir']}/git")
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

    #will make a scalar value an array, or will leave an array as an array
    # it's ruby magic, and some people hate it, but it's just so damn simple!
    versions = Array(data['version'])

    begin

      versions.each do |version|

        moddir = "#{@conf['mod_dir']}/#{name}"
        tardir = "#{moddir}/#{version}"

        @logger.debug('Pem::deploy_mod') {"deploying module #{name} at version #{version} - Creating directory structure"}
        FileUtils.mkdir(moddir) unless Dir.exist?(moddir)
        purge_mod(name, version) if Dir.exist?(tardir)

        case data['type']
        when 'forge'
          deploy_forge_module(name,version,tardir)
          modname = name.split('-')
          data['source'] = "https://forge.puppet.com/#{modname[0]}/#{modname[1]}"
        when 'git'
          deploy_git_module(name,version,tardir,data['source'])
        when 'upload'
          deploy_uploaded_module(name,version,tardir,data[file])
          data['source'] ||= "N/A"
        end

        File.open("#{tardir}/.pemversion", 'w+') do |file|
          file.write({ 'type' => data['type'], 'source' => data['source']}.to_yaml)
        end
      end
    rescue StandardError => err
      Pem.log_error(err, @logger)
      raise(err)
    end
  end

  def deploy_uploaded_module(name,version,tardir,file)
    PuppetForge::Unpacker.unpack(file.path, tardir, '/tmp')
    @logger.debug('Pem::deploy_mod') { "pem::deploy_mod deploy #{name} @ #{version} succeeded" }
  end

  def deploy_git_module(name,version,tardir,source)
    begin
      repo = Rugged::Repository.clone_at(source, tardir)
      repo.checkout(version)
    rescue Rugged::InvalidError => e
      # If this is an annotated tag, we have to parse it a bit different
      atag = repo.rev_parse(version).target.oid
      repo.checkout(atag)
    end
    @logger.debug('Pem::deploy_mod') { "#{name} @ #{version} checked out successfully from Git source #{source}" }
  end

  def deploy_forge_module(name, version, tardir)
    PuppetForge.user_agent = 'pem/1.0.0'

    release_slug = "#{name}-#{version}"
    release_tarball = release_slug + '.tar.gz'

    release = PuppetForge::Release.find release_slug

    Dir.chdir('/tmp') do
      release.download(Pathname(release_tarball))
      release.verify(Pathname(release_tarball))
      PuppetForge::Unpacker.unpack(release_tarball, tardir, '/tmp')
    end
    @logger.debug('Pem::deploy_mod') { "pem::deploy_mod deploy #{name} @ #{version}from the PuppetForge has succeeded" }
  end

  # Delete a module from global module dir
  #
  # @param [String] name the name of the module to delete
  # @param [String] version the name of the version to delete
  #
  def purge_mod(name, version)
    tardir = "#{@conf['mod_dir']}/#{name}/#{version}"

    @logger.debug('Pem::purge_mod') { "Purging module #{name} @ #{version}; location #{tardir}" }

    FileUtils.rm_rf(tardir)

    @logger.debug('Pem::purge_mod') { "Successfully purged module #{name} @ #{version}" }
  rescue StandardError => err
    Pem.log_error(err, @logger)
    raise(err)
  end

  # Determine if module and version is in use in any environment.
  #
  # If the module is found in an enviornment it will raise an error
  #
  # @param [String] name the name of the module in <author>-<name> format
  # @param [String] version the version string of the module in question
  # @return [Hash] key status equals true/false (boolean) and envs hash will be an array containing 0 or more envs
  #
  def check_mod_use(name, version)
    e = []

    @envs.each do |k, v|
      next unless v.keys.include?(name) && v[name] == version
      e << k
    end

    if e.any?
      { 'status' => true, 'envs' => e }
    else
      { 'status' => false, 'envs' => e }
    end
  end

  # Get all available versions of a given modules
  #
  # @param [String] mod the name of the module to return versions of
  # @return [Array] all available global versions of module supplied
  #
  def mod_versions(mod)
    versions = {}

    Pathname.new(mod).children.select(&:directory?).each do |m|
      version = m.basename.to_s
      deets = YAML.safe_load(File.open("#{mod}/#{version}/.pemversion"))
      versions[version] = deets
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

  # Retrieve all branches/versions of a deployed git data registration
  #
  # @return [Hash] All branches/versions of a deployed git data registration
  #
  def git_data_reg_versions(dreg)
    versions = {}
    versions['branches'] = {}

    # Get branches
    Pathname.new(dreg).children.select(&:directory?).each do |b|
      versions['branches'][b.basename.to_s] = {}
      # Get versions per branch
      Pathname.new(b).children.select(&:directory?).each do |v|
        version = v.basename.to_s
        deets = YAML.safe_load(File.open("#{v}/.pemversion"))
        versions['branches'][b.basename.to_s][version] = deets
      end
    end

    versions
  end

  # Retrieve all versions of a uploaded git data registration
  #
  # @return [Hash] All versions of a deployed upload data registration
  #
  def upload_data_reg_versions(dreg)
    versions = {}

    Pathname.new(dreg).children.select(&:directory?).each do |v|
      version = v.basename.to_s
      deets = YAML.safe_load(File.open("#{v}/.pemversion"))
      versions[v.basename.to_s] = deets
    end

    {'uploads' => versions}
  end

  # Merge (recursive) two hashes 
  #
  # Shameless robbed from SO
  # https://stackoverflow.com/questions/8415240/how-to-merge-ruby-hashes
  #
  # @param [Hash] a the first hash to be merged
  # @param [Hash] b the second hash to be merged
  #
  def merge_recursively(a, b)
    a.merge(b) {|key, a_item, b_item| merge_recursively(a_item, b_item) }
  end


  # Retrieve all data registrations that have been deployed
  #
  # @return [Hash] All deployed data registrations and the versions of each type
  #
  def data_registrations
    dreg = {}

    begin
      # Get git based registrations first
      git_dregs = {}
      gits = Pathname.new("#{@conf['data_dir']}/git").children.select(&:directory?)

      # For each 'registration' we are tracking, loop thru and find versions by branch
      gits.each do |g|
        puts g
        git_dregs[g.basename.to_s] = git_data_reg_versions(g)
      end

      # Get uploaded registrations
      upload_dregs = {}
      uploads = Pathname.new("#{@conf['data_dir']}/upload").children.select(&:directory?)

      # For each 'regsitration', loop thru and find versions that have been posted
      uploads.each do |u|
        upload_dregs[u.basename.to_s] = upload_data_reg_versions(u)
      end

      dreg = merge_recursively(git_dregs,upload_dregs)
    rescue StandardError => err
      Pem.log_error(err, @logger)
      raise(err)
    end

    dreg
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
    diffs   = {}
    shareds = {}
    e1 = @envs[env1]
    e2 = @envs[env2]

    uniq_mods = e1.keys - e2.keys | e2.keys - e1.keys
    shared_mods = ((e1.keys + e2.keys) - uniq_mods).uniq

    shared_mods.each do |s|
      if e1[s] != e2[s]
        diffs[s] = { env1 => e1[s], env2 => e2[s] } if e1[s] != e2[s]
      else
        shareds[s] = e1[s]
      end
    end

    uniq_mods.each do |u|
      if e1.keys.include?(u)
        diffs[u] = { env1 => e1[u], env2 => false }
      elsif e2.keys.include?(u)
        diffs[u] = { env2 => e2[u], env1 => false }
      end
    end

    {
      'diffs'  => diffs,
      'shared' => shareds,
    }
  end

  # Find what environments a given module/version is deployed to
  #
  # @param [String] name the name of the module in <author>-<name> format
  # @param [String] version the version string of the module in question
  # @return [Array] list of enviornments this module is deployed to
  #
  def find_module(name, version)
    e = []

    @envs.each do |k, v|
      next unless v.keys.include?(name) && v[name] == version
      e << k
    end

    e
  end

  # Create an archive of an enviornment
  #
  # @param [String] name the name of the enviornment
  # @return [File] a file handle of the archive created
  #
  def create_env_archive(name)
    if !@envs.keys.include?(name)
      err = 'Invalid environment name supplied'
      Pem.log_error(err, @logger)
      raise err
    else
      begin
        tmpfile = Tempfile.new

        Dir.chdir(@conf['envdir']) do
          Minitar.pack(name, Zlib::GzipWriter.new(tmpfile))
        end

        return tmpfile
      rescue StandardError => err
        Pem.log_error(err, @logger)
        raise err
      end
    end
  end

  # Filesync handling
  #
  # This method commits changes to the staging code dir, force-syncs, and purges env caches on the master
  #
  def filesync_deploy
    @logger.debug('Pem::filesync_deploy') { 'starting filesync deploy' }

    verify_ssl = true
    if @conf['verify_ssl'] == false
      @logger.debug('Pem::filesync_deploy') { 'SSL verification disabled in config.yml' }
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

    @logger.debug('Pem::filesync_deploy') { 'Hitting filesync commit endpoint...' }
    conn.post '/file-sync/v1/commit', 'commit-all' => true
    @logger.debug('Pem::filesync_deploy') { 'Done.' }

    @logger.debug('Pem::filesync_deploy') { 'Hitting filesync force-sync endpoint...' }
    conn.post '/file-sync/v1/force-sync'
    @logger.debug('Pem::filesync_deploy') { 'Done.' }

    @logger.debug('Pem::filesync_deploy') { 'Hitting puppet-admin-api env endpoint...' }
    conn.delete '/puppet-admin-api/v1/environment-cache'
    @logger.debug('Pem::filesync_deploy') { 'Done.' }

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


  # Find forge modules and versions
  #
  # @param [String] search_string to use when looking up modules
  # @return [Hash] hash containing names and releases {'module_name' => [x.y.z, z.y.x]}
  def get_forge_modules(search_string)
    modules = {}

    unless search_string =~ /^\A[-\w.]*\z/
      raise 'Invalid search_string provided'
    end

    url = "https://forgeapi.puppetlabs.com/v3/modules?query=#{search_string}"
    r = RestClient.get url, accept: 'application/json', charset: 'utf-8'

    JSON.parse(r)['results'].each do |x|
      name = x['current_release']['metadata']['name'].tr('/', '-')
      versions = x['releases'].map { |y| y['version'] }

      modules[name] = versions
    end

    modules
  end


  # Create a data registration
  #
  # @param [String] name the name of the data registration
  # @param [Hash] data a hash of all the info for deploying this registration.
  #   prefix: Path relative to <env>/data/<prefix>. Optional.  Defaults to <env>/data
  #   type: (upload or git)
  #    upload:
  #       - version [String] this is the user assigned version for this upload
  #       - file [Filehandle] this is the file handle to the tar gz to be used
  #    git:
  #       - source [String] the checkout URL
  #       - branch [String] the git branch to register
  # @return [String] version the version of the latest created registration
  #
  def create_data_reg(name,data)
    @logger.debug('Pem::create_data_reg') { "pem::create_data_reg for #{name} starting" }

    # Store global version to be returned after checkout
    ver = nil

    # Set the prefix if not provided
    data['prefix'] = data['prefix'].nil? ? nil : data['prefix']

    # Set directories for checkout/deployment
    datadir = "#{@conf['data_dir']}"

    # Calculate version
    case data['type'] 
    when 'upload'
      if data['version'].nil?
        @logger.debug('Pem::create_data_reg') { "pem::create_data_reg for #{name} failed!  Must supply version on upload!" }
        raise "Must supply version when uploading data!"
      end

      # Set global version
      ver = data['version']

      begin
        if data['file'].nil?
          @logger.debug('Pem::create_data_reg') {"Pem::create_data_reg must supply file param in data!"}
          raise "Must supply file parameter for uploading data!"
        end

        # Set the upload dir
        uploaddir = "#{datadir}/upload/#{name}"
        FileUtils.mkdir(uploaddir) unless Dir.exist?(uploaddir)

        # Set the target dir
        tardir = "#{datadir}/upload/#{name}/#{data['version']}"
        PuppetForge::Unpacker.unpack(data['file'].path, tardir, '/tmp')
        @logger.debug('Pem::create_data_reg') { "pem::create_data_reg deploy #{name} @ #{data['version']} succeeded" }


        # Write metadata - minus tmpfile
        data.delete('file')
        File.open("#{tardir}/.pemversion", 'w+') do |file|
          file.write(data.to_yaml)
        end
      rescue StandardError => err
        Pem.log_error(err, @logger)
        raise(err)
      end

    when 'git'
      if data['branch'].nil?
        @logger.debug('Pem::create_data_reg') {
          "pem::create_data_reg for #{name} failed!  Must supply branch for git registrations!"
        }
        raise "Must supply branch for git registrations data!"
      end

      begin
        # Set the data dir
        new_data_dir = "#{datadir}/git/#{name}"
        FileUtils.mkdir(new_data_dir) unless Dir.exist?(new_data_dir)

        # Set the branch dir
        branchdir = "#{datadir}/git/#{name}/#{data['branch']}"
        FileUtils.mkdir(branchdir) unless Dir.exist?(branchdir)

        # Make a tmpdir to clone into; get version; cp_r contents into the right version dir; mktmpdir purges original clone location
        Dir.mktmpdir do |dir|
          repo = Rugged::Repository.clone_at(data['source'], dir)
          repo.checkout("origin/#{data['branch']}")
          ref = repo.head.target_id

          # Set global version
          ver = ref

          tardir = "#{datadir}/git/#{name}/#{data['branch']}/#{ref}"

          # If we are 'refreshing' and this commit is already checked out; do nothing
          if Dir.exists?(tardir)
            @logger.debug('Pem::create_data_reg') {
              "Pem::create_data_reg version #{ref} for #{name} already exists, skipping checkout!"
            }
          end
          FileUtils.cp_r(dir,tardir) unless Dir.exist?(tardir)

          # Store version for metadata
          data['version'] = ref

          # Write the metadata
          File.open("#{tardir}/.pemversion", 'w+') do |file|
            file.write(data.to_yaml)
          end
        end
      rescue StandardError => err
        Pem.log_error(err, @logger)
        raise(err)
      end
    end

    ver
  end
end

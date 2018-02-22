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
require "#{File.dirname(__FILE__)}/pemlogger"
require "#{File.dirname(__FILE__)}/pem/env"
require "#{File.dirname(__FILE__)}/pem/utils"
require "#{File.dirname(__FILE__)}/pem/filesync"
require "#{File.dirname(__FILE__)}/pem/module"
require "#{File.dirname(__FILE__)}/pem/module/version"

# PEM Main class
class Pem
  attr_reader :conf
  attr_reader :logger
  attr_reader :envs
  attr_reader :modules
  attr_reader :filesync

  include Pem::Utils

  # Initialize
  #
  # @param logger Logger Object
  # @return PEM instance
  def initialize
    @conf = load_config

    setup(self)

    @envs = envs_details
    @modules = {}
    @filesync = Pem::Filesync.new(@conf)

    load_modules(self)
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
      PemLogger.logit(err,:fatal)
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
    PemLogger.logit(err,:fatal)
    raise(err)
  end

  # Retrieve all envs with details
  #
  # @return [Hash] all deployed environments and the modules (including versions) that have been deployed
  #
  def envs_details
    current_envs = {}
    show_envs.each do |e|
      z = Pem::Env.new(e, self)
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
      PemLogger.logit(err,:fatal)
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
    PemLogger.logit("Starting create data registration for #{name} ...", :debug)

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
        PemLogger.logit("create_data_reg for #{name} failed!  Must supply version on upload!",:fatal)
        raise "Must supply version when uploading data!"
      end

      # Set global version
      ver = data['version']

      begin
        if data['file'].nil?
          PemLogger.logit("Must supply file param in data!", :fatal)
          raise "Must supply file parameter for uploading data!"
        end

        # Set the upload dir
        uploaddir = "#{datadir}/upload/#{name}"
        FileUtils.mkdir(uploaddir) unless Dir.exist?(uploaddir)

        # Set the target dir
        tardir = "#{datadir}/upload/#{name}/#{data['version']}"
        PuppetForge::Unpacker.unpack(data['file'].path, tardir, '/tmp')
        PemLogger.logit("pem::create_data_reg deploy #{name} @ #{data['version']} succeeded")


        # Write metadata - minus tmpfile
        data.delete('file')
        File.open("#{tardir}/.pemversion", 'w+') do |file|
          file.write(data.to_yaml)
        end
      rescue StandardError => err
        PemLogger.logit(err,:fatal)
        raise(err)
      end

    when 'git'
      if data['branch'].nil?
        PemLogger.logit("Must supply branch for git registrations!", :fatal)
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
            PemLogger.logit("Version #{ref} for #{name} already exists, skipping checkout!", :debug)
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
        PemLogger.logit(err, :fatal)
        raise(err)
      end
    end

    ver
  end


end

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
require "#{File.dirname(__FILE__)}/pem/utils"


# PEM Main class
class Pem
  attr_reader :conf
  attr_reader :logger
  attr_reader :envs
  attr_reader :data
  attr_reader :modules
  attr_reader :filesync

  include Pem::Utils

  # Initialize
  #
  # @param logger Logger Object
  # @return PEM instance
  def initialize
    @conf = Pem::Utils::Config.load_config
    Pem::Utils::Setup.setup(self)

    @envs     = envs_details
    @modules  = {}
    @data     = {}
    @filesync = Pem::Filesync.new(@conf)

    Pem::Utils::Modules.load_modules(self)
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

end

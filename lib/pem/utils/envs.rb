require "#{File.dirname(__FILE__)}/../../pemlogger"

class Pem
  module Utils
  module Envs
    # Create an archive of an enviornment
    #
    # @param [String] name the name of the enviornment
    # @return [File] a file handle of the archive created
    #
    def self.create_env_archive(name,conf)
    begin
      tmpfile = Tempfile.new

      Dir.chdir(conf['envdir']) do
      Minitar.pack(name, Zlib::GzipWriter.new(tmpfile))
      end

      return tmpfile
    rescue StandardError => err
      PemLogger.logit(err, :fatal)
      raise err
    end
    end


    # Compare Envs
    #
    # @param [String] env1 Name of the first environment to compare the second two
    # @param [String] env2 Name of the second environment to compare to the first
    # @param [Hash] envs Hash of the environments you want to compare (pass in a Pem object instance var of envs)
    # @return [Hash] a listing of all modules with differences in the format of 'name' => ['env1' => <version, 'env2' => version]
    def self.compare_envs(env1, env2, envs)
    diffs   = {}
    shareds = {}
    e1 = envs[env1]
    e2 = envs[env2]

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
  end
  end
end

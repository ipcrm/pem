require "#{File.dirname(__FILE__)}/../../pemlogger"

class Pem
    module Utils
        module Modules
            # Used on startup to determine what modules are deployed populate the modules instance var
            def self.load_modules(pem)
                begin
                    Pathname.new(pem.conf['mod_dir']).children.select(&:directory?).each do |m|
                        Pem::Module.new(m.basename.to_s, pem).load_versions
                    end
                rescue StandardError => err
                    PemLogger.logit(err,:fatal)
                    raise(err)
                end
            end

            # Determine if module and version is in use in any environment.
            #
            # If the module is found in an enviornment it will raise an error
            #
            # @param [String] name the name of the module in <author>-<name> format
            # @param [String] version the version string of the module in question
            # @return [Hash] key status equals true/false (boolean) and envs hash will be an array containing 0 or more envs
            #
            def self.check_mod_use(name, version, pem)
                e = []

                pem.envs.each do |k, v|
                    next unless v.keys.include?(name) && v[name] == version
                    e << k
                end

                if e.any?
                { 'status' => true, 'envs' => e }
                else
                { 'status' => false, 'envs' => e }
                end
            end
        end
    end
end

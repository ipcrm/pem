require "#{File.dirname(__FILE__)}/../../pemlogger"

class Pem
    module Utils
        module Setup
            # Build global dirs
            #
            def self.setup(pem)
                PemLogger.logit('Running setup...',:debug)
                # Make sure dirs exist
                begin
                    FileUtils.mkdir(pem.conf['basedir']) unless Dir.exist?(pem.conf['basedir'])
                    FileUtils.mkdir(pem.conf['mod_dir']) unless Dir.exist?(pem.conf['mod_dir'])
                    FileUtils.mkdir(pem.conf['data_dir']) unless Dir.exist?(pem.conf['data_dir'])
                    FileUtils.mkdir(pem.conf['envdir'])  unless Dir.exist?(pem.conf['envdir'])
                rescue StandardError => err
                    PemLogger.logit(err, :fatal)
                    raise(err)
                end
            end
        end
    end
end

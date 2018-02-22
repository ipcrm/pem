require "#{File.dirname(__FILE__)}/../pemlogger"

class Pem
    module Utils

        # Used on startup to determine what modules are deployed populate the modules instance var
        def load_modules(pem)
            begin
                Pathname.new(pem.conf['mod_dir']).children.select(&:directory?).each do |m|
                Pem::Module.new(m.basename.to_s, pem).load_versions
            end
            rescue StandardError => err
                PemLogger.logit(err,:fatal)
                raise(err)
            end
        end


        # Load config or fail if there is missing stuff
        #
        # @return [Hash] Configuration hash
        #
        def load_config
            conf = YAML.load_file(File.expand_path('../../config.yml', File.dirname(__FILE__)))

            unless %w[basedir master filesync_cert filesync_cert_key filesync_ca_cert].all? { |s| conf.key?(s) && !conf[s].nil? }
            PemLogger.logit('Missing required settings in config.yml',:fatal)
            raise
            end

            conf['envdir']  = "#{conf['basedir']}/environments"
            conf['mod_dir'] = "#{conf['basedir']}/modules"
            conf['data_dir'] = "#{conf['basedir']}/data"

            return conf
        rescue StandardError
            err = 'Missing config file, or required configuration values - check config.yml'
            PemLogger.logit(err, :fatal)
            raise(err)
        end

        # Build global dirs
        #
        def setup(pem)
            PemLogger.logit('Running setup...',:debug)
            # Make sure dirs exist
            begin
            FileUtils.mkdir(pem.conf['basedir']) unless Dir.exist?(pem.conf['basedir'])
            FileUtils.mkdir(pem.conf['mod_dir']) unless Dir.exist?(pem.conf['mod_dir'])
            FileUtils.mkdir(pem.conf['data_dir']) unless Dir.exist?(pem.conf['data_dir'])
            FileUtils.mkdir("#{pem.conf['data_dir']}/upload") unless Dir.exist?("#{pem.conf['data_dir']}/upload")
            FileUtils.mkdir("#{pem.conf['data_dir']}/git") unless Dir.exist?("#{pem.conf['data_dir']}/git")
            FileUtils.mkdir(pem.conf['envdir'])  unless Dir.exist?(pem.conf['envdir'])
            rescue StandardError => err
                PemLogger.logit(err, :fatal)
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
        def check_mod_use(name, version, pem)
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


        # Compare Envs
        #
        # @param [String] env1 Name of the first environment to compare the second two
        # @param [String] env2 Name of the second environment to compare to the first
        # @param [Hash] envs Hash of the environments you want to compare (pass in a Pem object instance var of envs)
        # @return [Hash] a listing of all modules with differences in the format of 'name' => ['env1' => <version, 'env2' => version]
        def compare_envs(env1, env2, envs)
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


        # Create an archive of an enviornment
        #
        # @param [String] name the name of the enviornment
        # @return [File] a file handle of the archive created
        #
        def create_env_archive(name)
            begin
                tmpfile = Tempfile.new

                Dir.chdir(@conf['envdir']) do
                Minitar.pack(name, Zlib::GzipWriter.new(tmpfile))
                end

                return tmpfile
            rescue StandardError => err
                PemLogger(err, :fatal)
                raise err
            end
        end


    end
end
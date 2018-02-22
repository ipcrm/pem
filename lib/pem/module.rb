class Pem
    class Module
        def initialize(name,pem)
            @logger = pem.logger
            @mod_location = pem.conf['mod_dir']
        
            setup
        
            @envs = envs_details
    end
end
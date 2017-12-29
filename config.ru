require 'json'
require File.expand_path('app', File.dirname(__FILE__))
conf = YAML.load_file(File.expand_path('config.yml', File.dirname(__FILE__)))

# Write a config file for UI
File.open(File.expand_path('pem_ui/config.js', File.dirname(__FILE__)), 'w+') do |f|
  f.write("var master = \'#{conf['pem_host']}\';\n")
  f.write("var port = \'#{conf['pem_port']}\';\n")
end


run PemApp

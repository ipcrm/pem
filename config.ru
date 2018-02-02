require 'json'
require File.expand_path('app', File.dirname(__FILE__))
conf = YAML.load_file(File.expand_path('config.yml', File.dirname(__FILE__)))

run PemApp

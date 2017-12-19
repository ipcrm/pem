# frozen_string_literal: true

require 'r10k/puppetfile'
require 'json'
require 'faraday'

raise('Supply location for puppetfile!') unless ARGV[0]
raise('Supply name for new env!') unless ARGV[1]

conn = Faraday.new(url: 'http://localhost:4567') do |faraday|
  faraday.request :json
  faraday.adapter Faraday.default_adapter
end

puppetfile = R10K::Puppetfile.new(ARGV[0])
raise 'Could not load Puppetfile' unless puppetfile.load

modules = puppetfile.modules
create_env = {}

modules.each do |mod|
  if mod.is_a? R10K::Module::Forge
    if mod.expected_version.is_a?(String)

      puts "Deploying module #{mod.title}"
      conn.post '/deploy_mod', mod.title => { 'version' => mod.expected_version, 'type' => 'forge' }
      create_env[mod.title] = mod.expected_version
    end
  elsif mod.is_a? R10K::Module::Git
    puts "Deploying module #{mod.title}"
    conn.post '/deploy_mod', "myorg-#{mod.name}" => {
      'version' => mod.version[0, 6],
      'type' => 'git',
      'source' => mod.instance_variable_get(:@remote)
    }
    create_env["myorg-#{mod.name}"] = mod.version[0, 6]
  end
end

puts 'Creating env'
conn.post "/envs/#{ARGV[1]}/create", create_env

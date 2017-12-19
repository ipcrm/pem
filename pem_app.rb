# frozen_string_literal: true

require 'sinatra'
require "#{File.dirname(__FILE__)}/lib/pem"
require "#{File.dirname(__FILE__)}/lib/pemenv"

# Assuming these go someplace useful in future
logger = Logger.new(STDERR)
logger = Logger.new(STDOUT)

pem = Pem.new(logger)

get '/' do
  puts 'HI'
end

#
# Dump env list
#
get '/envs' do
  content_type 'application/json'
  pem.envs.to_json
end

#
# Deploy a global module
#
post '/deploy_mod' do
  content_type 'application/json'
  data = JSON.parse(request.body.read)

  begin
    data.each do |m, v|
      pem.deploy_mod(m, v)
    end
    { 'status' => 'successful' }.to_json
  rescue
    { 'status' => 'failed' }.to_json
  end
end

#
# Get global modules
#
get '/modules' do
  content_type 'application/json'
  pem.modules.to_json
end

#
# Create an environment
#
post '/envs/:name/create' do
  content_type 'application/json'
  data = JSON.parse(request.body.read)
  e = PemEnv.new(params[:name], pem)

  begin
    e.deploy(data)
    { 'status' => 'successful' }.to_json
  rescue
    { 'status' => 'failed' }.to_json
  end
end

#
# Get modules for configured enviornment
#
get '/envs/:name/modules' do
  content_type 'application/json'
  e = PemEnv.new(params[:name], pem)
  e.mods.to_json
end

#
# Compare two envs
#
post '/envs/compare' do
  content_type 'application/json'
  data = JSON.parse(request.body.read)
  pem.compare_envs(data[0], data[1]).to_json
end

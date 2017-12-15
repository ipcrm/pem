require 'sinatra'
require_relative 'pem'
require_relative 'pem_env'

# Assuming these go someplace useful in future
logger = Logger.new(STDERR)
logger = Logger.new(STDOUT)

pem = Pem.new(logger)


get '/' do
  puts "HI"
end

#
# Dump env list
#
get '/envs' do
  pem.envs.to_json
end

#
# Deploy a global module
#
post '/deploy_mod' do
  data = JSON.parse(request.body.read)

  begin
    data.each do |m,v|
      pem.deploy_mod(m,v)
    end
    {'status' => 'successful'}.to_json
  rescue
    {'status' => 'failed'}.to_json
  end
end

#
# Get global modules
#
get '/modules' do
  pem.get_modules.to_json
end

#
# Create an environment
#
post '/envs/:name/create' do
  data = JSON.parse(request.body.read)
  e = Pem_env.new(params[:name],pem)

  begin
    e.deploy(data)
    {'status' => 'successful'}.to_json
  rescue
    {'status' => 'failed'}.to_json
  end
end

#
# Get modules for configured enviornment
#
get '/envs/:name/modules' do
  e = Pem_env.new(params[:name],pem)
  e.get_mods.to_json
end

#
# Compare two envs
#
post '/envs/compare' do
  data = JSON.parse(request.body.read)
  pem.compare_envs(data[0],data[1]).to_json
end

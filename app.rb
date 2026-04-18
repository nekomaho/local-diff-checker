require 'sinatra'
require 'sinatra/reloader' if development?
require 'yaml'
require 'json'

class LocalDiffChecker < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  set :config, YAML.load_file('config.yml')

  get '/' do
    erb :index
  end
end

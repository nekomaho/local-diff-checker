require 'sinatra'
require 'sinatra/reloader' if development?
require 'yaml'
require 'json'
require 'commonmarker'
require_relative 'lib/git_manager'
require_relative 'lib/diff_parser'
require_relative 'lib/markdown_storage'

class LocalDiffChecker < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  enable :sessions
  set :session_secret, 'a_very_long_and_secure_session_secret_key_that_is_at_least_64_characters_long_for_security_compliance'

  config_file = File.join(File.dirname(__FILE__), 'config.yml')
  set :config, File.exist?(config_file) ? YAML.load_file(config_file) : {}
  set :port, settings.config['port'] || 4567
  set :storage, MarkdownStorage.new(settings.config['storage_dir'] || './data')

  get '/' do
    @last_path = session[:last_path]
    @repo_paths = settings.config['repo_paths'] || []
    erb :index
  end

  get '/diff_router' do
    path = params[:path]
    path = params[:manual_path] if path == 'manual'
    session[:last_path] = path
    mode = params[:mode]
    if mode == 'unstaged'
      redirect "/diff/unstaged?path=#{path}"
    else
      redirect "/diff?path=#{path}"
    end
  end

  get '/diff' do
    @path = params[:path]
    @mode = :committed
    @git = GitManager.new(@path)

    unless @git.git_repo?
      return "Error: Not a git repository or directory does not exist."
    end

    @branch = @git.current_branch
    @base = @git.base_branch
    @diff_text = @git.diff_with_base
    @repo_name = @git.repo_name
    @commit_hash = @git.current_commit_hash
    prefix = "#{@repo_name}-#{@branch}-#{@commit_hash}"

    metadata = {
      branch: @branch,
      base_branch: @base,
      base_commit: @git.merge_base_hash,
      current_commit: @commit_hash,
      generated_at: Time.now.to_s,
      mode: @mode
    }

    @filename = settings.storage.save(prefix, metadata, @diff_text)
    @data = settings.storage.load(@filename)
    @parsed_diff = DiffParser.new(@data[:diff]).parse
    @comments = @data[:comments]

    erb :diff
  end

  get '/diff/unstaged' do
    @path = params[:path]
    @mode = :unstaged
    @git = GitManager.new(@path)

    unless @git.git_repo?
      return "Error: Not a git repository or directory does not exist."
    end

    @branch = @git.current_branch
    @base = @git.base_branch
    @diff_text = @git.diff_unstaged
    @repo_name = @git.repo_name
    @commit_hash = @git.current_commit_hash
    prefix = "#{@repo_name}-#{@branch}-#{@commit_hash}"

    metadata = {
      branch: @branch,
      current_commit: "#{@commit_hash} (unstaged)",
      generated_at: Time.now.to_s,
      mode: @mode
    }

    @filename = settings.storage.save(prefix, metadata, @diff_text, "_uncommited")
    @data = settings.storage.load(@filename)
    @parsed_diff = DiffParser.new(@data[:diff]).parse
    @comments = @data[:comments]

    erb :diff
  end

  post '/comment' do
    filename = params[:filename]
    line_id = params[:line_id]
    content = params[:content]
    path = params[:path]
    mode = params[:mode]

    settings.storage.add_comment(filename, line_id, content)

    if mode == 'unstaged'
      redirect "/diff/unstaged?path=#{path}"
    else
      redirect "/diff?path=#{path}"
    end
  end

  post '/comment/update' do
    filename = params[:filename]
    line_id = params[:line_id]
    index = params[:index].to_i
    content = params[:content]
    path = params[:path]
    mode = params[:mode]

    settings.storage.update_comment(filename, line_id, index, content)

    if mode == 'unstaged'
      redirect "/diff/unstaged?path=#{path}"
    else
      redirect "/diff?path=#{path}"
    end
  end

  post '/comment/delete' do
    filename = params[:filename]
    line_id = params[:line_id]
    index = params[:index].to_i
    path = params[:path]
    mode = params[:mode]

    settings.storage.delete_comment(filename, line_id, index)

    if mode == 'unstaged'
      redirect "/diff/unstaged?path=#{path}"
    else
      redirect "/diff?path=#{path}"
    end
  end

  run! if app_file == $0
end

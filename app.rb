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

  helpers do
    def fill_gaps(parsed_diff, git, mode)
      revision = (mode == :unstaged ? nil : 'HEAD')
      parsed_diff.each do |file_diff|
        new_lines = []
        current_left = 1
        current_right = 1
        file_path = file_diff[:file]
        
        total_lines = git.line_count(file_path, revision)

        file_diff[:lines].each do |line|
          if line[:is_hunk]
            h_left_start = line[:left][:start]
            h_right_start = line[:right][:start]
            
            if h_right_start > current_right
              new_lines << {
                is_gap: true,
                left_start: current_left,
                right_start: current_right,
                count: h_right_start - current_right
              }
            end
            new_lines << line
            current_left = h_left_start
            current_right = h_right_start
          else
            new_lines << line
            if line[:left][:number]
              current_left = line[:left][:number] + 1
            end
            if line[:right][:number]
              current_right = line[:right][:number] + 1
            end
          end
        end
        
        if current_right <= total_lines
          new_lines << {
            is_gap: true,
            left_start: current_left,
            right_start: current_right,
            count: total_lines - current_right + 1
          }
        end
        file_diff[:lines] = new_lines
      end
    end
  end

  get '/' do
    @last_path = session[:last_path]
    @last_base = session[:last_base]
    @repo_paths = settings.config['repo_paths'] || []
    erb :index
  end

  get '/diff_router' do
    path = params[:path]
    path = params[:manual_path] if path == 'manual'
    session[:last_path] = path
    mode = params[:mode]
    base = params[:base]
    session[:last_base] = base
    if mode == 'unstaged'
      redirect "/diff/unstaged?path=#{path}"
    else
      redirect "/diff?path=#{path}&base=#{base}"
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
    @base = @git.base_branch(params[:base])
    @diff_text = @git.diff_with_base(@base)
    @repo_name = @git.repo_name
    @commit_hash = @git.current_commit_hash
    prefix = "#{@repo_name}-#{@branch.gsub('/', '--')}-#{@commit_hash}"

    metadata = {
      branch: @branch,
      base_branch: @base,
      base_commit: @git.merge_base_hash(@base),
      current_commit: @commit_hash,
      generated_at: Time.now.to_s,
      mode: @mode
    }

    @filename = settings.storage.save(prefix, metadata, @diff_text)
    @full_filename = File.expand_path(File.join(settings.storage.storage_dir, @filename))
    @data = settings.storage.load(@filename)
    @parsed_diff = DiffParser.new(@data[:diff]).parse
    fill_gaps(@parsed_diff, @git, @mode)
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
    prefix = "#{@repo_name}-#{@branch.gsub('/', '--')}-#{@commit_hash}"

    metadata = {
      branch: @branch,
      current_commit: "#{@commit_hash} (unstaged)",
      generated_at: Time.now.to_s,
      mode: @mode
    }

    @filename = settings.storage.save(prefix, metadata, @diff_text, "_uncommited")
    @full_filename = File.expand_path(File.join(settings.storage.storage_dir, @filename))
    @data = settings.storage.load(@filename)
    @parsed_diff = DiffParser.new(@data[:diff]).parse
    fill_gaps(@parsed_diff, @git, @mode)
    @comments = @data[:comments]

    erb :diff
  end

  get '/api/file_content' do
    content_type :json
    repo_path = params[:path]
    file_path = params[:file]
    start_line = params[:start].to_i
    end_line = params[:end].to_i
    mode = params[:mode]
    
    git = GitManager.new(repo_path)
    revision = (mode == 'unstaged' ? nil : 'HEAD')
    
    content = git.file_content(file_path, revision)
    lines = content.lines
    
    # Lines are 1-indexed in the request
    s = [start_line - 1, 0].max
    e = [end_line - 1, lines.size - 1].min
    requested_lines = lines[s..e] || []
    
    {
      lines: requested_lines.map { |l| CGI.escapeHTML(l.chomp) }
    }.to_json
  end

  post '/comment' do
    filename = params[:filename]
    line_id = params[:line_id]
    content = params[:content]
    path = params[:path]
    mode = params[:mode]

    settings.storage.add_comment(filename, line_id, content)

    if params[:ajax]
      content_type :json
      return { 
        status: 'success', 
        line_id: line_id, 
        content_html: Commonmarker.to_html(content),
        raw_content: content,
        index: (settings.storage.load(filename)[:comments][line_id].size - 1)
      }.to_json
    end

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

    if params[:ajax]
      content_type :json
      return { 
        status: 'success', 
        line_id: line_id, 
        index: index, 
        content_html: Commonmarker.to_html(content),
        raw_content: content
      }.to_json
    end

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

    if params[:ajax]
      content_type :json
      return { status: 'success', line_id: line_id, index: index }.to_json
    end

    if mode == 'unstaged'
      redirect "/diff/unstaged?path=#{path}"
    else
      redirect "/diff?path=#{path}"
    end
  end

  post '/approve' do
    filename = params[:filename]
    approved = params[:approved] == 'true'
    path = params[:path]
    mode = params[:mode]

    settings.storage.set_approved(filename, approved)

    if mode == 'unstaged'
      redirect "/diff/unstaged?path=#{path}"
    else
      redirect "/diff?path=#{path}"
    end
  end

  run! if app_file == $0
end

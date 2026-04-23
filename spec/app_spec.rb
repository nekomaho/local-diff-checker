require 'spec_helper'
require 'rack/test'
require 'tmpdir'
require_relative '../app'

RSpec.describe LocalDiffChecker do
  include Rack::Test::Methods

  def app
    LocalDiffChecker
  end

  let(:repo_path) { Dir.mktmpdir }
  let(:storage_dir) { Dir.mktmpdir }

  before do
    app.set :storage, MarkdownStorage.new(storage_dir)
    Dir.chdir(repo_path) do
      `git init`
      `git config user.email "test@example.com"`
      `git config user.name "Test User"`
      File.write('file.txt', 'base')
      `git add file.txt`
      `git commit -m "initial"`
      `git checkout -b feat`
      File.write('file.txt', 'change')
      `git add file.txt`
      `git commit -m "feat"`
    end
  end

  after do
    FileUtils.remove_entry(repo_path)
    FileUtils.remove_entry(storage_dir)
  end

  it 'loads configuration' do
    # It should have a default storage_dir if not specified
    expect(app.settings.storage.instance_variable_get(:@storage_dir)).not_to be_nil
  end

  it 'renders index' do
    get '/'
    expect(last_response).to be_ok
    expect(last_response.body).to include('Local Diff Checker')
    expect(last_response.body).to include('style.css')
    expect(last_response.body).to include('app.js')
  end

  it 'renders diff for a valid git repo' do
    get '/diff', path: repo_path
    expect(last_response).to be_ok
    expect(last_response.body).to include('feat')
    expect(last_response.body).to include('file.txt')
    expect(last_response.body).to include('class="copy-btn"')
  end

  it 'adds a comment' do
    # First render to create the markdown file and get the current filename
    get '/diff', path: repo_path
    filename = last_response.body.match(/name="filename" value="([^"]+)"/)[1]

    post '/comment', {
      filename: filename,
      line_id: 'file.txt:R1',
      content: 'Interesting change',
      path: repo_path,
      mode: 'committed'
    }

    expect(last_response.status).to eq 302 # Redirect back

    # Verify comment is saved
    follow_redirect!
    expect(last_response.body).to include('Interesting change')
  end

  it 'approves a diff' do
    # First render to create the markdown file and get the current filename
    get '/diff', path: repo_path
    filename = last_response.body.match(/name="filename" value="([^"]+)"/)[1]
    expect(last_response.body).to include('Approve')

    post '/approve', {
      filename: filename,
      approved: 'true',
      path: repo_path,
      mode: 'committed'
    }

    expect(last_response.status).to eq 302 # Redirect back

    # Verify approval state in view
    follow_redirect!
    expect(last_response.body).to include('✓ Approved (Cancel)')
  end

  it 'renders unstaged diff' do
    # Make changes to the working directory
    Dir.chdir(repo_path) do
      File.write('file.txt', "unstaged change\n")
    end
    
    get '/diff/unstaged', path: repo_path
    expect(last_response).to be_ok
    expect(last_response.body).to include('Unstaged Changes for feat')
    expect(last_response.body).to include('_uncommited.md')
    expect(last_response.body).to include('unstaged')
    expect(last_response.body).to include('change')
  end

  it 'persists the last used path in session' do
    # First request
    get '/diff_router', path: '/dummy/path', mode: 'committed'
    
    # Check home page
    get '/'
    expect(last_response.body).to include('value="/dummy/path"')
  end

  it 'returns file content via API' do
    get '/api/file_content', {
      path: repo_path,
      file: 'file.txt',
      start: 1,
      end: 1,
      mode: 'committed'
    }
    expect(last_response).to be_ok
    data = JSON.parse(last_response.body)
    expect(data['lines']).to eq(['change'])
  end
end

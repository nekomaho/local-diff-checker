require 'spec_helper'
require 'tmpdir'
require_relative '../../lib/git_manager'

RSpec.describe GitManager do
  let(:repo_path) { Dir.mktmpdir }
  subject { GitManager.new(repo_path) }

  before do
    # Set up a Git repository for testing
    Dir.chdir(repo_path) do
      `git init`
      `git config user.email "test@example.com"`
      `git config user.name "Test User"`
      File.write('file.txt', 'base content')
      `git add file.txt`
      `git commit -m "Initial commit"`
      `git checkout -b feature`
      File.write('file.txt', 'new content')
      `git add file.txt`
      `git commit -m "Feature commit"`
    end
  end

  after do
    FileUtils.remove_entry(repo_path)
  end

  it 'detects if it is a git repository' do
    expect(subject.git_repo?).to be true
    expect(GitManager.new('/tmp').git_repo?).to be false if !Dir.exist?('/tmp/.git')
  end

  it 'gets current branch name' do
    expect(subject.current_branch).to eq 'feature'
  end

  it 'detects base branch' do
    # The feature branch should branch off from master (or main)
    # Since the default branch name might vary by environment,
    # consider creating it explicitly for testing.
    expect(subject.base_branch).to match(/master|main/)
  end

  it 'gets diff with base branch' do
    diff = subject.diff_with_base
    expect(diff).to include 'base content'
    expect(diff).to include 'new content'
  end
end

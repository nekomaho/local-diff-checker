require 'spec_helper'
require 'tmpdir'
require_relative '../../lib/markdown_storage'

RSpec.describe MarkdownStorage do
  let(:storage_dir) { Dir.mktmpdir }
  let(:prefix) { 'repo-branch-hash' }
  subject { MarkdownStorage.new(storage_dir) }

  after do
    FileUtils.remove_entry(storage_dir)
  end

  it 'generates the first filename correctly' do
    expect(subject.next_filename(prefix)).to eq "#{prefix}-1.md"
  end

  it 'saves and loads markdown with metadata and comments' do
    metadata = { branch: 'branch', base_commit: 'abc', current_commit: 'def' }
    diff_text = "some diff content"
    
    filename = subject.save(prefix, metadata, diff_text)
    expect(filename).to eq "#{prefix}-1.md"
    expect(File.exist?(File.join(storage_dir, filename))).to be true

    loaded = subject.load(filename)
    expect(loaded[:metadata][:branch]).to eq 'branch'
    expect(loaded[:diff]).to eq diff_text
  end

  it 'increments version when saving new diff' do
    metadata = { branch: 'branch', base_commit: 'abc', current_commit: 'def' }
    subject.save(prefix, metadata, "diff 1")
    
    # Returns (or updates) the same file if the commit hash is identical
    expect(subject.get_latest_file(prefix)[:filename]).to eq "#{prefix}-1.md"

    # When the commit hash changes
    new_metadata = { branch: 'branch', base_commit: 'abc', current_commit: 'xyz' }
    new_filename = subject.save(prefix, new_metadata, "diff 2")
    expect(new_filename).to eq "#{prefix}-2.md"
  end

  it 'adds comments to an existing markdown' do
    metadata = { branch: 'branch', base_commit: 'abc', current_commit: 'def' }
    filename = subject.save(prefix, metadata, "diff")
    
    subject.add_comment(filename, 'file.txt:L10', 'Nice change!')
    subject.add_comment(filename, 'file.txt:L10', 'Agree.')

    loaded = subject.load(filename)
    expect(loaded[:comments]['file.txt:L10']).to eq ['Nice change!', 'Agree.']
  end

  it 'updates an existing comment' do
    metadata = { branch: 'branch', base_commit: 'abc', current_commit: 'def' }
    filename = subject.save(prefix, metadata, "diff")
    subject.add_comment(filename, 'file.txt:L10', 'Old comment')
    
    subject.update_comment(filename, 'file.txt:L10', 0, 'Updated comment')
    
    loaded = subject.load(filename)
    expect(loaded[:comments]['file.txt:L10']).to eq ['Updated comment']
  end

  it 'deletes an existing comment' do
    metadata = { branch: 'branch', base_commit: 'abc', current_commit: 'def' }
    filename = subject.save(prefix, metadata, "diff")
    subject.add_comment(filename, 'file.txt:L10', 'Comment to delete')
    
    subject.delete_comment(filename, 'file.txt:L10', 0)
    
    loaded = subject.load(filename)
    expect(loaded[:comments]['file.txt:L10']).to be_nil
  end

  it 'handles filename with suffix correctly' do
    metadata = { branch: 'branch', current_commit: 'abc' }
    filename = subject.save(prefix, metadata, "unstaged diff", "_uncommited")
    
    expect(filename).to eq "#{prefix}-1_uncommited.md"
    expect(File.exist?(File.join(storage_dir, filename))).to be true

    # Confirm that getting the latest file also accounts for the suffix
    latest = subject.get_latest_file(prefix, "_uncommited")
    expect(latest[:filename]).to eq filename
    expect(latest[:content][:diff]).to eq "unstaged diff"
  end

  it 'separates files with and without suffix' do
    metadata = { branch: 'branch', current_commit: 'abc' }
    
    # Without suffix
    f1 = subject.save(prefix, metadata, "normal diff")
    # With suffix
    f2 = subject.save(prefix, metadata, "unstaged diff", "_uncommited")

    expect(f1).to eq "#{prefix}-1.md"
    expect(f2).to eq "#{prefix}-1_uncommited.md"
  end
end

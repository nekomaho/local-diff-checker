require 'spec_helper'
require 'fileutils'
require_relative '../../lib/markdown_storage'

RSpec.describe MarkdownStorage do
  let(:storage_dir) { File.expand_path('../../tmp/spec_data', __dir__) }
  let(:prefix) { 'repo-feature-hash' }
  subject { MarkdownStorage.new(storage_dir) }

  before do
    FileUtils.mkdir_p(storage_dir)
    FileUtils.rm_rf(Dir.glob("#{storage_dir}/*"))
  end

  # Commented out so that files are not deleted after tests (in case you want to check the contents)
  # after do
  #   FileUtils.remove_entry(storage_dir)
  # end

  it 'handles multi-line comments with code blocks correctly' do
    metadata = { branch: 'feature-test', base_commit: 'abc', current_commit: 'def' }
    filename = subject.save(prefix, metadata, "diff content")
    
    code_block_comment = <<~COMMENT
      Check this code:
      ```ruby
      def hello
        puts "world"
      end
      ```
    COMMENT
    
    subject.add_comment(filename, 'file.txt:L10', code_block_comment.strip)

    # Display the content of the saved file
    path = File.join(storage_dir, filename)
    file_content = File.read(path)
    puts "\n--- DEBUG: File saved at #{path} ---"
    puts "--- DEBUG: File Content ---"
    puts file_content
    puts "---------------------------\n"

    loaded = subject.load(filename)
    puts "--- DEBUG: Loaded Data ---"
    p loaded
    puts "--------------------------\n"

    expect(loaded[:comments]['file.txt:L10']).to eq [code_block_comment.strip]
  end
end

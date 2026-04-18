require 'spec_helper'
require_relative '../../lib/diff_parser'

RSpec.describe DiffParser do
  let(:diff_content) do
    <<~DIFF
      diff --git a/file.txt b/file.txt
      index 1234567..89abcde 100644
      --- a/file.txt
      +++ b/file.txt
      @@ -1,3 +1,3 @@
       base line 1
      -removed line 2
      +added line 2
       base line 3
    DIFF
  end

  subject { DiffParser.new(diff_content) }

  it 'parses diff into files and lines' do
    parsed = subject.parse
    expect(parsed.size).to eq 1
    file = parsed.first
    expect(file[:file]).to eq 'file.txt'
    
    lines = file[:lines]
    # In side-by-side view with a Hunk Header, the line count is 4 (@@... + base + diff + base)
    expect(lines.size).to eq 4
    
    # Line 0: hunk header
    expect(lines[0][:is_hunk]).to be true
    
    # Line 1: unmodified
    expect(lines[1][:left][:number]).to eq 1
    expect(lines[1][:right][:number]).to eq 1
    expect(lines[1][:left][:type]).to eq 'unmodified'
    
    # Line 2: removed & added (merged)
    expect(lines[2][:left][:number]).to eq 2
    expect(lines[2][:left][:type]).to eq 'removed'
    expect(lines[2][:right][:number]).to eq 2
    expect(lines[2][:right][:type]).to eq 'added'
    # Check if highlight is included
    expect(lines[2][:right][:content]).to include('inner-diff-highlight')
  end

  it 'highlights specific differences' do
    parser = DiffParser.new("")
    left, right = parser.send(:highlight_line_diff, "hello world", "hello ruby")
    # Matches up to "hello ", then identifies subsequent parts as changes
    expect(left).to include("<span class='inner-diff-highlight'>w</span>")
    expect(right).to include("<span class='inner-diff-highlight'>u</span>")
  end
end

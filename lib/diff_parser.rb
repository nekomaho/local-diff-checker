require 'diff/lcs'
require 'cgi'

class DiffParser
  def initialize(diff_text)
    @diff_text = diff_text
  end

  def parse
    files = []
    current_file = nil
    left_line_no = 0
    right_line_no = 0
    
    # For buffering
    pending_removals = []
    pending_additions = []

    return [] if @diff_text.nil?

    @diff_text.each_line do |line|
      if line.start_with?('diff --git')
        flush_pending(current_file, pending_removals, pending_additions) if current_file
        current_file = { file: line.split(' ').last.sub(/^b\//, ''), lines: [] }
        files << current_file
      elsif line.start_with?('@@')
        flush_pending(current_file, pending_removals, pending_additions) if current_file
        # Parse hunk header to get start line and line count for both old (-) and new (+) files.
        # Format: @@ -start,len +start,len @@
        match = line.match(/@@ -(\d+),?(\d*) \+(\d+),?(\d*) @@/)
        left_start = match[1].to_i
        left_count = (match[2] || "1").to_i
        right_start = match[3].to_i
        right_count = (match[4] || "1").to_i
        
        if current_file
          current_file[:lines] << {
            is_hunk: true,
            content: line.chomp,
            left: { type: 'hunk', start: left_start, count: left_count },
            right: { type: 'hunk', start: right_start, count: right_count }
          }
        end
        left_line_no = left_start
        right_line_no = right_start
      elsif line.start_with?('---') || line.start_with?('+++') || line.start_with?('index')
        next
      elsif current_file
        case line[0]
        when ' '
          flush_pending(current_file, pending_removals, pending_additions)
          current_file[:lines] << {
            left: { number: left_line_no, content: CGI.escapeHTML(line[1..-1].chomp), type: 'unmodified' },
            right: { number: right_line_no, content: CGI.escapeHTML(line[1..-1].chomp), type: 'unmodified' }
          }
          left_line_no += 1
          right_line_no += 1
        when '-'
          pending_removals << { number: left_line_no, content: line[1..-1].chomp }
          left_line_no += 1
        when '+'
          pending_additions << { number: right_line_no, content: line[1..-1].chomp }
          right_line_no += 1
        end
      end
    end
    flush_pending(current_file, pending_removals, pending_additions) if current_file
    files
  end

  private

  def flush_pending(file, removals, additions)
    while !removals.empty? || !additions.empty?
      if !removals.empty? && !additions.empty?
        # Synchronous display (pairing)
        rem = removals.shift
        add = additions.shift
        
        highlighted_left, highlighted_right = highlight_line_diff(rem[:content], add[:content])
        
        file[:lines] << {
          left: { number: rem[:number], content: highlighted_left, type: 'removed' },
          right: { number: add[:number], content: highlighted_right, type: 'added' }
        }
      elsif !removals.empty?
        rem = removals.shift
        file[:lines] << {
          left: { number: rem[:number], content: CGI.escapeHTML(rem[:content]), type: 'removed' },
          right: { number: nil, content: nil, type: 'empty' }
        }
      elsif !additions.empty?
        add = additions.shift
        file[:lines] << {
          left: { number: nil, content: nil, type: 'empty' },
          right: { number: add[:number], content: CGI.escapeHTML(add[:content]), type: 'added' }
        }
      end
    end
  end

  def highlight_line_diff(old_str, new_str)
    # Get character-level differences. Using sdiff makes the correspondence clear.
    diffs = Diff::LCS.sdiff(old_str.chars, new_str.chars)
    
    # Do not highlight if there are too many differences
    if diffs.size > 100
      return [CGI.escapeHTML(old_str), CGI.escapeHTML(new_str)]
    end

    left_res = ""
    right_res = ""
    
    diffs.each do |change|
      case change.action
      when '='
        left_res << CGI.escapeHTML(change.old_element)
        right_res << CGI.escapeHTML(change.new_element)
      when '!'
        left_res << "<span class='inner-diff-highlight'>#{CGI.escapeHTML(change.old_element)}</span>"
        right_res << "<span class='inner-diff-highlight'>#{CGI.escapeHTML(change.new_element)}</span>"
      when '-'
        left_res << "<span class='inner-diff-highlight'>#{CGI.escapeHTML(change.old_element)}</span>"
      when '+'
        right_res << "<span class='inner-diff-highlight'>#{CGI.escapeHTML(change.new_element)}</span>"
      end
    end

    [left_res, right_res]
  end
end

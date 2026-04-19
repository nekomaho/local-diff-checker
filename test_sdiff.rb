require 'diff/lcs'
require 'cgi'

def highlight_line_diff(old_str, new_str)
  diffs = Diff::LCS.sdiff(old_str.chars, new_str.chars)
  
  marker_start = "<"
  marker_end = ">"

  left_res = ""
  right_res = ""
  
  in_diff_left = false
  in_diff_right = false

  diffs.each do |change|
    # Left side
    case change.action
    when '=', '+'
      if in_diff_left
        left_res << marker_end
        in_diff_left = false
      end
      left_res << CGI.escapeHTML(change.old_element) if change.old_element && change.action == '='
    when '!', '-'
      if !in_diff_left
        left_res << marker_start
        in_diff_left = true
      end
      left_res << CGI.escapeHTML(change.old_element) if change.old_element
    end

    # Right side
    case change.action
    when '=', '-'
      if in_diff_right
        right_res << marker_end
        in_diff_right = false
      end
      right_res << CGI.escapeHTML(change.new_element) if change.new_element && change.action == '='
    when '!', '+'
      if !in_diff_right
        right_res << marker_start
        in_diff_right = true
      end
      right_res << CGI.escapeHTML(change.new_element) if change.new_element
    end
  end
  
  left_res << marker_end if in_diff_left
  right_res << marker_end if in_diff_right

  [left_res, right_res]
end

# Case 1: user's example
# If old was: marker_start = ""
# If new was: marker_start = "..."
# But user said "pure addition". 
# Maybe they mean adding the whole line? 
# But as I found, pure additions (no removal pair) don't call highlight_line_diff.
# So it MUST be paired with something.

puts "Test 1: marker_start"
old_l = 'marker_start = ""'
new_l = 'marker_start = "___DIFFSTART___"'
l, r = highlight_line_diff(old_l, new_l)
puts "Old: #{old_l}"
puts "New: #{new_l}"
puts "Res Old: #{l}"
puts "Res New: #{r}"

puts "\nTest 3: mismatched pairing"
# Old line is far from New line
old_l = "def old_method"
new_l = "marker_start = \"___DIFFSTART___\""
l, r = highlight_line_diff(old_l, new_l)
puts "Old: #{old_l}"
puts "New: #{new_l}"
puts "Res Old: #{l}"
puts "Res New: #{r}"

puts "\nTest 4: near-identical but different quotes"
old_l = "marker_start = ''"
new_l = "marker_start = \"\""
l, r = highlight_line_diff(old_l, new_l)
puts "Old: #{old_l}"
puts "New: #{new_l}"
puts "Res Old: #{l}"
puts "Res New: #{r}"

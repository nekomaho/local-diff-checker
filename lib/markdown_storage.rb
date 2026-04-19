require 'yaml'
require 'fileutils'

class MarkdownStorage
  def initialize(storage_dir)
    @storage_dir = storage_dir
    FileUtils.mkdir_p(@storage_dir)
  end

  def next_filename(prefix, suffix = nil)
    pattern = suffix ? "#{prefix}-*#{suffix}.md" : "#{prefix}-*.md"
    files = Dir.glob(File.join(@storage_dir, pattern))
    if suffix
      files = files.select { |f| f.end_with?("#{suffix}.md") }
    else
      files = files.select { |f| f =~ /-\d+\.md$/ }
    end

    if files.empty?
      suffix ? "#{prefix}-1#{suffix}.md" : "#{prefix}-1.md"
    else
      regex = suffix ? /-(\d+)#{Regexp.escape(suffix)}\.md$/ : /-(\d+)\.md$/
      numbers = files.map { |f| f.match(regex)[1].to_i }
      suffix ? "#{prefix}-#{numbers.max + 1}#{suffix}.md" : "#{prefix}-#{numbers.max + 1}.md"
    end
  end

  def get_latest_file(prefix, suffix = nil)
    pattern = suffix ? "#{prefix}-*#{suffix}.md" : "#{prefix}-*.md"
    files = Dir.glob(File.join(@storage_dir, pattern))
    
    if suffix
      files = files.select { |f| f.end_with?("#{suffix}.md") }
    else
      files = files.select { |f| f =~ /-\d+\.md$/ }
    end

    return nil if files.empty?

    regex = suffix ? /-(\d+)#{Regexp.escape(suffix)}\.md$/ : /-(\d+)\.md$/
    latest_path = files.max_by { |f| f.match(regex)[1].to_i }
    { filename: File.basename(latest_path), content: load(File.basename(latest_path)) }
  end

  def save(prefix, metadata, diff_text, suffix = nil)
    latest = get_latest_file(prefix, suffix)
    
    if latest && latest[:content][:metadata][:current_commit] == metadata[:current_commit] && 
       latest[:content][:diff].strip == diff_text.strip
      return latest[:filename]
    end

    filename = next_filename(prefix, suffix)
    # When creating a new file, inherit comments from the latest file
    initial_comments = latest ? latest[:content][:comments] : {}
    write_file(filename, metadata, diff_text, initial_comments)
    filename
  end

  def add_comment(filename, line_id, content)
    data = load(filename)
    data[:comments][line_id] ||= []
    data[:comments][line_id] << content
    write_file(filename, data[:metadata], data[:diff], data[:comments])
  end

  def update_comment(filename, line_id, index, new_content)
    data = load(filename)
    if data[:comments][line_id] && data[:comments][line_id][index]
      data[:comments][line_id][index] = new_content
      write_file(filename, data[:metadata], data[:diff], data[:comments])
    end
  end

  def delete_comment(filename, line_id, index)
    data = load(filename)
    if data[:comments][line_id] && data[:comments][line_id][index]
      data[:comments][line_id].delete_at(index)
      data[:comments].delete(line_id) if data[:comments][line_id].empty?
      write_file(filename, data[:metadata], data[:diff], data[:comments])
    end
  end

  def load(filename)
    path = File.join(@storage_dir, filename)
    content = File.read(path)
    
    parts = content.split(/^---$/)
    metadata = YAML.safe_load(parts[1], permitted_classes: [Symbol], symbolize_names: true)
    
    # Split by sections (extract using regular expressions)
    diff = ""
    comments = {}

    if content =~ /^# Diff Summary$(.*?)^# Comments$/m
      diff = $1.strip
    elsif content =~ /^# Diff Summary$(.*)/m
      diff = $1.strip
    end

    if content =~ /^# Comments$(.*)/m
      yaml_content = $1.strip
      if yaml_content.empty?
        comments = {}
      else
        begin
          loaded = YAML.safe_load(yaml_content, permitted_classes: [Symbol])
          comments = loaded.is_a?(Hash) ? loaded : {}
        rescue
          comments = parse_old_comments(yaml_content)
        end
      end
    end

    { metadata: metadata, diff: diff, comments: comments }
  end

  private

  def parse_old_comments(content)
    comments = {}
    current_line_id = nil
    content.each_line do |line|
      if match = line.match(/^## \[(.+)\]/)
        current_line_id = match[1]
        comments[current_line_id] = []
      elsif line.start_with?("- ") && current_line_id
        comments[current_line_id] << line.sub("- ", "").strip
      end
    end
    comments
  end

  def write_file(filename, metadata, diff_text, comments)
    path = File.join(@storage_dir, filename)
    
    comments_yaml = comments.empty? ? "" : comments.to_yaml.strip

    content = <<~MARKDOWN
      ---
      #{metadata.to_yaml.sub("---\n", "").strip}
      ---
      
      # Diff Summary
      #{diff_text}
      
      # Comments
      #{comments_yaml}
    MARKDOWN

    File.write(path, content)
  end
end

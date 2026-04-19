require 'open3'

class GitManager
  def initialize(path)
    @path = path
  end

  def git_repo?
    return false unless Dir.exist?(@path)
    Dir.chdir(@path) do
      _, status = Open3.capture2('git rev-parse --is-inside-work-tree')
      status.success?
    end
  rescue
    false
  end

  def current_branch
    Dir.chdir(@path) do
      branch, _ = Open3.capture2('git rev-parse --abbrev-ref HEAD')
      branch.strip
    end
  end

  def base_branch(provided_base = nil)
    return provided_base if provided_base && !provided_base.empty?
    default_branch
  end

  def default_branch
    Dir.chdir(@path) do
      # Try to get the default branch from origin
      stdout, status = Open3.capture2("git remote show origin | grep 'HEAD branch' | cut -d' ' -f5")
      if status.success? && !stdout.strip.empty?
        return stdout.strip
      end

      # Fallback to common names if no origin
      ['main', 'master', 'develop'].each do |b|
        _, s = Open3.capture2("git rev-parse --verify #{b}")
        return b if s.success?
      end
      
      # Final fallback to current branch
      current_branch
    end
  end

  def diff_with_base(base = nil)
    base ||= default_branch
    return nil unless base
    Dir.chdir(@path) do
      # Get unified diff (-U3) for split display
      diff, _ = Open3.capture2("git diff #{base}...HEAD")
      diff
    end
  end

  def diff_unstaged
    Dir.chdir(@path) do
      # Get unstaged changes, including newly added (untracked) files
      # git diff (unstaged) + git diff HEAD (staged)
      diff, _ = Open3.capture2("git diff HEAD")
      diff
    end
  end

  def has_unstaged_changes?
    Dir.chdir(@path) do
      # Check for changes
      stdout, _ = Open3.capture2("git status --short")
      !stdout.strip.empty?
    end
  end

  def merge_base_hash(base = nil)
    base ||= default_branch
    return nil unless base
    Dir.chdir(@path) do
      hash, _ = Open3.capture2("git merge-base #{base} HEAD")
      hash.strip
    end
  end

  def current_commit_hash
    Dir.chdir(@path) do
      hash, _ = Open3.capture2('git rev-parse HEAD')
      hash.strip
    end
  end

  def repo_name
    Dir.chdir(@path) do
      toplevel, _ = Open3.capture2('git rev-parse --show-toplevel')
      File.basename(toplevel.strip)
    end
  end

  def file_content(file_path, revision = 'HEAD')
    Dir.chdir(@path) do
      if revision.nil? # Working tree
        full_path = File.join(@path, file_path)
        return File.read(full_path) if File.exist?(full_path)
        return ""
      end
      stdout, stderr, status = Open3.capture3("git show #{revision}:#{file_path}")
      return "" unless status.success?
      stdout
    end
  end

  def line_count(file_path, revision = 'HEAD')
    content = file_content(file_path, revision)
    content.lines.size
  end
end

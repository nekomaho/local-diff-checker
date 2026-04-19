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

  def base_branch
    Dir.chdir(@path) do
      current = current_branch
      # User provided logic to find the parent branch
      cmd = "git show-branch | grep '*' | grep -v '#{current}' | head -1 | awk -F'[]~^[]' '{print $2}'"
      stdout, status = Open3.capture2(cmd)
      return nil unless status.success?
      
      base = stdout.strip
      base.empty? ? nil : base
    end
  end

  def diff_with_base
    base = base_branch
    return nil unless base
    Dir.chdir(@path) do
      # Get unified diff (-U3) for split display
      diff, _ = Open3.capture2("git diff #{base}..HEAD")
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

  def merge_base_hash
    base = base_branch
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
end

require 'open3'
require 'logger'

class GitSync
  def initialize(repo_path, branch = 'gh-pages')
    @repo_path = repo_path
    @branch = branch
    @logger = Logger.new('git_sync.log')
  end

  def sync_with_remote
    Dir.chdir(@repo_path) do
      begin
        # Store current changes
        stash_changes
        
        # Fetch latest changes
        fetch_remote
        
        # Clean untracked files that exist in remote
        clean_untracked_files
        
        # Pull latest changes
        pull_changes
        
        # Restore stashed changes
        restore_stashed_changes
        
        # Add all changes
        stage_changes
        
        # Commit and push
        commit_and_push
        
        @logger.info "Successfully synchronized with remote repository"
        return true, "Successfully synchronized with remote repository"
      rescue => e
        error_msg = "Error during git sync: #{e.message}"
        @logger.error error_msg
        @logger.error e.backtrace.join("\n")
        return false, error_msg
      end
    end
  end

  private

  def stash_changes
    return if working_directory_clean?
    
    @logger.info "Stashing changes..."
    run_command("git stash save 'Temporary stash before sync'")
    @had_stashed_changes = true
  end

  def fetch_remote
    @logger.info "Fetching from remote..."
    run_command("git fetch origin #{@branch}")
  end

  def clean_untracked_files
    @logger.info "Cleaning untracked files..."
    # Get list of untracked files that exist in remote
    untracked = run_command("git ls-files --others --exclude-standard").split("\n")
    remote_files = run_command("git ls-tree -r --name-only origin/#{@branch}").split("\n")
    
    # Remove only untracked files that exist in remote
    (untracked & remote_files).each do |file|
      File.delete(file) if File.exist?(file)
      @logger.info "Removed untracked file: #{file}"
    end
  end

  def pull_changes
    @logger.info "Pulling changes..."
    run_command("git pull origin #{@branch}")
  end

  def restore_stashed_changes
    return unless @had_stashed_changes
    
    @logger.info "Restoring stashed changes..."
    begin
      run_command("git stash pop")
      
      if has_conflicts?
        resolve_conflicts
      end
    rescue => e
      @logger.warn "Error while popping stash: #{e.message}"
      @logger.warn "Trying to apply stash instead..."
      run_command("git stash apply")
      run_command("git stash drop")
    end
  end

  def stage_changes
    @logger.info "Staging changes..."
    run_command("git add -A")
  end

  def commit_and_push
    return if working_directory_clean?
    
    @logger.info "Committing and pushing changes..."
    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    run_command(%Q{git commit -m "Updated gallery content - #{timestamp}"})
    run_command("git push origin #{@branch}")
  end

  def working_directory_clean?
    status = run_command("git status --porcelain")
    status.empty?
  end

  def has_conflicts?
    status = run_command("git status")
    status.include?("Unmerged paths") || status.include?("fix conflicts")
  end

  def resolve_conflicts
    @logger.info "Resolving conflicts..."
    # Always keep local version in case of conflicts
    run_command("git checkout --ours .")
    run_command("git add -A")
  end

  def run_command(cmd)
    stdout, stderr, status = Open3.capture3(cmd)
    
    unless status.success?
      @logger.error "Command failed: #{cmd}"
      @logger.error "STDERR: #{stderr}"
      raise "Command failed: #{stderr}"
    end
    
    stdout.strip
  end
end
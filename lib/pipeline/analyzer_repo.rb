class Pipeline::AnalyzerRepo

  BASE_DIR = ENV.fetch("ANALYZER_REPO_BASE_DIR", "./tmp/repos")

  attr_reader :repo_url

  def initialize(repo_url)
    @repo_url = repo_url
    puts repo_dir
  end

  def fetch!
    repo.fetch('origin')
  end

  def head
    head_commit.oid
  end

  def checkout(ref)
    repo.checkout(ref)
  end

  def workdir
    repo.workdir
  end

  private

  def repo
    @repo ||= if repo_dir_exists?
      Rugged::Repository.new(repo_dir)
    else
      Rugged::Repository.clone_at(repo_url, repo_dir)
    end
  rescue => e
    puts "Failed to clone repo #{repo_url}"
    puts e.message
    raise
  end

  def main_branch_ref
    "origin/master"
  end

  def repo_dir_exists?
    File.directory?(repo_dir)
  end

  def repo_dir
    "#{BASE_DIR}/#{url_hash}-#{local_name}"
  end

  def url_hash
    Digest::SHA1.hexdigest(repo_url)
  end

  def local_name
    repo_url.split("/").last
  end

end

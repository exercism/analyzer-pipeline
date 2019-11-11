class Pipeline::AnalyzerRepo

  BASE_DIR = ENV.fetch("ANALYZER_REPO_BASE_DIR", "./tmp/repos")

  attr_reader :repo_url

  def self.for_track(track_slug, suffix)
    repo_url = "https://github.com/exercism/#{track_slug}-#{suffix}"
    Pipeline::AnalyzerRepo.new(repo_url)
  end

  def initialize(repo_url)
    @repo_url = repo_url
    puts repo_dir
  end

  def fetch!
    repo.fetch('origin')
  end

  def checkout(ref)
    if tags[ref]
      oid = tags[ref]
      repo.checkout(oid)
      return oid
    else
      ref_pointer = repo.checkout(ref)
      return ref_pointer.target.target.oid
    end
  end

  def workdir
    repo.workdir
  end

  def tags
    return @tags if @tags
    @tags = {}
    repo.tags.each do |tag|
      @tags[tag.name] = tag.target.oid
    end
    @tags
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

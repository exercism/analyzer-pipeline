class Pipeline::BuildImage
  include Mandate

  attr_accessor :target_sha, :build_tag

  initialize_with :track_slug, :repo, :img

  def call
    @build_tag = "master"
    repo.fetch!
    checkout
    build
  end

  def checkout
    @target_sha = repo.checkout(build_tag)
  end

  def build
    Dir.chdir(repo.workdir) do
      img.build(local_tag)
    end
    local_tag
  end

  def local_tag
    "#{slug}:#{target_sha}"
  end

  def slug
    "#{track_slug}-analyzer-dev"
  end
end

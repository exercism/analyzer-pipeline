class Pipeline::AnalyzerBuild
  include Mandate

  attr_accessor :img, :target_sha, :build_tag, :image_tag

  initialize_with :track_slug

  def call
    setup_utilities
    build
    validate
    publish
  end

  def setup_utilities
    @img = Pipeline::Util::ImgWrapper.new
  end

  def build
    @build_tag = "master"
    @image_tag = Pipeline::BuildImage.(build_tag, image_name, repo, img)
  end

  def validate
    Pipeline::ValidateBuild.(image_tag, "fixtures/#{track_slug}")
  end

  def publish
    Pipeline::PublishImage.(img, image_name, image_tag, build_tag)
  end

  def image_name
    suffix = "-dev" unless ENV["env"] == "production"
    "#{track_slug}-analyzer#{suffix}"
  end

  memoize

  def repo
    repo_url = "https://github.com/exercism/#{track_slug}-analyzer"
    Pipeline::AnalyzerRepo.new(repo_url)
  end
end

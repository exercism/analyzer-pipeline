class Pipeline::AnalyzerBuild
  include Mandate

  attr_accessor :img, :runc, :target_sha, :build_tag, :image_tag

  initialize_with :track_slug

  def call
    setup_utiliies
    build
    validate
    publish
  end

  def setup_utiliies
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
    "#{track_slug}-analyzer-dev"
  end

  memoize
  def repo
    repo_url = "https://github.com/exercism/#{track_slug}-analyzer"
    Pipeline::AnalyzerRepo.new(repo_url)
  end
end

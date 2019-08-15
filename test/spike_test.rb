require 'test_helper'
require 'json'

module Pipeline
  class SpikeTest < Minitest::Test

    def test_build_image
      track_slug = "demo"
      demo_analyzer_repo = "/home/ccare/code/exercism/sample-analyzer"
      repo = Pipeline::AnalyzerRepo.new(demo_analyzer_repo)

      refute repo.nil?

      img = Pipeline::Util::ImgWrapper.new

      image_tag = Pipeline::BuildImage.(track_slug, repo, img)

      puts image_tag

      Pipeline::ValidateBuild.(image_tag, "fixtures/#{track_slug}")
    end

  end
end

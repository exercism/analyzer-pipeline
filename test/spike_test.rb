require 'test_helper'
require 'json'

module Pipeline
  class BuildAndValidateTest < Minitest::Test

    def test_build_and_validate_realish_image
      demo_analyzer_repo = "/home/ccare/code/exercism/sample-analyzer"
      repo = Pipeline::AnalyzerRepo.new(demo_analyzer_repo)
      img = Pipeline::Util::ImgWrapper.new
      image_tag = Pipeline::BuildImage.("master", "demo", repo, img)
      Pipeline::ValidateBuild.(image_tag, "test-fixtures/demo")
    end

  end
end

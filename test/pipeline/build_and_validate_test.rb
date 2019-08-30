require 'test_helper'
require 'json'

module Pipeline
  class BuildAndValidateTest < Minitest::Test

    def test_build_and_validate_realish_image
      demo_analyzer_repo = "https://github.com/exercism/stub-analyzer.git"
      repo = Pipeline::AnalyzerRepo.new(demo_analyzer_repo)
      img = Pipeline::Util::ImgWrapper.new
      image_tag = Pipeline::Build::BuildImage.("master", "demo", repo, img)
      Pipeline::Validation::ValidateBuild.(image_tag, "test-fixtures/demo")
    end

  end
end

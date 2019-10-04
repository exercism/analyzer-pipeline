require 'test_helper'
require 'json'

module Pipeline
  class BuildAndValidateTest < Minitest::Test

    def test_build_and_validate_realish_image
      demo_analyzer_repo = "https://github.com/exercism/stub-analyzer.git"
      repo = Pipeline::AnalyzerRepo.new(demo_analyzer_repo)
      logs = Pipeline::Util::LogCollector.new
      img = Pipeline::Util::ImgWrapper.new(logs)
      local_tag = Pipeline::Build::BuildImage.("master", "demo", repo, img)
      image_tag = "demo:#{local_tag}"
      Pipeline::Validation::ValidateBuild.(image_tag, "test-fixtures/demo")
    end

  end
end

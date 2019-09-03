require 'test_helper'
require 'json'

module Pipeline::Runtime
  class ReleaseAnalyzerTest < Minitest::Test

    attr_reader :env_base, :environment

    def setup
      FileUtils.rm_rf "/tmp/analyzer-env/"
      @env_base = "/tmp/analyzer-env/#{SecureRandom.hex}"
      @environment = RuntimeEnvironment.new(@env_base)
    end

    def test_prepare_creates_env_if_missing
      refute File.directory?(env_base)
      environment.prepare
      assert File.directory?(env_base)
    end

    # def test_release_latest_analyzer
    #   demo_analyzer_repo = "https://github.com/exercism/stub-analyzer.git"
    #   repo = Pipeline::AnalyzerRepo.new(demo_analyzer_repo)
    #   img = Pipeline::Util::ImgWrapper.new
    #
    #   environment.release_analyzer("demo")
    #   assert File.directory?("#{env_base}/demo")
    #   assert File.directory?("#{env_base}/demo/releases")
    #   releases = Dir["#{env_base}/demo/releases"]
    #   assert_equal 1, releases.size
    # end

  end
end

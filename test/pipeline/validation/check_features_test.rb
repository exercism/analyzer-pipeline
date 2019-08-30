require 'test_helper'
require 'json'

module Pipeline::Validation
  class CheckFixturesTest < Minitest::Test

    attr_reader :img, :runc, :container_driver

    def setup
      track_slug = "demo"
      demo_analyzer_repo = "https://github.com/exercism/stub-analyzer.git"
      repo = Pipeline::AnalyzerRepo.new(demo_analyzer_repo)
      workdir = "/tmp/analyzer-scratch/#{SecureRandom.uuid}"

      @img = Pipeline::Util::ImgWrapper.new
      @runc = Pipeline::Util::RuncWrapper.new
      configurator = Pipeline::Util::RuncConfigurator.new
      configurator.seed_from_env

      image_tag = Pipeline::Build::BuildImage.("master", track_slug, repo, img)

      @container_driver = Pipeline::Util::ContainerDriver.new(runc, img, configurator, workdir)
      container_driver.prepare_workdir
      container_driver.unpack_image(image_tag)
    end

    def test_checks_when_ok
      Pipeline::Validation::CheckFixtures.(container_driver, "test-fixtures/demo-ok")
    end

    def test_checks_fails_when_status_incorrect
      err = assert_raises FixtureCheckError do
         Pipeline::Validation::CheckFixtures.(container_driver, "test-fixtures/demo-failure")
      end
      expected_message = "Incorrect status (<approve> not <unapprove>) when validating test-fixtures/demo-failure/approval/example1"
      assert_equal expected_message, err.message
    end

    def test_checks_fails_when_comments_incorrect
      err = assert_raises FixtureCheckError do
         Pipeline::Validation::CheckFixtures.(container_driver, "test-fixtures/demo-failure2")
      end
      expected_message = "Incorrect comments when validating test-fixtures/demo-failure2/disapprove-comments/example1. Got: [{\"comment\":\"demo.sample.comment\",\"params\":{\"p1\":\"hello\"}}]"
      assert_equal expected_message, err.message
    end

  end
end

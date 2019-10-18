require 'test_helper'
require 'json'

module Pipeline::Build
  class AnalyzerBuildTest < Minitest::Test

    def setup
      @repo = mock()
      @container_repo = mock()
        # @container_repo = Pipeline::ContainerRepo.instance_for(container_slug, credentials)
        # @container_repo = Pipeline::ContainerRepo.new(image_name)
      @cmd = AnalyzerBuild.new("v0.1.1", "demotrack", @repo, @container_repo)
    end

    def test_call_invokes_each_phase
      @cmd.img = mock()
      @cmd.img.expects(:logs).returns(stub())

      @cmd.expects(:setup_utilities)
      @cmd.expects(:setup_remote_repo)
      @cmd.expects(:check_tag_exists)
      @cmd.expects(:already_built?)
      @cmd.expects(:build)
      @cmd.expects(:validate)
      @cmd.expects(:publish)
      @cmd.call()
    end

    def test_check_tag_permits_master_branch
      @analyzer_repo = Pipeline::AnalyzerRepo.for_track("demotrack")
      @cmd = AnalyzerBuild.new("master", "demotrack", @analyzer_repo, nil)
      @cmd.expects(:repo).never
      @cmd.check_tag_exists
    end

    def test_check_tag_exists
      stub_repo = stub(tags: {"v0.1.1" => "abcdef"})
      @cmd.expects(:repo).returns(stub_repo)
      @cmd.check_tag_exists
    end

    def test_check_tag_raises_if_tag_doesnt_exists
      stub_repo = stub(tags: {})
      @cmd.expects(:repo).returns(stub_repo)
      assert_raises(RuntimeError) do
        @cmd.check_tag_exists
      end
    end

    def test_setup_utilities
      assert_nil @cmd.img
      @cmd.setup_utilities()
      refute_nil @cmd.img
    end

    def test_build
      stub_repo = stub()
      stub_img = stub()
      @cmd.img = stub_img
      @cmd.expects(:repo).returns(stub_repo)
      Pipeline::Build::BuildImage.expects(:call).with("v0.1.1", "demotrack-analyzer-dev", stub_repo, stub_img)
      @cmd.build
    end

    def test_validate_delegates_correctly
      @cmd.image_tag = "my_image_tag"
      Pipeline::Validation::ValidateBuild.expects(:call).with("my_image_tag", "fixtures/demotrack")
      @cmd.validate
    end

    def test_publish_delegates_correctly
      stub_img = stub()
      @cmd.img = stub_img
      @cmd.local_tag = "build_tag"
      Pipeline::Build::PublishImage.expects(:call).with(stub_img, @container_repo, "build_tag", "v0.1.1")
      @cmd.publish
    end

    def test_image_name_defaults_to_dev_suffix
      assert_equal "demotrack-analyzer-dev", @cmd.image_name
    end

    def test_image_name_for_production
      old_env = ENV["env"]
      begin
        ENV["env"] = "production"
        assert_equal "demotrack-analyzer", @cmd.image_name
      ensure
        ENV["env"] = old_env
      end
    end

  end
end

require 'test_helper'
require 'json'

module Pipeline::Util
  class RuncConfiguratorTest < Minitest::Test

    attr_reader :configurator

    def setup
      @configurator = Pipeline::Util::RuncConfigurator.new
      configurator.uid_id = 888
      configurator.gid_id = 999
    end

    def test_can_set_uid_and_guid
      @configurator = Pipeline::Util::RuncConfigurator.new
      assert_nil configurator.uid_id
      assert_nil configurator.gid_id

      configurator.uid_id = 123
      configurator.gid_id = 456
      assert_equal 123, configurator.uid_id
      assert_equal 456, configurator.gid_id
    end

    # Probably platform dependent
    def test_can_seed_guid_and_uid
      @configurator = Pipeline::Util::RuncConfigurator.new
      assert_nil configurator.uid_id
      assert_nil configurator.gid_id

      configurator.seed_from_env
      refute configurator.uid_id.nil?
      refute configurator.gid_id.nil?
    end

    def test_build_config_has_correct_process_defaults
      config = configurator.build
      refute config.nil?

      assert_equal "1.0.1-dev",       config["ociVersion"]
      assert_equal "exercism-runner", config["hostname"]

      assert_equal 0,               config["process"]["user"]["uid"]
      assert_equal 0,               config["process"]["user"]["gid"]
      assert_equal true,            config["process"]["noNewPrivileges"]

      assert_equal "RLIMIT_NOFILE", config["process"]["rlimits"][0]["type"]
      assert_equal 1024,            config["process"]["rlimits"][0]["hard"]
      assert_equal 1024,            config["process"]["rlimits"][0]["soft"]

    end

    def test_build_config_has_correct_custom_mounts
      config = configurator.build
      refute config.nil?

      assert_equal "./rootfs", config["root"]["path"]
      assert_equal true,       config["root"]["readonly"]

      mounts = config["mounts"]
      refute mounts.nil?

      mount = mounts.select {|m| m["destination"] == "/mnt/exercism-iteration"}.first
      refute mount.nil?
      assert_equal "./iteration",     mount["source"]
      assert_equal [ "rbind", "rw" ], mount["options"]

      mount = mounts.select {|m| m["destination"] == "/tmp"}.first
      refute mount.nil?
      assert_equal "./tmp",     mount["source"]
      assert_equal [ "rbind", "rw" ], mount["options"]
    end

    def test_build_config_has_correct_custom_mounts
      config = configurator.build
      refute config.nil?

      assert_equal 0,   config["linux"]["uidMappings"][0]["containerID"]
      assert_equal 888, config["linux"]["uidMappings"][0]["hostID"]
      assert_equal 1,   config["linux"]["uidMappings"][0]["size"]

      assert_equal 0,   config["linux"]["gidMappings"][0]["containerID"]
      assert_equal 999, config["linux"]["gidMappings"][0]["hostID"]
      assert_equal 1,   config["linux"]["gidMappings"][0]["size"]
    end

    def test_build_config_has_correct_invocation
      configurator.invoke_analyzer_for("two-fer")

      config = configurator.build
      refute config.nil?

      assert_equal false,           config["process"]["terminal"]
      assert_equal "/opt/analyzer", config["process"]["cwd"]

      expected_args = ["bin/analyze.sh", "two-fer", "/mnt/exercism-iteration/"]

      assert_equal expected_args, config["process"]["args"]
    end

    def test_build_config_has_correct_invocation
      configurator.invoke_analyser_for("two-fer")

      config = configurator.build
      refute config.nil?

      assert_equal false,           config["process"]["terminal"]
      assert_equal "/opt/analyzer", config["process"]["cwd"]

      expected_args = ["bin/analyze.sh", "two-fer", "/mnt/exercism-iteration/"]

      assert_equal expected_args, config["process"]["args"]
    end

    def test_build_config_for_terminal_access
      configurator.setup_for_terminal_access

      config = configurator.build
      refute config.nil?

      assert_equal true,            config["process"]["terminal"]
      assert_equal "/opt/analyzer", config["process"]["cwd"]
      assert_equal ["/bin/bash"],   config["process"]["args"]
    end

    def test_build_config_for_test_scripting
      configurator.setup_bash_script("/opt/my_script.sh")

      config = configurator.build
      refute config.nil?

      expected_args = ["/bin/bash", "/opt/my_script.sh"]

      assert_equal false,            config["process"]["terminal"]
      assert_equal expected_args,   config["process"]["args"]
    end

  end
end

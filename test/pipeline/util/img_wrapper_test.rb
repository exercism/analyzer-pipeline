require 'test_helper'
require 'json'

module Pipeline::Util
  class ImgWrapperTest < Minitest::Test

    def setup
      @img = ImgWrapper.new
      @img.binary_path = "/path/to/img"
    end

    def test_push_cmd
      assert_equal "/path/to/img push -state /tmp/state-img", @img.push_cmd
    end

    def test_build_cmd
      assert_equal "/path/to/img build -state /tmp/state-img", @img.build_cmd
    end

    def test_tag_cmd
      assert_equal "/path/to/img tag -state /tmp/state-img", @img.tag_cmd
    end

    def test_push_cmd_with_custom_state
      @img.state_location = "/my/state"
      assert_equal "/path/to/img push -state /my/state", @img.push_cmd
    end

    def test_build_cmd
      @img.state_location = "/my/state"
      assert_equal "/path/to/img build -state /my/state", @img.build_cmd
    end

    def test_tag_cmd
      @img.state_location = "/my/state"
      assert_equal "/path/to/img tag -state /my/state", @img.tag_cmd
    end

    def test_exec_build
      @img.binary_path = "/bin/true"
      @img.suppress_output = true
      @img.build("my_tag")
    end

    def test_build_failure_raises
      @img.binary_path = "/bin/false"
      @img.state_location = "/my/state"
      @img.suppress_output = true
      assert_raises(RuntimeError) do
        @img.build("my_tag")
      end
    end

  end
end

require 'test_helper'
require 'json'

module Pipeline::Util
  class RuncWrapperTest < Minitest::Test

    def setup
      @runc = RuncWrapper.new
      @runc.binary_path = "/path/to/runc"
    end

    # def test_run_cmd
    #   assert %r{^/path/to/runc --root root-state run analyzer-\w+$}.match(@runc.run_cmd)
    # end

    def test_exec_build
      @runc.binary_path = "/bin/true"
      @runc.suppress_output = true
      @runc.run("/tmp/")
    end

    def test_build_failure_raises
      @runc.binary_path = "/bin/false"
      @runc.suppress_output = true
      assert_raises(RuntimeError) do
        @runc.run("/tmp/")
      end
    end

  end
end

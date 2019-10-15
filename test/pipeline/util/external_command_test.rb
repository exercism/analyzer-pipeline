require 'test_helper'
require 'json'

module Pipeline::Util
  class ExternalCommandTest < Minitest::Test

    def setup
    end

    def test_call
      cmd = ExternalCommand.new("/bin/true")
      cmd.suppress_output = true
      cmd.call!
      assert_equal 0, cmd.exit_status
      assert cmd.success?
    end

    def test_call_with_failure
      cmd = ExternalCommand.new("/bin/false")
      cmd.suppress_output = true
      cmd.call
      assert_equal 1, cmd.exit_status
      refute cmd.success?
    end

    def test_call_with_failure_raises
      cmd = ExternalCommand.new("/bin/false")
      cmd.suppress_output = true
      assert_raises(RuntimeError) do
        cmd.call!
      end
      assert_equal 1, cmd.exit_status
      refute cmd.success?
    end

    def test_captures_empty_stdout_and_stderr
      cmd = ExternalCommand.new("/bin/true")
      cmd.suppress_output = true
      cmd.call!
      assert cmd.success?
      assert_equal "", cmd.stdout
      assert_equal "", cmd.stderr
    end

    def test_captures_stdout_and_stderr_from_echo
      cmd = ExternalCommand.new("/bin/echo 'hello'")
      cmd.suppress_output = true
      cmd.call!
      assert cmd.success?
      assert_equal "hello\n", cmd.stdout
      assert_equal "", cmd.stderr
    end

    def test_captures_stdout_and_stderr_from_echo
      cmd = ExternalCommand.new("/bin/echo 'hello' >&2")
      cmd.suppress_output = true
      cmd.call!
      assert cmd.success?
      assert_equal "", cmd.stdout
      assert_equal "hello\n", cmd.stderr
    end

    def test_runs_with_timeout
      cmd = ExternalCommand.new("/bin/sleep 5")
      cmd.timeout = 10
      cmd.suppress_output = true
      cmd.call!
      assert cmd.success?
    end

    def test_cancels_run_with_timeout
      cmd = ExternalCommand.new("/bin/sleep 5")
      cmd.timeout = 2
      cmd.suppress_output = true
      cmd.call
      refute cmd.success?
      assert_equal 124, cmd.exit_status
    end

  end
end

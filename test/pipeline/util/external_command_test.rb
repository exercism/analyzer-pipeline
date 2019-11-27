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
      assert_nil cmd.exit_status
    end

    def test_stdout_hard_limit
      cmd = ExternalCommand.new("/bin/sh -c \"echo 'hello'; sleep 4; echo 'world'\"")
      cmd.suppress_output = true
      cmd.stdout_limit = 4
      cmd.call
      refute cmd.success?
      assert cmd.killed?
      assert_equal "hello\n", cmd.stdout
      assert_equal "", cmd.stderr
    end

    def test_hard_limits_for_real
      verbose_command = 'perl -w -e \'$i = 0; while ($i<1000000) { print "x"; $i++ };  print "\n"; $i = 0; while ($i<10000) { print STDERR "y"; $i++ }\''

      # Run without limits
      cmd = ExternalCommand.new(verbose_command)
      cmd.suppress_output = true
      cmd.call
      assert cmd.success?
      refute cmd.killed?
      assert_equal 1000001, cmd.stdout.size
      assert_equal 10000, cmd.stderr.size

      # limit stdout
      cmd = ExternalCommand.new(verbose_command)
      cmd.suppress_output = true
      cmd.stdout_limit = 1000
      cmd.call
      refute cmd.success?
      assert cmd.killed?
      # should be truncated between block 1 and 2
      assert cmd.stdout.size < 2000
      assert_equal 0, cmd.stderr.size

      # limit stderr
      cmd = ExternalCommand.new(verbose_command)
      cmd.suppress_output = true
      cmd.stderr_limit = 1000
      cmd.call
      refute cmd.success?
      assert cmd.killed?
      assert_equal 1000001, cmd.stdout.size
      assert cmd.stderr.size < 2000
    end


  end
end

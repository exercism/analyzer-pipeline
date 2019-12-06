require 'open3'

module Pipeline::Util
  class ExternalCommand

    BLOCK_SIZE = 1024

    attr_accessor :cmd_string, :status, :stdout, :stderr, :suppress_output,
                  :stderr_limit, :stdout_limit

    def initialize(cmd_string)
      @cmd_string = cmd_string
      @stdout_limit = -1
      @stderr_limit = -1
    end

    def call!
      call
      raise "Failed #{cmd_string}" unless status.success?
    end

    def call
      invoke_process
      puts "status: #{status}" unless suppress_output
      puts "stdout: #{stdout}" unless suppress_output
      puts "stderr: #{stderr}" unless suppress_output
    end

    def cmd
      if @timeout
        "/usr/bin/timeout -s 9 -k #{@timeout + 1} #{@timeout} #{cmd_string}"
      else
        cmd_string
      end
    end

    def success?
      status && status.success?
    end

    def killed?
      !! @killed
    end

    def exit_status
      status.exitstatus
    end

    def timeout=(timeout)
      @timeout = timeout
    end

    def report
      {
        cmd: cmd_string,
        success: success?,
        stdout: fix_encoding(stdout),
        stderr: fix_encoding(stderr)
      }
    end

    private

    def fix_encoding(text)
      return nil if text.nil?
      text.force_encoding("ISO-8859-1").encode("UTF-8")
    rescue => e
      puts e.message
      puts e.backtrace
      "--- failed to encode as UTF-8: #{e.message} ---"
    end

    def invoke_process
      c = cmd
      captured_stdout = []
      captured_stderr = []
      stdout_size = 0
      stderr_size = 0
      puts "> #{c}"  unless suppress_output
      Open3.popen3(c) do |_stdin, _stdout, _stderr, wait_thr|
        pid = wait_thr.pid
        _stdin.close_write

        begin
          files = [_stdout, _stderr]

          until files.find { |f| !f.eof }.nil? || @killed do
            ready = IO.select(files)

            if ready
              readable = ready[0]
              readable.each do |f|
                begin
                  data = f.read_nonblock(BLOCK_SIZE)
                  if f == _stdout
                    unless @killed
                      captured_stdout << data
                      stdout_size += data.size
                      if stdout_limit > 0 && stdout_size > stdout_limit
                        Process.kill("KILL", wait_thr.pid)
                        @killed = true
                      end
                    end
                  end
                  if f == _stderr
                    unless @killed
                      captured_stderr << data
                      stderr_size += data.size
                      if stderr_limit > 0 && stderr_size > stderr_limit
                        Process.kill("KILL", wait_thr.pid)
                        @killed = true
                      end
                    end
                  end
                rescue EOFError => e
                end
              end
            end
          end
        rescue IOError => e
          puts "IOError: #{e}"
        ensure
          @stdout = captured_stdout.join
          @stderr = captured_stderr.join
          @status = wait_thr.value
        end
      end
    end
  end
end

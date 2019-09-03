module Pipeline::Util
  class ExternalCommand

    attr_accessor :cmd_string, :status, :stdout, :stderr, :suppress_output

    def initialize(cmd_string)
      @cmd_string = cmd_string
    end

    def call!
      call
      raise "Failed #{cmd_string}" unless status.success?
    end

    def call
      c = cmd
      puts "> #{c}"  unless suppress_output
      @stdout, @stderr, @status = Open3.capture3(c)
      puts "status: #{status}" unless suppress_output
      puts "stdout: #{stdout}" unless suppress_output
      puts "stderr: #{stderr}" unless suppress_output
    end

    def cmd
      if @timeout
        "timeout --foreground -s 9 #{@timeout} #{cmd_string}"
      else
        cmd_string
      end
    end

    def success?
      status.success?
    end

    def exit_status
      status.exitstatus
    end

    def timeout=(timeout)
      @timeout = timeout
    end
  end
end
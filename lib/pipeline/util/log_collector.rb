module Pipeline::Util
  class LogCollector

    def initialize
      @logs = []
    end

    def <<(external_result)
      @logs << {
        cmd: external_result.cmd_string,
        success: external_result.success?,
        stdout: external_result.stdout,
        stderr:  external_result.stderr
      }
    end

    def inspect
      @logs
    end

  end
end

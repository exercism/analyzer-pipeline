module Pipeline::Util
  class RuncWrapper
    attr_accessor :binary_path, :suppress_output

    def initialize
      @binary_path = File.expand_path "./opt/runc"
      @suppress_output = false
    end

    def run(container_folder)
      Dir.chdir(container_folder) do
        exec_cmd run_cmd
      end
    end

    def run_cmd
      "#{binary_path} --root root-state run analyzer-#{Time.now.to_i}"
    end

    def exec_cmd(cmd)
      puts "> #{cmd}" unless suppress_output
      puts "------------------------------------------------------------" unless suppress_output
      success = system({}, cmd)
      raise "Failed #{cmd}" unless success
    end

  end

end

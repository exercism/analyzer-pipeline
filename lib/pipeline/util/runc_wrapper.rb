module Pipeline::Util
  class RuncWrapper
    attr_accessor :binary_path, :suppress_output, :memory_limit

    def initialize
      @binary_path = File.expand_path "./opt/runc"
      @suppress_output = false
      @memory_limit = 3000000
    end

    def run(container_folder)
      container_id = "analyzer-#{Time.now.to_i}"

      run_cmd = ExternalCommand.new("bash -x -c 'ulimit -v #{memory_limit}; #{binary_path} --root root-state run #{container_id}'")
      run_cmd.timeout = 5

      kill_cmd = ExternalCommand.new("#{binary_path} --root root-state kill #{container_id} KILL")

      Dir.chdir(container_folder) do
        begin
          run_cmd.call
        ensure
          kill_cmd.call
        end
      end

      run_cmd
    end

  end

end

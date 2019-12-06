module Pipeline::Util
  class RuncWrapper
    attr_accessor :binary_path, :suppress_output, :memory_limit

    def initialize(logs)
      @binary_path = "/opt/container_tools/runc"
      @suppress_output = false
      @memory_limit = 3000000
      @logs = logs || Pipeline::Util::LogCollector.new
    end

    def run(container_folder)
      container_id = "analyzer-#{Time.now.to_i}"

      actual_command = "#{binary_path} --root root-state run #{container_id}"
      run_cmd = ExternalCommand.new("bash -x -c 'ulimit -v #{memory_limit}; #{actual_command}'")
      run_cmd.timeout = 5
      run_cmd.stdout_limit = 1024*1024
      run_cmd.stderr_limit = 1024*1024

      kill_cmd = ExternalCommand.new("#{binary_path} --root root-state kill #{container_id} KILL")

      Dir.chdir(container_folder) do
        puts "HERE: #{@logs}" + @logs.class.to_s
        begin
          run_cmd.call
        rescue => e
          puts e.message
          puts "HERE"
          puts " --------- "
          raise
        ensure
          @logs << run_cmd
          kill_cmd.call
        end
      end

      run_cmd
    end

  end

end

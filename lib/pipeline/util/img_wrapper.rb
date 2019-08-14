module Pipeline::Util
  class ImgWrapper
    attr_accessor :binary_path, :state_location

    def initialize
      @binary_path = File.expand_path "./opt/img"
      @state_location = "/tmp/state-img"
    end

    def build(local_tag)
      cmd = "#{build_cmd} -t #{local_tag} ."
      exec_cmd cmd
    end

    def push_cmd
      "#{binary_path} push -state /tmp/state-img"
    end

    def build_cmd
      "#{binary_path} build -state /tmp/state-img"
    end

    def tag_cmd
      "#{binary_path} tag -state /tmp/state-img"
    end

    def exec_cmd(cmd)
      puts "> #{cmd}"
      puts "------------------------------------------------------------"
      success = system({}, cmd)
      raise "Failed #{cmd}" unless success
    end

  end

end

module Pipeline::Util
  class ImgWrapper
    attr_accessor :binary_path, :state_location, :suppress_output

    def initialize
      @binary_path = File.expand_path "./opt/img"
      @state_location = "/tmp/state-img"
      @suppress_output = false
    end

    def build(local_tag)
      cmd = "#{build_cmd} -t #{local_tag} ."
      exec_cmd cmd
    end

    def unpack(local_tag)
      exec_cmd "#{binary_path} unpack -state #{state_location} #{local_tag}"
    end

    def push_cmd
      "#{binary_path} push -state #{state_location}"
    end

    def push_cmd
      "#{binary_path} push -state #{state_location}"
    end

    def build_cmd
      "#{binary_path} build -state #{state_location}"
    end

    def tag_cmd
      "#{binary_path} tag -state #{state_location}"
    end

    def exec_cmd(cmd)
      puts "> #{cmd}" unless suppress_output
      puts "------------------------------------------------------------" unless suppress_output
      success = system({}, cmd)
      raise "Failed #{cmd}" unless success
    end

  end

end

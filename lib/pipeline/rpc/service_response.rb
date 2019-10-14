module Pipeline::Rpc
  class ServiceResponse

    def self.recv(socket)
      msg = ""
      socket.recv_string(msg)
      self.new(msg, socket)
    end

    attr_reader :parsed_msg

    def initialize(raw_msg, socket)
      @raw_msg = raw_msg
      @socket = socket
      @parsed_msg = JSON.parse(raw_msg)
    end

    def type
      @parsed_msg["msg_type"]
    end

    def return_address
      @parsed_msg["return_address"]
    end

    def binary_return_address
      return_address.pack("c*")
    end

    def raw_msg
      @raw_msg
    end

  end
end

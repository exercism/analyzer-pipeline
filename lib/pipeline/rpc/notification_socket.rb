module Pipeline::Rpc
  class NotificationSocket

    attr_reader :socket

    def initialize(zmq_context, port)
      @zmq_context = zmq_context
      @port = port
      @socket = zmq_context.socket(ZMQ::PUB)
      @socket.bind("tcp://*:#{@port}")
    end

    def emit(msg)
      raw = msg.to_json
      puts "SENDING #{raw}"
      @socket.send_string(raw)
    end

  end
end

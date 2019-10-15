module Pipeline::Rpc
  class FrontEndSocket

    attr_reader :socket

    def initialize(zmq_context, front_end_port)
      @socket = zmq_context.socket(ZMQ::ROUTER)
      @socket.bind("tcp://*:#{front_end_port}")
    end

    def recv
      msg = []
      @socket.recv_strings(msg)
      FrontEndRequest.new(msg, @socket)
    end

  end
end

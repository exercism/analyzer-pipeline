module Pipeline::Rpc
  class ResponseSocket

    attr_reader :socket

    def initialize(zmq_context, response_port)
      @zmq_context = zmq_context
      @response_port = response_port
      @socket = zmq_context.socket(ZMQ::SUB)
      @socket.setsockopt(ZMQ::SUBSCRIBE, "")
      @socket.bind("tcp://*:#{@response_port}")
    end

    def recv
      msg = ""
      @socket.recv_string(msg)
      ServiceResponse.new(msg, @socket)
    end

    def run_heartbeater
      puts "STARTING heartbeat_socket"
      heartbeat_socket = @zmq_context.socket(ZMQ::PUB)
      heartbeat_socket.connect("tcp://127.0.0.1:#{@response_port}")
      sleep 2
      loop do
        heartbeat_socket.send_string({ msg_type: "heartbeat" }.to_json)
        puts "ping heartbeat"
        sleep 10
      end
    end

  end
end

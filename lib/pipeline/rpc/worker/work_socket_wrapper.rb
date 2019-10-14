module Pipeline::Rpc::Worker
  class WorkSocketWrapper

    attr_reader :socket

    def initialize(socket)
      @socket = socket
    end

    def recv
      msg = []
      @socket.recv_strings(msg)

      puts "1 Received request. Data: #{msg.inspect}"
      return_address = msg[0].unpack('c*')
      puts "return_address: #{return_address}"
      raw_request = msg[2]
      request = JSON.parse(raw_request)
      action = request["action"]

      if action == "configure"
        ConfigureAction.new
      elsif action == "analyze_iteration" || action == "test_solution"
        a = AnalyzeAction.new(request, return_address)
        a.request = request
        a
      else
        puts "HERE ELSE: #{request}"
      end
    end

  end
end

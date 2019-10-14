module Pipeline::Rpc::Worker
  class NotificationSocketWrapper

    attr_reader :socket

    def initialize(socket)
      @socket = socket
    end

    def recv
      msg = ""
      @socket.recv_string(msg)

      puts "1 Received request. Data: #{msg.inspect}"
      request = JSON.parse(msg)
      action = request["action"]

      puts "HERE #{action}"
      if action == "configure"
        a = Pipeline::Rpc::Worker::ConfigureAction.new
        a.request = request
        a
      elsif action == "analyze_iteration" || action == "test_solution"
        a = Pipeline::Rpc::Worker::AnalyzeAction.new(request, return_address)
        a
      else
        puts "HERE ELSE: #{request}"
      end
    end

  end

end

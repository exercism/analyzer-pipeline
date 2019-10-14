module Pipeline::Rpc::Worker
  class NotificationSocketWrapper

    attr_reader :socket, :channel

    def initialize(socket, channel)
      @socket = socket
      @channel = channel
    end

    def recv
      msg = ""
      @socket.recv_string(msg)

      puts "1 Received request. Data: #{msg.inspect}"
      request = JSON.parse(msg)
      action = request["action"]

      if action == "configure"
        a = Pipeline::Rpc::Worker::ConfigureAction.new(channel, request)
        a.request = request
        a
      else
        puts "HERE ELSE: #{request}"
      end
    end

  end

end

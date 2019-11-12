module Pipeline::Rpc::Worker
  class NotificationSocketWrapper

    attr_reader :socket, :channel, :topic_scopes

    def initialize(socket, channel, topic_scopes)
      @socket = socket
      @channel = channel
      @topic_scopes = topic_scopes
      @start_at = Time.now.to_i
    end

    def recv
      msg = ""
      @socket.recv_string(msg)

      puts "1 Received request. Data: #{msg.inspect}"
      request = JSON.parse(msg)
      action = request["action"]

      if action == "configure"

        force_restart_at = request["force_restart_at"]
        if force_restart_at && force_restart_at > @start_at
          raise DaemonRestartException
        end


        a = Pipeline::Rpc::Worker::ConfigureAction.new(channel, request, topic_scopes)
        a.request = request
        a
      else
        puts "HERE ELSE: #{request}"
        exit 1
      end
    end

  end

end

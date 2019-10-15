module Pipeline::Rpc
  class ChannelPoller

    def initialize
      @poller = ZMQ::Poller.new
      @socket_wrappers = {}
    end

    def register(socket_wrapper)
      socket = socket_wrapper.socket
      @poller.register(socket, ZMQ::POLLIN)
      @socket_wrappers[socket] = socket_wrapper
    end

    def listen_for_messages
      loop do
        poll_result = @poller.poll
        break if poll_result == -1

        readables = @poller.readables
        continue if readables.empty?

        readables.each do |readable|
          socket_wrapper = @socket_wrappers[readable]
          unless socket_wrapper.nil?
            msg = socket_wrapper.recv
            yield(msg)
          end
        end
      end
    end
  end
end

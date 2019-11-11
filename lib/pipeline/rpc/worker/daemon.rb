module Pipeline::Rpc::Worker

  class Daemon

    attr_reader :identity, :context, :incoming, :outgoing, :environment

    def initialize(identity, channel_address, env_base)
      puts identity
      puts channel_address
      puts env_base
      @identity = identity
      channel_address = URI(channel_address)
      @control_queue = "#{channel_address.scheme}://#{channel_address.host}:#{channel_address.port}"
      @channel = channel_address.path[1..-1]
      @context = ZMQ::Context.new(1)
      @incoming = context.socket(ZMQ::PULL)
      @notifications = context.socket(ZMQ::SUB)
      @notifications.setsockopt(ZMQ::SUBSCRIBE, "")
      @environment = Pipeline::Runtime::RuntimeEnvironment.new(env_base)
    end

    def setup
      @setup = context.socket(ZMQ::REQ)
      @setup.setsockopt(ZMQ::LINGER, 0)
      puts @control_queue
      @setup.connect(@control_queue)
      request = {
        action: "configure_worker",
        channel: @channel
      }
      @setup.send_string(request.to_json)
      msg = ""
      @setup.recv_string(msg)
      msg = JSON.parse(msg)
      puts "Bootstrap with #{msg}"
      @setup.close

      environment.prepare

      action = Pipeline::Rpc::Worker::ConfigureAction.new(@channel, msg)
      action.environment = environment
      action.invoke

      response_address = msg["channel"]["response_address"]
      request_address = msg["channel"]["workqueue_address"]
      notification_address = msg["channel"]["notification_address"]
      @outgoing = context.socket(ZMQ::PUB)
      @outgoing.connect(response_address)
      incoming.connect(request_address)
      @notifications.connect(notification_address)

    end

    def listen
      setup

      @incoming_wrapper = Pipeline::Rpc::Worker::WorkSocketWrapper.new(incoming)
      @noificationincoming_wrapper = Pipeline::Rpc::Worker::NotificationSocketWrapper.new(@notifications, @channel)

      @poller = Pipeline::Rpc::ChannelPoller.new
      @poller.register(@incoming_wrapper)
      @poller.register(@noificationincoming_wrapper)

      loop do
        msg = []

        @poller.listen_for_messages do |action_task|
          puts "ACTION #{action_task}"
          unless action_task.nil?
            action_task.environment = environment
            result = action_task.invoke
            puts "RESULT #{result}"
            if result && result[:return_address]
              outgoing.send_string(result.to_json)
            end
          end
        end

      end
    end

  end
end

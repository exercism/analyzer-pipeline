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

      @topic = "*"
      if channel_address.query
        query = CGI::parse(channel_address.query)
        @topics = query["topic"] if query["topic"]
      end
      @topics = ["*"] if @topics.nil? || @topics.empty?

      @context = ZMQ::Context.new(1)
      @incoming = context.socket(ZMQ::PULL)
      @notifications = context.socket(ZMQ::SUB)
      @notifications.setsockopt(ZMQ::SUBSCRIBE, "")
      @environment = Pipeline::Runtime::RuntimeEnvironment.new(env_base)
    end

    def bootstrap_and_listen
      bootstrap
      configure
      connect
      poll_messages
    end

    def bootstrap
      @setup = context.socket(ZMQ::REQ)
      @setup.setsockopt(ZMQ::LINGER, 0)
      puts @control_queue
      @setup.connect(@control_queue)
      request = {
        action: "configure_worker",
        channel: @channel,
        topics: @topics
      }
      @setup.send_string(request.to_json)
      msg = ""
      @setup.recv_string(msg)
      parsed_msg = JSON.parse(msg)
      puts parsed_msg
      status_code = parsed_msg["status"]["status_code"]
      if status_code != 200
        puts "Error when configuring"
        puts "Recieved: #{msg}"
        raise "Got status #{status_code} when trying to configure"
      end
      @bootstrap = parsed_msg["response"]
      puts "Bootstrap with #{JSON.pretty_generate(@bootstrap)}"
      @setup.close
    end

    def configure
      environment.prepare
      action = Pipeline::Rpc::Worker::ConfigureAction.new(@channel, @bootstrap, @topics)
      action.environment = environment
      action.invoke
    end

    def listen
      connect
      start_status_publisher
      poll_messages
    end

    private

    def start_status_publisher
      Thread.new do
        channel_defn = @bootstrap["channel"]
        response_address = channel_defn["response_address"]
        workqueue_addresses  = channel_defn["workqueue_addresses"]
        notifier = context.socket(ZMQ::PUB)
        notifier.connect(response_address)
        loop do
          sleep 2
          msg = {
            msg_type: "worker_heartbeat",
            channel: @channel,
            topics: @topics,
            identity: identity,
            workqueue_addresses: workqueue_addresses,
            deployed_versions: environment.list_deployed_containers
          }
          notifier.send_string(msg.to_json)
          puts "SENT"
        end
      end
    end

    def connect
      channel_defn = @bootstrap["channel"]
      response_address = channel_defn["response_address"]
      workqueue_addresses  =channel_defn["workqueue_addresses"]
      notification_address = channel_defn["notification_address"]
      @outgoing = context.socket(ZMQ::PUB)
      @outgoing.connect(response_address)
      workqueue_addresses.each do |workqueue_address|
        incoming.connect(workqueue_address)
      end
      @notifications.connect(notification_address)

      @incoming_wrapper = Pipeline::Rpc::Worker::WorkSocketWrapper.new(incoming)
      @noificationincoming_wrapper = Pipeline::Rpc::Worker::NotificationSocketWrapper.new(@notifications, @channel, @topics)

      @poller = Pipeline::Rpc::ChannelPoller.new
      @poller.register(@incoming_wrapper)
      @poller.register(@noificationincoming_wrapper)
    end

    def poll_messages
      loop do
        msg = []
        @poller.listen_for_messages do |action_task|
          unless action_task.nil?
            action_task.environment = environment
            result = nil
            begin
              result = action_task.invoke
            rescue => e
              puts "Error in invoke"
              puts e.message
              puts e.backtrace
            end
            if result && result[:return_address]
              puts "RESULT #{result}"
              outgoing.send_string(result.to_json)
            end
          end
        end
      end
    end

  end
end

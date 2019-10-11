class Pipeline::Rpc::WorkerAction

  attr_accessor :environment, :request

  def invoke
  end

  def parse_credentials(request)
    raw_credentials = request["credentials"]
    key = raw_credentials["access_key_id"]
    secret = raw_credentials["secret_access_key"]
    session = raw_credentials["session_token"]
    Aws::Credentials.new(key, secret, session)
  end

end

class Pipeline::Rpc::AnalyzeAction < Pipeline::Rpc::WorkerAction

  attr_reader :reader, :return_address

  def initialize(request, return_address)
    @request = request
    @return_address = return_address
  end

  def invoke
    s3 = Aws::S3::Client.new(
      credentials: parse_credentials(request["context"]),
      region: "eu-west-1")

    language_slug = request["track_slug"]
    exercise_slug = request["exercise_slug"]
    solution_slug = request["solution_slug"]
    location = request["iteration_folder"]
    container_version = request["container_version"]

    unless environment.released?(language_slug, container_version)
      return {
        error: "Container #{language_slug}:#{container_version} isn't available"
      }
    end

    analysis_run = environment.new_invocation(language_slug, container_version, exercise_slug, solution_slug)
    analysis_run.prepare_iteration do |iteration_folder|
      location_uri = URI(location)
      bucket = location_uri.host
      path = location_uri.path[1..]
      params = {
        bucket: bucket,
        prefix: "#{path}/",
      }
      resp = s3.list_objects(params)
      resp.contents.each do |item|
        key = item[:key]
        filename = File.basename(key)
        s3.get_object({
          bucket: bucket,
          key: key,
          response_target: "#{iteration_folder}/#{filename}"
        })
      end
    end
    begin
      result = analysis_run.analyze!
      result["return_address"] = return_address
      result['msg_type'] = 'response'
      result
    rescue => e
      puts e
    ensure
      puts "DONE"
    end
  end

end

class Pipeline::Rpc::ConfigureAction < Pipeline::Rpc::WorkerAction

  def invoke
    spec = request["specs"]["analyzer_spec"]
    credentials = parse_credentials(request)
    raise "No spec received" if spec.nil?
    spec.each do |language_slug, versions|
      puts "Preparing #{language_slug} #{versions}"
      versions.each do |version|
        if environment.released?(language_slug, version)
          puts "Already installed #{language_slug}:#{version}"
        else
          puts "Installed #{language_slug}"
          environment.release_analyzer(language_slug, version, credentials)
        end
      end
    end
  end
end

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
      a = Pipeline::Rpc::ConfigureAction.new
      a.request = request
      a
    elsif action == "analyze_iteration" || action == "test_solution"
      a = Pipeline::Rpc::AnalyzeAction.new(request, return_address)
      a
    else
      puts "HERE ELSE: #{request}"
    end
  end

end

class SocketWrapper

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
      Pipeline::Rpc::ConfigureAction.new
    elsif action == "analyze_iteration" || action == "test_solution"
      a = Pipeline::Rpc::AnalyzeAction.new(request, return_address)
      a.request = request
      a
    else
      puts "HERE ELSE: #{request}"
    end
  end

end


class Pipeline::Rpc::Worker

  attr_reader :identity, :context, :incoming, :outgoing, :environment

  def initialize(identity, channel_address, env_base)
    @identity = identity
    channel_address = URI(channel_address)
    @control_queue = "#{channel_address.scheme}://#{channel_address.host}:#{channel_address.port}"
    @channel = channel_address.path[1..]
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

    action = Pipeline::Rpc::ConfigureAction.new
    action.environment = environment
    action.request = msg
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

    @incoming_wrapper = SocketWrapper.new(incoming)
    @noificationincoming_wrapper = NotificationSocketWrapper.new(@notifications)

    @poller = Pipeline::Rpc::ChannelPoller.new
    @poller.register(@incoming_wrapper)
    @poller.register(@noificationincoming_wrapper)

    loop do
      msg = []

      @poller.listen_for_messages do |action_task|
        # puts "1 Received request. Data: #{msg.inspect}"
        # return_address = msg[0].unpack('c*')
        # puts "return_address: #{return_address}"
        # raw_request = msg[2]
        # request = JSON.parse(raw_request)
        # action = request["action"]
        #
        # if action == "configure"
        #   action_task = Pipeline::Rpc::ConfigureAction.new
        # elsif action == "analyze_iteration" || action == "test_solution"
        #   action_task = Pipeline::Rpc::AnalyzeAction.new
        # else
        #   puts "HERE ELSE: #{request}"
        # end

        unless action_task.nil?
          action_task.environment = environment
          result = action_task.invoke
          if result && result["return_address"]
            outgoing.send_string(result.to_json)
          end
        end
      end

      # incoming.recv_strings(msg)
      # puts "2 Received request. Data: #{msg.inspect}"
      # return_address = msg[0].unpack('c*')
      # puts "return_address: #{return_address}"
      # raw_request = msg[2]
      # request = JSON.parse(raw_request)
      # action = request["action"]
      #
      # if action == "configure"
      #   action_task = Pipeline::Rpc::ConfigureAction.new
      # elsif action == "analyze_iteration" || action == "test_solution"
      #   action_task = Pipeline::Rpc::AnalyzeAction.new
      # else
      #   puts "HERE ELSE: #{request}"
      # end

      # continue if action_task.nil?
      #
      # action_task.environment = environment
      # action_task.request = request
      # result = action_task.invoke
      #
      # if result && return_address
      #   result["return_address"] = return_address
      #   result['msg_type'] = 'response'
      #   outgoing.send_string(result.to_json)
      # end

    end
  end

  def parse_credentials(request)
    raw_credentials = request["credentials"]
    key = raw_credentials["access_key_id"]
    secret = raw_credentials["secret_access_key"]
    session = raw_credentials["session_token"]
    Aws::Credentials.new(key, secret, session)
  end

  def analyze(request)
    action = Pipeline::Rpc::AnalyzeAction.new
    action.environment = environment
    action.request = request
    action.invoke
  end

end

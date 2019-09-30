class Pipeline::RpcServer

  attr_reader :context, :socket, :identity

  def initialize
    @context = ZMQ::Context.new(1)
    @socket = context.socket(ZMQ::REP)
    @identity = SecureRandom.uuid
  end

  def listen
    hostname = Socket.gethostname
    # socket.setsockopt(ZMQ::IDENTITY, identity)
    # socket.setsockopt(ZMQ::ROUTING_ID, identity)
    # socket.connect("tcp://localhost:5577")
    port = 5555
    bind_result = -1
    until bind_result != -1 || port > 5600
      port += 1
      # @identity = "#{port}"
      bind_result = socket.bind("tcp://*:#{port}")
    end
    address = "tcp://#{hostname}:#{port}"

    Thread.new do
      puts "STARTING"
      emitter = context.socket(ZMQ::PUB)
      emitter.connect("tcp://localhost:5555")
      sleep 2
      loop do
        emitter.send_string({ msg_type: "status", address: address, identity: identity}.to_json)
        puts "Sent"
        sleep 10
      end
    end

    loop do
      request = ''
      socket.recv_string(request)
      puts "Received request. Data: #{request.inspect}"
      if request.start_with? "build-analyzer_"
        _, track = request.split("_")
        result = Pipeline.build_analyzer(track)
        socket.send_string(result.to_json)
      elsif request.start_with? "build-test-runner_"
        _, track = request.split("_")
        result = Pipeline.build_test_runner(track)
        socket.send_string(result.to_json)
      elsif request.start_with? "release-analyzer_"
        _, arg = request.split("_")
        result = Pipeline.release(arg)
        socket.send_string(result.to_json)
      elsif request.start_with? "analyze_"
        _, arg = request.split("_", 2)
        track, exercise_slug, solution_slug, location = arg.split("|")
        result = Pipeline.analyze!(track, exercise_slug, solution_slug) do |iteration_folder|
          location_uri = URI(location)
          bucket = location_uri.host
          path = location_uri.path[1..]
          s3 = Aws::S3::Client.new(region: 'eu-west-1')
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
        socket.send_string(result.to_json)
      else
        socket.send_string("done")
      end
    end
    socket.send_string(msg)
  end

end

class Pipeline::RpcServer

  attr_reader :context, :socket

  def initialize
    @context = ZMQ::Context.new(1)
    @socket = context.socket(ZMQ::REP)
    socket.connect("tcp://localhost:5577")
  end

  def listen
    loop do
      request = ''
      socket.recv_string(request)
      sleep 10
      puts "Received request. Data: #{request.inspect}"
      if request.start_with? "build-analyzer_"
        _, arg = request.split("_")
        result = Pipeline.build_analyzer(arg)
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

class Pipeline::Rpc::Worker

  attr_reader :identity, :context, :incoming, :outgoing, :environment

  def initialize(identity, env_base)
    @identity = identity
    @context = ZMQ::Context.new(1)
    @incoming = context.socket(ZMQ::PULL)
    @outgoing = context.socket(ZMQ::PUB)
    @outgoing.connect("tcp://localhost:5555")
    @environment = Pipeline::Runtime::RuntimeEnvironment.new(env_base)
  end

  def setup
    @setup = context.socket(ZMQ::REQ)
    @setup.setsockopt(ZMQ::LINGER, 0)
    @setup.connect("tcp://localhost:5566")
    @setup.send_string("describe_analysers")
    msg = ""
    @setup.recv_string(msg)
    msg = JSON.parse(msg)
    analyzer_spec = msg["analyzer_spec"]
    credentials = parse_credentials(msg)
    @setup.close

    environment.prepare

    analyzer_spec.each do |language_slug, versions|
      puts "Preparing #{language_slug} #{versions}"
      versions.each do |version|
        if environment.released?(language_slug, version)
          puts "Already installed #{language_slug}"
        else
          puts "Installed #{language_slug}"
          environment.release_analyzer(language_slug, version, credentials)
        end
      end
    end
  end

  def listen
    setup
    incoming.connect("tcp://localhost:5577")

    loop do
      msg = []
      incoming.recv_strings(msg)
      puts "Received request. Data: #{msg.inspect}"
      return_address = msg[0].unpack('c*')
      raw_request = msg[2]
      request = JSON.parse(raw_request)
      action = request["action"]
      if action == "analyze_iteration"
        result = analyze(request)
        result["return_address"] = return_address
        result['msg_type'] = 'response'
        outgoing.send_string(result.to_json)
      else
        puts "HERE ELSE: #{request}"
      end
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
    s3 = Aws::S3::Client.new(
      credentials: parse_credentials(request),
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
      analysis_run.analyze!
    rescue => e
      puts e
    ensure
      puts "DONE"
    end
  end

end

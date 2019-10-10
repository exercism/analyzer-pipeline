class Pipeline::Rpc::Worker

  attr_reader :identity, :context, :incoming, :outgoing, :environment

  def initialize(identity, env_base)
    @identity = identity
    @context = ZMQ::Context.new(1)
    @incoming = context.socket(ZMQ::PULL)
    @environment = Pipeline::Runtime::RuntimeEnvironment.new(env_base)
  end

  def setup
    @setup = context.socket(ZMQ::REQ)
    @setup.setsockopt(ZMQ::LINGER, 0)
    @setup.connect("tcp://localhost:5566")
    request = {
      action: "configure_worker",
      role: "static_analyzer"
    }
    @setup.send_string(request.to_json)
    msg = ""
    @setup.recv_string(msg)
    msg = JSON.parse(msg)
    analyzer_spec = msg["analyzer_spec"]
    raise "No spec received" if analyzer_spec.nil?

    puts msg["channels"]
    response_address = msg["channels"]["response_address"]
    request_address = msg["channels"]["workqueue_address"]

    @outgoing = context.socket(ZMQ::PUB)
    @outgoing.connect(response_address)

    credentials = parse_credentials(msg)
    @setup.close

    environment.prepare

    configure_containers(analyzer_spec, credentials)
    # analyzer_spec.each do |language_slug, versions|
    #   puts "Preparing #{language_slug} #{versions}"
    #   versions.each do |version|
    #     if environment.released?(language_slug, version)
    #       puts "Already installed #{language_slug}:#{version}"
    #     else
    #       puts "Installed #{language_slug}"
    #       environment.release_analyzer(language_slug, version, credentials)
    #     end
    #   end
    # end


    incoming.connect(request_address)
  end

  def configure_containers(spec, credentials)
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

  def listen
    setup

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
      elsif action == "analyzer_spec"
        puts request
        puts "!!!!!"
        analyzer_spec = request["spec"]
        credentials = parse_credentials(request)
        configure_containers(analyzer_spec, credentials)
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
      analysis_run.analyze!
    rescue => e
      puts e
    ensure
      puts "DONE"
    end
  end

end

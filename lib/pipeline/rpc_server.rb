# class Pipeline::Rpc::Server
#
#   attr_reader :context, :incoming, :outgoing, :environment
#
#   def initialize(env_base)
#     @context = ZMQ::Context.new(1)
#     @incoming = context.socket(ZMQ::PULL)
#     @outgoing = context.socket(ZMQ::PUB)
#     @outgoing.connect("tcp://localhost:5555")
#     @environment = Pipeline::Runtime::RuntimeEnvironment.new(env_base)
#   end
#
#   def setup
#     @setup = context.socket(ZMQ::REQ)
#     @setup.setsockopt(ZMQ::LINGER, 0)
#     @setup.connect("tcp://localhost:5566")
#     @setup.send_string("describe_analysers")
#     msg = ""
#     @setup.recv_string(msg)
#     analyzer_spec = JSON.parse(msg)
#     puts analyzer_spec
#
#     environment.prepare
#
#     analyzer_spec.each do |language_slug, version|
#       if environment.released?(language_slug)
#         puts "Already installed #{language_slug}"
#       else
#         puts "Installed #{language_slug}"
#         environment.release_analyzer(language_slug)
#       end
#     end
#   end
#
#   def listen
#     setup
#     incoming.connect("tcp://localhost:5577")
#
#     loop do
#       msg = []
#       incoming.recv_strings(msg)
#       puts "Received request. Data: #{msg.inspect}"
#       return_address = msg[0].unpack('c*')
#       puts return_address
#       request = msg[2]
#       if request.start_with? "analyze_"
#         _, arg = request.split("_", 2)
#         track, exercise_slug, solution_slug, location = arg.split("|")
#         result = analyze(track, exercise_slug, solution_slug) do |iteration_folder|
#           location_uri = URI(location)
#           bucket = location_uri.host
#           path = location_uri.path[1..]
#           s3 = Aws::S3::Client.new(region: 'eu-west-1')
#           params = {
#             bucket: bucket,
#             prefix: "#{path}/",
#           }
#           resp = s3.list_objects(params)
#           resp.contents.each do |item|
#             key = item[:key]
#             filename = File.basename(key)
#             s3.get_object({
#               bucket: bucket,
#               key: key,
#               response_target: "#{iteration_folder}/#{filename}"
#             })
#           end
#         end
#         result["return_address"] = return_address
#         result['msg_type'] = 'response'
#         outgoing.send_string(result.to_json)
#       else
#         puts "HERE ELSE: #{request}"
#       end
#     end
#   end
#
#   def analyze(language_slug, exercise_slug, solution_slug)
#     analysis_run = environment.new_analysis(language_slug, exercise_slug, solution_slug)
#     analysis_run.prepare_iteration do |iteration_folder|
#       yield(iteration_folder)
#     end
#     begin
#       analysis_run.analyze!
#     rescue => e
#       puts e
#     ensure
#       # puts "---"
#       # puts analysis_run.stdout
#       # puts "==="
#       # puts analysis_run.stderr
#       # puts "---"
#       # puts analysis_run.success?
#       # puts analysis_run.exit_status
#       # puts analysis_run.result
#       puts "DONE"
#     end
#   end
#
# end

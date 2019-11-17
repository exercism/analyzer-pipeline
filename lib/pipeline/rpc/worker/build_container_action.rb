module Pipeline::Rpc::Worker

  class BuildContainerAction < WorkerAction

    attr_reader :reader, :return_address

    def initialize(request, return_address)
      @request = request
      @return_address = return_address
    end

    def invoke
      track_slug = request["track_slug"]
      channel = request["channel"]
      build_tag = request["git_reference"]
      puts "Building #{build_tag}"
      credentials = parse_credentials(request["context"])
      container_repo = Pipeline::Runtime::RuntimeEnvironment.container_repo(channel, track_slug, credentials)
      repo = Pipeline::Runtime::RuntimeEnvironment.source_repo(channel, track_slug)

      result = case channel
      when "static_analyzers"
        Pipeline::Build::AnalyzerBuild.(build_tag, track_slug, repo, container_repo)
      when "test_runners"
        Pipeline::Build::TestRunnerBuild.(build_tag, track_slug, repo, container_repo)
      when "representers"
        Pipeline::Build::RepresenterBuild.(build_tag, track_slug, repo, container_repo)
      else
        raise "Unknown channel: #{channel}"
      end
      response = {return_address: return_address}

      if @error
        response[:msg_type] = :error_response
        response.merge(@error)
      else
        response[:msg_type] = :response
        response[:return_address] = return_address
        response.merge(result)
      end
    end

  end
end

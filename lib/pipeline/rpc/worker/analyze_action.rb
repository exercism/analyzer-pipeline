module Pipeline::Rpc::Worker

  class AnalyzeAction < ContainerAction

    attr_reader :reader, :return_address

    def initialize(request, return_address)
      @request = request
      @return_address = return_address
    end

    def setup_container_run(track_dir, exercise_slug, job_slug)
      Pipeline::Runtime::AnalysisRun.new(track_dir, exercise_slug, job_slug)
    end

    def prepare_folder(iteration_folder)
      location = @request["s3_uri"]
      s3_sync(location, iteration_folder)
    end

  end
end

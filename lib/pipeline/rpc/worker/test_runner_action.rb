module Pipeline::Rpc::Worker

  class TestRunnerAction < AnalyzeAction

    def initialize(request, return_address)
      super(request, return_address)
    end

    def setup_container_run(track_dir, exercise_slug, job_slug)
      Pipeline::Runtime::TestRun.new(track_dir, exercise_slug, job_slug)
    end

  end
end

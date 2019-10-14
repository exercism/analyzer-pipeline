module Pipeline::Rpc::Worker

  class TestRunnerAction < AnalyzeAction

    def initialize(request, return_address)
      super(request, return_address)
    end

    def setup(track_slug, version, exercise_slug, solution_slug)
      track_dir = environment.track_dir(track_slug, version)
      Pipeline::Runtime::TestRun.new(track_dir, exercise_slug, solution_slug)
    end

  end
end

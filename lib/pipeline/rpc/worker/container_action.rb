module Pipeline::Rpc::Worker

  class ContainerAction < WorkerAction

    attr_reader :reader, :return_address, :s3

    def initialize(request, return_address)
      @request = request
      @return_address = return_address
    end

    def setup(track_slug, version, exercise_slug, solution_slug)
      track_dir = environment.track_dir(track_slug, version)
      Pipeline::Runtime::AnalysisRun.new(track_dir, exercise_slug, solution_slug)
    end

    def invoke
      @s3 = Aws::S3::Client.new(
        credentials: parse_credentials(request["context"]),
        region: "eu-west-1")

      language_slug = request["track_slug"]
      exercise_slug = request["exercise_slug"]
      job_slug = request["id"]
      container_version = request["container_version"]

      unless environment.released?(language_slug, container_version)
        return {
          error: "Container #{language_slug}:#{container_version} isn't available"
        }
      end

      analysis_run = setup(language_slug, container_version, exercise_slug, solution_slug)
      analysis_run.prepare_iteration do |iteration_folder|
        prepare_folder(iteration_folder)
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

    def prepare_folder(iteration_folder)
      raise "Please prepare input"
    end

  end
end

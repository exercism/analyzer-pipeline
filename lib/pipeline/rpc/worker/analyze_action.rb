module Pipeline::Rpc::Worker

  class AnalyzeAction < WorkerAction

    attr_reader :reader, :return_address

    def initialize(request, return_address)
      @request = request
      @return_address = return_address
    end

    def setup(track_slug, version, exercise_slug, solution_slug)
      track_dir = environment.track_dir(track_slug, version)
      Pipeline::Runtime::AnalysisRun.new(track_dir, exercise_slug, solution_slug)
    end

    def invoke
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

      analysis_run = setup(language_slug, container_version, exercise_slug, solution_slug)
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

  end
end

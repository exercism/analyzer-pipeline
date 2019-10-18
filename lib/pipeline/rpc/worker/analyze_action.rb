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
      location_uri = URI(location)
      bucket = location_uri.host
      path = location_uri.path[1..-1]
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

  end
end

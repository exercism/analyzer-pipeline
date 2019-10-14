module Pipeline::Rpc::Worker

  class AnalyzeAction < ContainerAction

    attr_reader :reader, :return_address

    def initialize(request, return_address)
      @request = request
      @return_address = return_address
    end

    def setup(track_slug, version, exercise_slug, solution_slug)
      track_dir = environment.track_dir(track_slug, version)
      Pipeline::Runtime::AnalysisRun.new(track_dir, exercise_slug, solution_slug)
    end

    def prepare_folder(iteration_folder)
      location = @request["iteration_folder"]
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

  end
end

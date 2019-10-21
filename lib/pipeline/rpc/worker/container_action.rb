module Pipeline::Rpc::Worker

  class ContainerAction < WorkerAction

    attr_reader :reader, :return_address, :s3, :track_slug, :container_version

    def initialize(request, return_address)
      @request = request
      @return_address = return_address
    end

    def invoke
      @s3 = Aws::S3::Client.new(
        credentials: parse_credentials(request["context"]),
        region: "eu-west-1")

      @track_slug = request["track_slug"]
      @exercise_slug = request["exercise_slug"]
      @job_slug = request["id"]
      @container_version = request["container_version"]

      check_container
      setup_run unless @error
      prepare_input unless @error
      run_container unless @error

      response = {return_address: return_address}

      if @error
        response[:msg_type] = :error_response
        response.merge(@error)
      else
        response[:msg_type] = :response
        response[:return_address] = return_address
        response.merge(@result)
      end
    end

    def check_container
      unless environment.released?(track_slug, container_version)
        @error = {
          status_code: 404,
          error: "Container #{track_slug}:#{container_version} isn't available"
        }
      end
    end

    def setup_run
      track_dir = environment.track_dir(track_slug, container_version)

      begin
        @analysis_run = setup_container_run(track_dir, @exercise_slug, @job_slug)
      rescue => e
        @error = {
          status_code: 500,
          error: "Failure setting up job",
          detail: e
        }
      end
    end

    def prepare_input
      begin
        @analysis_run.prepare_iteration do |iteration_folder|
          prepare_folder(iteration_folder)
        end
      rescue => e
        @error = {
          status_code: 500,
          error: "Failure preparing input",
          detail: e
        }
      end
    end

    def run_container
      begin
        @result = @analysis_run.analyze!
      rescue => e
        @error = {
          status_code: 500,
          error: "Error from container",
          detail: e
        }
      end
    end

    def setup_container_run(track_dir, exercise_slug, job_slug)
      raise "Please create run command"
    end

    def prepare_folder(iteration_folder)
      raise "Please prepare input"
    end

    def s3_sync(s3_uri, download_folder)
      location_uri = URI(s3_uri)
      bucket = location_uri.host
      path = location_uri.path[1..-1]
      s3_download_path = "#{path}/"
      params = {
        bucket: bucket,
        prefix: s3_download_path,
      }
      resp = s3.list_objects(params)
      resp.contents.each do |item|
        key = item[:key]
        local_key = key.delete_prefix(s3_download_path)
        target = "#{download_folder}/#{local_key}"
        target_folder = File.dirname(target)
        FileUtils.mkdir_p target_folder
        s3.get_object({
          bucket: bucket,
          key: key,
          response_target: target
        })
      end
    end

  end
end

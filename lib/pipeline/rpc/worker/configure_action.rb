module Pipeline::Rpc::Worker

  class ConfigureAction < WorkerAction

    def initialize(channel, request)
      @channel = channel
      @request = request
    end

    def invoke
      spec = request["specs"][@channel]
      credentials = parse_credentials(request)
      raise "No spec received" if spec.nil?
      spec.each do |language_slug, versions|
        puts "Preparing #{language_slug} #{versions}"
        versions.each do |version|
          if environment.released?(language_slug, version)
            puts "Already installed #{language_slug}:#{version}"
          else
            puts "Installed #{language_slug}"
            environment.release(@channel, language_slug, version, credentials)
          end
        end
      end
    end
  end

end

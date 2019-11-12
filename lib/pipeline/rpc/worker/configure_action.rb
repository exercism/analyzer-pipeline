module Pipeline::Rpc::Worker

  class ConfigureAction < WorkerAction

    def initialize(channel, request, topic_scopes)
      @channel = channel
      @request = request
      @topic_scopes = topic_scopes
    end

    def invoke      
      spec = request["specs"][@channel]
      puts "Configuing #{@channel} with #{spec}"
      credentials = parse_credentials(request)
      raise "No spec received" if spec.nil?
      spec.each do |language_slug, versions|
        if should_install?(language_slug)
          puts "Preparing #{language_slug} #{versions}"
          versions.each do |version|
            configure(language_slug, version, credentials)
          end
        else
          puts "Skipping configuration of #{language_slug}"
        end
      end
    end

    private

    def should_install?(language_slug)
       @topic_scopes.include?("*") || @topic_scopes.include?(language_slug)
    end

    def configure(language_slug, version, credentials)
      if environment.released?(language_slug, version)
        puts "Already installed #{language_slug}:#{version}"
      else
        puts "Installed #{language_slug}"
        environment.release(@channel, language_slug, version, credentials)
      end
    end

  end

end

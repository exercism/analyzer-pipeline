module Pipeline::Runtime
  class RuntimeEnvironment

    attr_reader :env_base

    def initialize(env_base)
      @env_base = env_base
    end

    def prepare
      FileUtils.mkdir_p env_base
    end

    def release_analyzer(track_slug)
      registry_endpoint = Pipeline.config["registry_endpoint"]

      track_dir = "#{env_base}/#{track_slug}"
      release_dir = "#{track_dir}/releases/#{Time.now.to_i}_release"
      current_dir = "#{track_dir}/current"
      FileUtils.mkdir_p release_dir

      logs = Pipeline::Util::LogCollector.new
      img = Pipeline::Util::ImgWrapper.new logs
      runc = Pipeline::Util::RuncWrapper.new logs

      configurator = Pipeline::Util::RuncConfigurator.new
      configurator.seed_from_env

      container_driver = Pipeline::Util::ContainerDriver.new(runc, img, configurator, release_dir)

      ecr = Aws::ECR::Client.new(region: 'eu-west-1')
      authorization_token = ecr.get_authorization_token.authorization_data[0].authorization_token
      plain = Base64.decode64(authorization_token)
      user,password = plain.split(":")
      img.login("AWS", password, registry_endpoint)

      remote_tag = "#{registry_endpoint}/#{track_slug}-analyzer-dev:latest"
      puts remote_tag

      img.pull(remote_tag)

      puts "pulled"

      container_driver.unpack_image(remote_tag)

      puts "unpacked"

      system("chmod -R a-w #{release_dir}")
      system("chmod -R go-rwx #{release_dir}")

      puts "current_dir #{current_dir} -> #{release_dir}"
      FileUtils.symlink(release_dir, current_dir, force: true)
    end

    def create_analyzer_workdir(track_slug)
      track_dir = "#{env_base}/#{track_slug}"
      current_dir = "#{track_dir}/current"
      iterations = "#{track_dir}/iterations"
      FileUtils.mkdir_p iterations
    end

    def new_analysis(track_slug, exercise_slug, solution_slug)
      track_dir = "#{env_base}/#{track_slug}"
      AnalysisRun.new(track_dir, exercise_slug, solution_slug)
    end

  end
end

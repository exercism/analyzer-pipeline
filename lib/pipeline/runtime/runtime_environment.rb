module Pipeline::Runtime
  class RuntimeEnvironment

    attr_reader :env_base

    def initialize(env_base)
      @env_base = env_base
    end

    def prepare
      FileUtils.mkdir_p env_base
    end

    def released?(track_slug, version)
      track_dir = "#{env_base}/#{track_slug}/#{version}"
      current_dir = "#{track_dir}/current"
      File.exist? current_dir
    end

    def available?(track_slug, version)
      puts "-- CHECK #{version} -----"
      puts container_repo.list_images
      puts "-------------------------"
      true
    end

    def container_repo
      @container_repo ||= Pipeline::ContainerRepo.new("#{track_slug}-analyzer-dev", credentials)
    end

    def release_analyzer(track_slug, version, credentials)
      track_dir = "#{env_base}/#{track_slug}/#{version}"
      release_dir = "#{track_dir}/releases/#{Time.now.to_i}_release"
      current_dir = "#{track_dir}/current"
      FileUtils.mkdir_p release_dir

      logs = Pipeline::Util::LogCollector.new
      img = Pipeline::Util::ImgWrapper.new logs
      runc = Pipeline::Util::RuncWrapper.new logs

      configurator = Pipeline::Util::RuncConfigurator.new
      configurator.seed_from_env

      container_driver = Pipeline::Util::ContainerDriver.new(runc, img, configurator, release_dir)

      user,password = container_repo.create_login_token
      img.reset_hub_login
      img.login("AWS", password, container_repo.repository_url)

      remote_tag = "#{container_repo.repository_url}:#{version}"
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

    def new_invocation(track_slug, version, exercise_slug, solution_slug)
      container_slug = "#{track_slug}/#{version}"
      puts "AnalysisRun: #{container_slug} #{exercise_slug} #{solution_slug}"
      track_dir = "#{env_base}/#{container_slug}"
      AnalysisRun.new(track_dir, exercise_slug, solution_slug)
    end

  end
end

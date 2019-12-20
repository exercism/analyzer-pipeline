module Pipeline::Runtime
  class RuntimeEnvironment

    def self.container_repo(channel, language_slug, credentials)
      suffix = "-dev" unless ENV["env"] == "production"
      container_slug = case channel
      when "static_analyzers"
        "#{language_slug}-analyzer#{suffix}"
      when "test_runners"
        "#{language_slug}-test-runner#{suffix}"
      when "representers"
        "#{language_slug}-representer#{suffix}"
      else
        raise "Unknown channel: #{channel}"
      end
      Pipeline::ContainerRepo.instance_for(container_slug, credentials)
    end

    def self.source_repo(channel, language_slug)
      suffix = case channel
      when "static_analyzers"
        "analyzer"
      when "test_runners"
        "test-runner"
      when "representers"
        "representer"
      else
        raise "Unknown channel: #{channel}"
      end
      Pipeline::AnalyzerRepo.for_track(language_slug, suffix)
    end

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

    def release(channel, language_slug, version, credentials)
      container_repo = RuntimeEnvironment.container_repo(channel, language_slug, credentials)
      release_container(language_slug, version, container_repo)
    end

    def list_deployed_containers(track_slug)
      track_dir = "#{env_base}/#{track_slug}"
      glob_pattern = "#{track_dir}/*/current"
      Dir.glob(glob_pattern).map do |match|
        match.gsub(track_dir, "").gsub(/current$/, "")
      end
    end

    def release_container(track_slug, version, container_repo)
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

    def track_dir(track_slug, version)
      container_slug = "#{track_slug}/#{version}"
      "#{env_base}/#{container_slug}"
    end

    def new_invocation(track_slug, version, exercise_slug, solution_slug)
      container_slug = "#{track_slug}/#{version}"
      puts "AnalysisRun: #{container_slug} #{exercise_slug} #{solution_slug}"
      track_dir = "#{env_base}/#{container_slug}"
      AnalysisRun.new(track_dir, exercise_slug, solution_slug)
    end

  end
end

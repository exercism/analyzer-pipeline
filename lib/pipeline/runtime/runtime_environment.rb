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

      img = Pipeline::Util::ImgWrapper.new
      runc = Pipeline::Util::RuncWrapper.new

      configurator = Pipeline::Util::RuncConfigurator.new
      configurator.seed_from_env

      container_driver = Pipeline::Util::ContainerDriver.new(runc, img, configurator, release_dir)

      # container_driver.prepare_workdir
      # container_driver.unpack_image("track_slug:master")
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

      FileUtils.symlink(release_dir, current_dir, force: true)
    end

    def create_analyzer_workdir(track_slug)
      track_dir = "#{env_base}/#{track_slug}"
      current_dir = "#{track_dir}/current"
      iterations = "#{track_dir}/iterations"
      FileUtils.mkdir_p iterations
    end

    def prepare_analysis(track_slug, solution_id)
      track_dir = "#{env_base}/#{track_slug}"
      runs_dir = "#{track_dir}/runs"
      current_dir = "#{track_dir}/current"
      solution_dir = "#{runs_dir}/iteration_#{Time.now.to_i}-#{solution_id}-#{SecureRandom.hex}"

      iteration_folder = "#{solution_dir}/iteration"
      tmp_folder = "#{solution_dir}/tmp"

      FileUtils.mkdir_p iteration_folder
      FileUtils.mkdir_p tmp_folder
      solution_dir
    end

    def run_analysis(track_slug, solution_dir, exercise_slug)
      track_dir = "#{env_base}/#{track_slug}"
      runs_dir = "#{track_dir}/runs"
      current_dir = "#{track_dir}/current"
      img = Pipeline::Util::ImgWrapper.new
      runc = Pipeline::Util::RuncWrapper.new
      configurator = Pipeline::Util::RuncConfigurator.new
      configurator.seed_from_env

      rootfs_source = "#{File.readlink(current_dir)}/rootfs"
      configurator.rootfs = rootfs_source

      container_driver = Pipeline::Util::ContainerDriver.new(runc, img, configurator, solution_dir)
      container_driver.run_analyzer_for("two-fer")
    end

    def analyze_solution(track_slug, solution_id, exercise_slug)
      iteration_folder = prepare_analysis
      yield iteration_folder
      run_analysis(iteration_folder, exercise_slug)
    end

  end
end

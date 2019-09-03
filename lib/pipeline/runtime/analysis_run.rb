module Pipeline::Runtime
  class AnalysisRun

    attr_reader :track_dir, :exercise_slug, :runs_dir, :solution_dir,
                :iteration_folder, :tmp_folder, :current_dir

    def initialize(track_dir, exercise_slug, solution_slug)
      @track_dir = track_dir
      @exercise_slug = exercise_slug
      @runs_dir = "#{track_dir}/runs"
      @current_dir = "#{track_dir}/current"
      @solution_dir = "#{runs_dir}/iteration_#{Time.now.to_i}-#{solution_slug}-#{SecureRandom.hex}"
      @iteration_folder = "#{solution_dir}/iteration"
      @tmp_folder = "#{solution_dir}/tmp"
    end

    def prepare_iteration
      FileUtils.mkdir_p iteration_folder
      FileUtils.mkdir_p tmp_folder

      configurator.setup_for_terminal_access
      File.write("#{solution_dir}/terminal_config.json", configurator.build.to_json)

      yield iteration_folder
    end

    def analyze!
      container_driver = Pipeline::Util::ContainerDriver.new(runc, img, configurator, solution_dir)
      container_driver.run_analyzer_for(exercise_slug)
    end

    def result
      File.read("#{iteration_folder}/analysis.json")
    end

    private

    def configurator
      @configurator ||= begin
        configurator = Pipeline::Util::RuncConfigurator.new
        configurator.seed_from_env
        configurator.rootfs = rootfs_source
        configurator
      end
    end

    def img
      @img ||= Pipeline::Util::ImgWrapper.new
    end

    def runc
      @runc ||= Pipeline::Util::RuncWrapper.new
    end

    def rootfs_source
      @rootfs_source ||= begin
        release_folder = File.readlink(current_dir)
        "#{release_folder}/rootfs"
      end
    end
  end
end

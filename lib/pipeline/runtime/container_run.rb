module Pipeline::Runtime
  class ContainerRun

    attr_reader :track_dir, :exercise_slug, :runs_dir, :solution_dir,
                :iteration_folder, :tmp_folder, :current_dir, :img,
                :runc

    def initialize(track_dir, exercise_slug, solution_slug)
      @track_dir = track_dir
      @exercise_slug = exercise_slug
      @runs_dir = "#{track_dir}/runs"
      @current_dir = "#{track_dir}/current"
      @solution_dir = "#{runs_dir}/iteration_#{Time.now.to_i}-#{solution_slug}-#{SecureRandom.hex}"
      @iteration_folder = "#{solution_dir}/iteration"
      @tmp_folder = "#{solution_dir}/tmp"
      @logs = Pipeline::Util::LogCollector.new
      @img  = Pipeline::Util::ImgWrapper.new(@logs)
      @runc = Pipeline::Util::RuncWrapper.new(@logs)
    end

    def prepare_iteration
      FileUtils.mkdir_p iteration_folder
      FileUtils.mkdir_p tmp_folder

      configurator.setup_for_terminal_access
      File.write("#{solution_dir}/terminal_config.json", configurator.build.to_json)

      yield iteration_folder
    end

    def analyze!
      puts "Starting container invocation"
      begin
        container_driver = Pipeline::Util::ContainerDriver.new(runc, img, configurator, solution_dir)
        @result = container_driver.invoke(working_directory, args)
      rescue => e
      end
      puts "Completed invocation"
      data = {
        exercise_slug: exercise_slug,
        solution_dir: solution_dir,
        rootfs_source: rootfs_source,
        invocation: @result.report,
        logs: @logs.inspect,
        exit_status: exit_status
      }
      begin
        data[:result] = result if exit_status == 0
      rescue => e
        puts "Error reading result"
        data[:error] = e
      end
      data
    end

    def working_directory
      raise "Working directory was not defined"
    end

    def args
      raise "args were not defined"
    end

    def result
      raise "No result handler defined"
    end

    def success?
      @result.success?
    end

    def exit_status
      @result.exit_status
    end

    def stdout
      @result.stdout
    end

    def stderr
      @result.stderr
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

    def rootfs_source
      @rootfs_source ||= begin
        release_folder = File.readlink(current_dir)
        "#{release_folder}/rootfs"
      end
    end
  end
end

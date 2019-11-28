module Pipeline::Util
  class ContainerDriver
    attr_accessor :runc, :img, :configurator, :workdir

    def initialize(runc, img, configurator, workdir)
      @runc = runc
      @img = img
      @configurator = configurator
      @workdir = workdir
    end

    def prepare_workdir
      FileUtils.mkdir_p workdir
      FileUtils.mkdir_p "#{workdir}/iteration"
      FileUtils.mkdir_p "#{workdir}/tmp"
    end

    def unpack_image(build_tag)
      puts "unpack #{build_tag}"
      Dir.chdir(workdir) do
        img.unpack(build_tag)
      end
      configurator.setup_for_terminal_access
      File.write("#{workdir}/terminal_config.json", configurator.build.to_json)
    end

    def run_script(script_contents)
      File.write("#{workdir}/iteration/test_script.sh", script_contents)

      configurator.setup_script("/mnt/exercism-iteration/test_script.sh")
      File.write("#{workdir}/test_config.json", configurator.build.to_json)

      FileUtils.symlink("#{workdir}/test_config.json", "#{workdir}/config.json", force: true)
      run_analyzer
    end

    def run_analyzer
      notifier = INotify::Notifier.new
      notifier.watch("#{workdir}/iteration", :moved_to, :create) do |event|
        puts "!!!!!!!!!!! #{event.name} is now in iteration!"
        puts event
        notifier.watch("{workdir}/iteration/#{event.name}", :modify) do |event|
          puts event
        end
      end
      notifier.watch("#{workdir}/tmp", :moved_to, :create) do |event|
        puts "!!!!!!!!!!! #{event.name} is now in tmp!"
      end
      Thread.new do
        notifier.run
      end
      runc.run(workdir)
    ensure
      puts "ALL DONE"
      notifier.stop
    end

    def run_analyzer_for(exercise_slug)
      configurator.invoke_analyzer_for(exercise_slug)
      File.write("#{workdir}/analyzer_config.json", configurator.build.to_json)
      FileUtils.symlink("#{workdir}/analyzer_config.json", "#{workdir}/config.json", force: true)
      run_analyzer
    end

    def invoke(container_work_dir, args)
      configurator.setup_invocation_args(container_work_dir, args)
      File.write("#{workdir}/invocation_config.json", configurator.build.to_json)
      FileUtils.symlink("#{workdir}/invocation_config.json", "#{workdir}/config.json", force: true)
      run_analyzer
    end

  end

end

require "docopt"

module Pipeline::Cmd

  class RouterDaemon

    SPEC = <<-DOCOPT
    Exercism router.

    Usage:
      #{__FILE__} <configuration_file> [--seed=<seed_configuration] [--force-worker-restart]
      #{__FILE__} -h | --help
      #{__FILE__} --version

    DOCOPT

    include Mandate

    initialize_with :argv

    def call
      puts "*** Exercism Router ***"
      router.force_worker_restart! if restart_workers?
      router.run
    end

    def options
      @options ||= begin
        Docopt::docopt(SPEC, argv: argv)
      rescue Docopt::Exit => e
        puts e.message
        exit 1
      end
    end

    def restart_workers?
      options["--force-worker-restart"] == true
    end

    def router
      @router ||= begin
        config_file = options["<configuration_file>"]
        unless File.file?(config_file)
          seed = options["--seed"]
          puts "Seeding config from #{seed}"
          FileUtils.cp(seed, config_file)
        end
        config = Pipeline::Config.new(config_file)
        config.seed_aws!

        context = ZMQ::Context.new

        Pipeline::Rpc::Router.new(context, config)
      end
    end

  end
end

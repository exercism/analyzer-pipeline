require "docopt"

module Pipeline::Cmd

  class RouterDaemon

    SPEC = <<-DOCOPT
    Exercism router.

    Usage:
      #{__FILE__} <configuration_file> [--force-worker-restart]
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
        context = ZMQ::Context.new
        Pipeline.load_config(config_file)
        Pipeline::Rpc::Router.new(context)
      end
    end

  end
end

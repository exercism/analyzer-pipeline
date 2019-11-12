require "docopt"

module Pipeline::Cmd

  class WorkerDaemon

    SPEC = <<-DOCOPT
    Exercism worker.

    Usage:
      #{__FILE__} (listen|configure) <identity> <channel_address> <work_folder> [--dryrun]
      #{__FILE__} -h | --help
      #{__FILE__} --version

    DOCOPT

    include Mandate

    initialize_with :argv

    def call
      puts "*** Exercism Worker ***"

      begin
        daemon.bootstrap
        exit 0 if dryrun?

        daemon.configure
        exit 0 if configure?

        daemon.listen
      rescue Pipeline::Rpc::Worker::DaemonRestartException
        puts "Restarting Daemon"
        retry
      end
    end

    def options
      @options ||= begin
        Docopt::docopt(SPEC, argv: argv)
      rescue Docopt::Exit => e
        puts e.message
        exit 1
      end
    end

    def dryrun?
      options["--dryrun"] == true
    end

    def configure?
      options["configure"] == true
    end

    def daemon
      @daemon ||= begin
        worker_identity = options["<identity>"]
        channel_address = options["<channel_address>"]
        env_base = options["<work_folder>"]
        Pipeline::Rpc::Worker::Daemon.new(worker_identity, channel_address, env_base)
      end
    end

  end
end

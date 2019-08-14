module Pipeline::Validation
  class CheckInvokable
    include Mandate

    initialize_with :container_driver

    def call
      container_driver.run_script <<-EOS
        echo "OK" >/mnt/exercism-iteration/result.txt
      EOS

      text = File.read("#{workdir}/iteration/result.txt")

      raise "Santity check failed" if (text.strip != "OK")
    end

    def workdir
      container_driver.workdir
    end
  end
end

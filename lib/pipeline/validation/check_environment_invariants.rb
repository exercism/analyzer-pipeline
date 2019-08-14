module Pipeline::Validation
  class CheckEnvironmentInvariants
    include Mandate

    initialize_with :container_driver

    def call
      run_script <<-EOS
      if ping -q -c 1 -W 1 8.8.8.8  >/mnt/exercism-iteration/ping_check.txt; then
        echo "IPv4 is up" >/mnt/exercism-iteration/ip_connectivity.txt
      else
        echo "IPv4 is down" >/mnt/exercism-iteration/ip_connectivity.txt
      fi
      EOS

      ip_connectivity = File.read("#{workdir}/iteration/ip_connectivity.txt")
      raise "IP down check failed" if (ip_connectivity.strip != "IPv4 is down")

      run_script <<-EOS
        nc -w 3 -v 8.8.8.8 53 2>/mnt/exercism-iteration/net_check.txt
      EOS

      net_check = File.read("#{workdir}/iteration/net_check.txt")
      raise "NET check failed" if (net_check.strip != "8.8.8.8 (8.8.8.8:53) open")

      run_script <<-EOS
        touch /mnt/exercism-iteration/fs_check.txt
        touch /mnt/foobar && echo "/mnt writable!" >>/mnt/exercism-iteration/fs_check.txt
        touch /opt/foobar && echo "/opt writable!" >>/mnt/exercism-iteration/fs_check.txt
        touch /opt/analyzer/foobar && echo "/opt/analyzer/ writable!" >>/mnt/exercism-iteration/fs_check.txt
        exit 0
      EOS

      fs_check = File.read("#{workdir}/iteration/fs_check.txt")

      raise "Not readonly: #{fs_check}" unless fs_check.strip.empty?

      run_script <<-EOS
        echo "/tmp/ writable!" >/tmp/foobar
      EOS
      run_script <<-EOS
        cat /tmp/foobar >/mnt/exercism-iteration/tmp_check.txt
      EOS

      tmp_check = File.read("#{workdir}/iteration/tmp_check.txt").strip
      tmp_file = File.read("#{workdir}/tmp/foobar").strip

      raise "/tmp not persisting across invocations" if ("/tmp/ writable!" != tmp_check || "/tmp/ writable!" != tmp_file)
    end

    def run_script(script_contents)
      container_driver.run_script(script_contents)
    end

    def workdir
      container_driver.workdir
    end
  end
end

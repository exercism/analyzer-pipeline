class Pipeline::ValidateBuild
  include Mandate

  attr_accessor :img, :runc

  initialize_with :build_tag

  def call
    @img = File.expand_path "./opt/img"
    @runc = File.expand_path "./opt/runc"
    puts "[x] #{build_tag}"
    FileUtils.mkdir_p workdir
    unpack
    write_runc_config
    FileUtils.mkdir_p "#{workdir}/iteration"
    FileUtils.mkdir_p "#{workdir}/tmp"
    check_environment_is_invokable
    check_environment_invariants
    check_sample_solutions
  end

  def unpack
    Dir.chdir(workdir) do
      exec_cmd "#{img} unpack -state /tmp/state-img #{build_tag}"
    end
  end

  def check_environment_is_invokable
    run_script <<-EOS
      echo "OK" >/mnt/exercism-iteration/result.txt
    EOS

    text = File.read("#{workdir}/iteration/result.txt")

    raise "Santity check failed" if (text.strip != "OK")
  end

  def check_environment_invariants
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

  def check_sample_solutions
    analysis = validate_status("ruby", "two-fer", "example1")
    analysis = validate_status("ruby", "two-fer", "example2")
  end

  def validate_status(track, exercise, slug)
    fixture = "fixtures/#{track}/#{exercise}/#{slug}/"
    FileUtils.rm_rf("#{workdir}/iteration/")
    FileUtils.cp_r "#{fixture}/iteration", "#{workdir}/iteration"

    FileUtils.symlink("#{workdir}/analyzer_config.json", "#{workdir}/config.json", force: true)

    Dir.chdir(workdir) do
      exec_cmd "#{runc} --root root-state run 123"
    end

    analysis = JSON.parse(File.read("#{workdir}/iteration/analysis.json"))
    expected = JSON.parse(File.read("#{fixture}/expected_analysis.json"))

    # puts analysis
    # puts expected

    raise "Incorrect expected_status" if expected["status"].nil?
    raise "Incorrect status when validating #{fixture}" if expected["status"] != analysis["status"]
    raise "Incorrect comments when validating #{fixture}" if expected["comments"].sort != analysis["comments"].sort
  end

  memoize
  def workdir
    "/tmp/analyzer-scratch/#{SecureRandom.uuid}"
  end

  def rootfs
    "#{workdir}/rootfs"
  end

  def run_script(script_contents)
    File.write("#{workdir}/iteration/test_script.sh", script_contents)

    FileUtils.symlink("#{workdir}/test_config.json", "#{workdir}/config.json", force: true)
    Dir.chdir(workdir) do
      exec_cmd "#{runc} --root root-state run 123"
    end
  end

  def exec_cmd(cmd)
    puts "> #{cmd}"
    puts "------------------------------------------------------------"
    success = system({}, cmd)
    raise "Failed #{cmd}" unless success
  end

  def write_runc_config
    uid_id=`id -u`.chomp
    gid_id=`id -g`.chomp
    config = <<-EOS
    {
      "ociVersion": "1.0.1-dev",
      "process": {
        "terminal": false,
        "user": {
          "uid": 0,
          "gid": 0
        },
        "args": [
           "bin/analyze.sh", "two-fer", "/mnt/exercism-iteration/"
        ],
        "env": [
          "GEM_HOME=/usr/local/bundle",
          "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
          "TERM=xterm"
        ],
        "cwd": "/opt/analyzer",
        "rlimits": [
          {
            "type": "RLIMIT_NOFILE",
            "hard": 1024,
            "soft": 1024
          }
        ],
        "noNewPrivileges": true
      },
      "root": {
        "path": "./rootfs",
        "readonly": true
      },
      "hostname": "exercism-runner",
      "mounts": [
        {
          "destination": "/mnt/exercism-iteration",
          "source": "./iteration",
          "options": [ "rbind", "rw" ]
        },
        {
          "destination": "/tmp",
          "source": "./tmp",
          "options": [ "rbind", "rw" ]
        },
        {
          "destination": "/proc",
          "type": "proc",
          "source": "proc"
        },
        {
          "destination": "/dev",
          "type": "tmpfs",
          "source": "tmpfs",
          "options": [
            "nosuid",
            "strictatime",
            "mode=755",
            "size=65536k"
          ]
        },
        {
          "destination": "/dev/pts",
          "type": "devpts",
          "source": "devpts",
          "options": [
            "nosuid",
            "noexec",
            "newinstance",
            "ptmxmode=0666",
            "mode=0620"
          ]
        },
        {
          "destination": "/dev/shm",
          "type": "tmpfs",
          "source": "shm",
          "options": [
            "nosuid",
            "noexec",
            "nodev",
            "mode=1777",
            "size=65536k"
          ]
        },
        {
          "destination": "/dev/mqueue",
          "type": "mqueue",
          "source": "mqueue",
          "options": [
            "nosuid",
            "noexec",
            "nodev"
          ]
        },
        {
          "destination": "/sys",
          "type": "none",
          "source": "/sys",
          "options": [
            "rbind",
            "nosuid",
            "noexec",
            "nodev",
            "ro"
          ]
        }
      ],
      "linux": {
        "uidMappings": [
          {
            "containerID": 0,
            "hostID": #{uid_id},
            "size": 1
          }
        ],
        "gidMappings": [
          {
            "containerID": 0,
            "hostID": #{gid_id},
            "size": 1
          }
        ],
        "namespaces": [
          {
            "type": "pid"
          },
          {
            "type": "ipc"
          },
          {
            "type": "uts"
          },
          {
            "type": "mount"
          },
          {
            "type": "user"
          }
        ],
        "maskedPaths": [
          "/proc/kcore",
          "/proc/latency_stats",
          "/proc/timer_list",
          "/proc/timer_stats",
          "/proc/sched_debug",
          "/sys/firmware",
          "/proc/scsi"
        ],
        "readonlyPaths": [
          "/proc/asound",
          "/proc/bus",
          "/proc/fs",
          "/proc/irq",
          "/proc/sys",
          "/proc/sysrq-trigger"
        ]
      }
    }
    EOS
    cc = JSON.parse(config)
    File.write("#{workdir}/analyzer_config.json", config)
    cc["process"]["args"] = ["/bin/bash"]
    cc["process"]["terminal"] = true
    File.write("#{workdir}/terminal_config.json", cc.to_json)

    cc["process"]["args"] = ["/bin/bash", "/mnt/exercism-iteration/test_script.sh"]
    cc["process"]["terminal"] = false
    File.write("#{workdir}/test_config.json", cc.to_json)
  end

end

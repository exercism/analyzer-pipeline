module Pipeline::Util
  class RuncConfigurator
    attr_accessor :uid_id, :gid_id, :invocation_args, :interactive

    def seed_from_env
      @uid_id = `id -u`.chomp
      @gid_id = `id -g`.chomp
      @invocation_args = []
      @interactive = false
    end

    def invoke_analyser_for(track_slug)
      @interactive = false
      @invocation_args = ["bin/analyze.sh", track_slug, "/mnt/exercism-iteration/"]
    end

    def setup_for_terminal_access
      @interactive = true
      @invocation_args = ["/bin/bash"]
    end

    def setup_bash_script(script_path)
      @interactive = false
      @invocation_args = ["/bin/bash", script_path]
    end

    def build
      config = <<-EOS
      {
        "ociVersion": "1.0.1-dev",
        "process": {
          "user": {
            "uid": 0,
            "gid": 0
          },
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
      parsed = JSON.parse(config)
      parsed["process"]["terminal"] = interactive
      parsed["process"]["args"] = invocation_args
      parsed
    end

  end
end

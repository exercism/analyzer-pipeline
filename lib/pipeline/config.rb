class Pipeline::Config

  attr_reader :config_file

  def initialize(config_file)
    @config_file = config_file
  end

  def seed_aws!
    Aws.config.update({
       credentials: Aws::Credentials.new(config["aws_access_key_id"], config["aws_secret_access_key"])
    })
    puts "HERE"

  end

  def config
    @config ||= begin
       loaded_config = YAML.load(File.read(config_file))
       loaded_config["workers"] ||= {}
       loaded_config["workers"].each do |worker_class, worker_config|
         raise "no default port for #{worker_class}" unless worker_config["shared_queue"]
         worker_config.each do |entry, value|
           next if entry == "shared_queue"
           raise "no port for #{worker_class}:#{entry}" unless value["queue"]
           value["worker_versions"] = [] if value["worker_versions"].nil?
         end
       end
       loaded_config
     end
  end

  def each_worker(&block)
    config["workers"].each(&block)
  end

  def update_container_versions!(worker_class, track_slug, versions)
    current = config.to_h
    workers = current["workers"]
    raise "No worker config" if workers.nil?
    class_config = workers[worker_class]
    raise "No worker class config for #{worker_class}" if class_config.nil?
    track_config = class_config[track_slug]
    raise "No track config for #{worker_class}:#{track_slug}" if track_config.nil?
    worker_versions = track_config["worker_versions"]
    track_config["old_worker_versions"] = worker_versions
    track_config["worker_versions"] = versions
    save_config(current)
  end

  def add_container_version!(worker_class, track_slug, new_version)
    current = config.to_h
    workers = current["workers"]
    raise "No worker config" if workers.nil?
    class_config = workers[worker_class]
    raise "No worker class config for #{worker_class}" if class_config.nil?
    track_config = class_config[track_slug]
    raise "No track config for #{worker_class}:#{track_slug}" if track_config.nil?
    worker_versions = track_config["worker_versions"]
    versions = worker_versions.clone
    versions << new_version
    versions.uniq!
    track_config["old_worker_versions"] = worker_versions
    track_config["worker_versions"] = versions
    save_config(current)
  end

  def save_config(updated_config)
    puts updated_config
    File.write(config_file, updated_config.to_yaml)
    @config = YAML.load(File.read(config_file))
  end


end

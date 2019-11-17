module Pipeline::Build
  class PublishImage
    include Mandate

    initialize_with :img, :container_repo, :local_tag, :build_tag

    attr_reader :repository_url

    def call
      puts "PUBLISHING #{image_tag}"
      puts "Login to repo"
      login_to_repository
      tag_build
      push_build
      logout
    end

    def login_to_repository
      @repository_url = container_repo.repository_url
      user, password = container_repo.create_login_token
      img.login("AWS", password, repository_url)
    end

    def logout
      img.logout(repository_url)
    end

    def tag_build
      img.tag(image_tag, remote_tag)
      img.tag(image_tag, remote_tag_timestamped)
      img.tag(image_tag, remote_human_tag) unless build_tag.nil?
      img.tag(image_tag, remote_latest_tag)
    end

    def push_build
      img.push(remote_tag)
      img.push(remote_tag_timestamped)
      img.push(remote_human_tag) unless build_tag.nil?
      img.push(remote_latest_tag)
    end

    def image_tag
      "#{container_repo.image_name}:#{local_tag}"
    end

    def remote_tag
      "#{repository_url}:#{local_tag}"
    end

    def remote_human_tag
      "#{repository_url}:#{build_tag}"
    end

    def remote_latest_tag
      "#{repository_url}:latest"
    end

    def remote_tag_timestamped
      tag = local_tag.gsub(/git-/, "build-")
      "#{repository_url}:#{tag}-#{build_timestamp}"
    end

    memoize
    def build_timestamp
      Time.now.to_i
    end

  end
end

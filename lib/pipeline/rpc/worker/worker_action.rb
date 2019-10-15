module Pipeline::Rpc::Worker

  class WorkerAction

    attr_accessor :environment, :request

    def invoke
    end

    def parse_credentials(request)
      raw_credentials = request["credentials"]
      key = raw_credentials["access_key_id"]
      secret = raw_credentials["secret_access_key"]
      session = raw_credentials["session_token"]
      Aws::Credentials.new(key, secret, session)
    end

  end

end

module Pipeline::Rpc

  class WorkerPresence

    def initialize
      @last_seen = Hash.new {|h,k| h[k] = {}}
    end

    def mark_seen!(identity, connected_queues, worker_info)
      connected_queues.each do |queue_address|
        @last_seen[queue_address][identity] = {
          identity: identity,
          last_seen: Time.now.to_i,
          info: worker_info
        }
      end
      @last_seen.each do |queue_address,v|
        v.reject! do |identity,entry|
          timestamp = entry[:last_seen]
          timestamp < Time.now.to_i - 10
        end
      end
    end

    def list_for(queue_addresses)
      workers = []
      queue_addresses.each do |queue_address|
        @last_seen[queue_address].each do |id, worker|
          workers << worker
        end
      end
      workers.uniq { |w| w[:identity] }
    end

    def count_for(queue_addresses)
      list_for(queue_addresses).size
    end

    def workers_info
      @last_seen
    end

  end

end

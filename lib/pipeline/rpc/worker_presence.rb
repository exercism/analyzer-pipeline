module Pipeline::Rpc

  class WorkerPresence

    def initialize
      @last_seen = Hash.new {|h,k| h[k] = {}}
    end

    def mark_seen!(identity, connected_queues)
      connected_queues.each do |queue_address|
        @last_seen[queue_address][identity] = Time.now.to_i
      end
      @last_seen.each do |queue_address,v|
        v.reject! do |identity,timestamp|
          timestamp < Time.now.to_i - 10
        end
      end
    end

    def list_for(queue_addresses)
      workers = []
      queue_addresses.each do |queue_address|
        workers += @last_seen[queue_address].keys
      end
      workers.uniq
    end

    def count_for(queue_addresses)
      list_for(queue_addresses).size
    end

  end

end

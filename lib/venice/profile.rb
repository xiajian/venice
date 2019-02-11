module Venice
  class Profile
    # 性能监控对象
    def self.prof(&block)
      start_time = Time.now

      if block_given?
        result = block.call
      end

      cost_time = Time.now - start_time

      Venice.logger.info "Cost Time is: #{cost_time} s"

      result
    end
  end
end

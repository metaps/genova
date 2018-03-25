module Genova
  module Sidekiq
    class Job
      def initialize(id, options = {})
        @id = id
        @options = options

        singleton_class.class_eval { attr_accessor 'id' }
        send('id=', id)

        options.each do |name, value|
          singleton_class.class_eval { attr_accessor name }
          send("#{name}=", value)
        end
      end

      def update(options)
        options.each do |name, value|
          @options[name] = value
        end

        $redis.mapped_hmset(@id, @options)
      end
    end
  end
end

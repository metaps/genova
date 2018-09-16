module Genova
  module Sidekiq
    class Job
      attr_reader :options

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

      def [](key)
        @options[key]
      end

      def update(options)
        options.each do |name, value|
          @options[name] = value
        end

        Redis.current.mapped_hmset(@id, @options)
      end
    end
  end
end

module Genova
  module Sidekiq
    class Job
      def initialize(id, values = {})
        @id = id
        @values = values

        singleton_class.class_eval { attr_accessor 'id' }
        send('id=', id)

        values.each do |name, value|
          singleton_class.class_eval { attr_accessor name }
          send("#{name}=", value)
        end
      end

      def update(values)
        values.each do |name, value|
          @values[name] = value
        end

        $redis.mapped_hmset(@id, @values)
      end
    end
  end
end

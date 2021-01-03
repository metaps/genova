module Genova
  module Slack
    module Command
      class Version
        VERSION = <<~DOC.freeze
          ```
          #{Genova::VERSION::LONG_STRING}
          ```
        DOC

        def self.call(client, _statements, _user)
          client.post_simple_message(text: VERSION)
        end
      end
    end
  end
end

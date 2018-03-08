module CI
  module Slack
    class Greeting
      def self.hello
        bot = CI::Slack::Bot.new
        bot.post_simple_message('Hello world')
      end
    end
  end
end

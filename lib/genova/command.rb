require 'open3'

module Genova
  module Command
    class << self
      def exec(command)
        output, stderr = Open3.capture3(command)
        raise StandardError, stderr if stderr.present?

        output
      end
    end

    class StandardError < Error; end
  end
end

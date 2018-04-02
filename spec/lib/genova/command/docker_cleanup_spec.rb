require 'rails_helper'

module Genova
  module Command
    describe DockerCleanup do
      let(:executor_mock) { double(Genova::Command::Executor) }

      describe 'exec' do
        it 'should be return execute result' do
          allow(executor_mock).to receive(:command).and_return('')

          arg = 'docker images --format "{{.ID}}|{{.Repository}}|{{.CreatedAt}}"'

          repository = "#{ENV.fetch('AWS_ACCOUNT_ID')}.dkr.ecr.#{ENV.fetch('AWS_REGION')}.amazonaws.com"
          created_at = '2018-01-01 00:00:00 +0900 UTC'
          expect = "id|#{repository}|#{created_at}"

          allow(executor_mock).to receive(:command).with(arg).and_return(expect)
          allow(Genova::Command::Executor).to receive(:new).and_return(executor_mock)

          Genova::Command::DockerCleanup.exec
        end
      end
    end
  end
end

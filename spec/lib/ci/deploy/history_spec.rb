require 'rails_helper'

module CI
  module Deploy
    describe History do
      let(:history) { CI::Deploy::History.new('user_id') }

      before do
        $redis.flushall
        allow(Settings.slack.command).to receive(:max_history).and_return(2)
      end

      describe 'add' do
        context 'when adding key for first' do
          it 'should be return one history' do
            history.add('metaps', 'ecs-ci', 'master', 'development')

            expect(history.list.size).to eq(1)
          end
        end

        context 'when adding key for second (new key)' do
          it 'should be return two history' do
            history.add('metaps', 'ecs-ci', 'master', 'development')
            history.add('metaps', 'ecs-ci', 'master', 'production')

            expect(history.list.size).to eq(2)
          end
        end

        context 'when adding key for second (exist key)' do
          it 'should be return one history' do
            history.add('metaps', 'ecs-ci', 'master', 'development')
            history.add('metaps', 'ecs-ci', 'master', 'development')

            expect(history.list.size).to eq(1)
          end
        end

        context 'when history holdings is exceeded' do
          it 'should be delete old history' do
            history.add('metaps', 'ecs-ci', 'feature/3', 'development')
            history.add('metaps', 'ecs-ci', 'feature/2', 'development')
            history.add('metaps', 'ecs-ci', 'feature/1', 'development')

            expect(history.list.size).to eq(2)
          end
        end
      end

      describe 'last' do
        context 'when adding key for first' do
          it 'should be return last value' do
            history.add('metaps', 'ecs-ci', 'master', 'development')
            last = history.last

            expect(last[:account]).to eq('metaps')
            expect(last[:repository]).to eq('ecs-ci')
            expect(last[:branch]).to eq('master')
            expect(last[:environment]).to eq('development')
          end
        end

        context 'when adding key for second (first key)' do
          it 'should be return last value' do
            history.add('metaps', 'ecs-ci', 'master', 'development')
            history.add('metaps', 'ecs-ci', 'master', 'production')
            last = history.last

            expect(last[:account]).to eq('metaps')
            expect(last[:repository]).to eq('ecs-ci')
            expect(last[:branch]).to eq('master')
            expect(last[:environment]).to eq('production')
          end
        end
      end
    end
  end
end

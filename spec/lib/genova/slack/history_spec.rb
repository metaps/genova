require 'rails_helper'

module Genova
  module Slack
    describe History do
      let(:history) { Genova::Slack::History.new('user_id') }

      before do
        Redis.current.flushall
        allow(Settings.slack.command).to receive(:max_history).and_return(2)
      end

      describe 'add' do
        context 'when adding key for first' do
          it 'should be return one history' do
            history.add(
              account: 'metaps',
              repository: 'genova',
              branch: 'master',
              cluster: 'default',
              service: 'development'
            )

            expect(history.list.size).to eq(1)
          end
        end

        context 'when adding key for second (new key)' do
          it 'should be return two history' do
            history.add(
              account: 'metaps',
              repository: 'genova',
              branch: 'master',
              cluster: 'default',
              service: 'development'
            )
            history.add(
              account: 'metaps',
              repository: 'genova',
              branch: 'master',
              cluster: 'default',
              service: 'production'
            )

            expect(history.list.size).to eq(2)
          end
        end

        context 'when adding key for second (exist key)' do
          it 'should be return one history' do
            history.add(
              account: 'metaps',
              repository: 'genova',
              branch: 'master',
              cluster: 'default',
              service: 'production'
            )
            history.add(
              account: 'metaps',
              repository: 'genova',
              branch: 'master',
              cluster: 'default',
              service: 'production'
            )

            expect(history.list.size).to eq(1)
          end
        end

        context 'when history holdings is exceeded' do
          it 'should be delete old history' do
            history.add(
              account: 'metaps',
              repository: 'genova',
              branch: 'feature/3',
              cluster: 'default',
              service: 'development'
            )
            history.add(
              account: 'metaps',
              repository: 'genova',
              branch: 'feature/2',
              cluster: 'default',
              service: 'development'
            )
            history.add(
              account: 'metaps',
              repository: 'genova',
              branch: 'feature/1',
              cluster: 'default',
              service: 'development'
            )

            expect(history.list.size).to eq(2)
          end
        end
      end

      describe 'last' do
        context 'when adding key for first' do
          it 'should be return last value' do
            history.add(
              account: 'metaps',
              repository: 'genova',
              branch: 'master',
              cluster: 'default',
              service: 'development'
            )
            last = history.last

            expect(last[:account]).to eq('metaps')
            expect(last[:repository]).to eq('genova')
            expect(last[:branch]).to eq('master')
            expect(last[:cluster]).to eq('default')
            expect(last[:service]).to eq('development')
          end
        end

        context 'when adding key for second (first key)' do
          it 'should be return last value' do
            history.add(
              account: 'metaps',
              repository: 'genova',
              branch: 'master',
              cluster: 'default',
              service: 'development'
            )
            history.add(
              account: 'metaps',
              repository: 'genova',
              branch: 'master',
              cluster: 'default',
              service: 'production'
            )
            last = history.last

            expect(last[:account]).to eq('metaps')
            expect(last[:repository]).to eq('genova')
            expect(last[:branch]).to eq('master')
            expect(last[:service]).to eq('production')
          end
        end
      end
    end
  end
end

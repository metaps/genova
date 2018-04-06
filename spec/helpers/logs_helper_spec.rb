require 'rails_helper'

describe LogsHelper do
  describe 'task_revision' do
    include LogsHelper

    context 'when task definition arn is nil' do
      it 'should be return nil' do
        expect(task_revision(nil)).to eq(nil)
      end
    end

    context 'when task definition arn is string' do
      it 'should be return revision' do
        expect(task_revision('arn:aws:ecs:ap-northeast-1:xxx:task-definition/yotsuba-staging:10')).to eq('10')
      end
    end
  end
end

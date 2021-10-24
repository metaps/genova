require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe 'readable_type' do
    it 'should be return correct service name' do
      expect(helper.readable_type('service')).to eq('Service')
      expect(helper.readable_type('scheduled_task')).to eq('Scheduled task')
    end
  end
end

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe 'type_tag' do
    it 'should be return correct service name' do
      expect(helper.type_tag('service')).to eq('<span class="tag is-info">Service</span>')
      expect(helper.type_tag('scheduled_task')).to eq('<span class="tag is-warning">Scheduled task</span>')
      expect(helper.type_tag('run_task')).to eq('<span class="tag is-success">Run task</span>')
    end
  end
end

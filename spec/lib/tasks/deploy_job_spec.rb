require 'rails_helper'
require 'thor'
require_relative '../../../lib/tasks/deploy'

RSpec.describe GenovaCli::Deploy do
  before do
    allow_any_instance_of(described_class).to receive(:linux_user_name).and_return('alice')
    allow(Genova::Deploy::Runner).to receive(:new).and_return(double(run: nil))
    allow(DeployJob).to receive(:generate_id).and_return(SecureRandom.uuid)
  end

  {
    'service' => ['--service', 'service'],
    'run-task' => ['--run_task', 'task'],
    'scheduled-task' => ['--scheduled_task_rule', 'rule', '--scheduled_task_target', 'target']
  }.each do |command, arguments|
    it "records the login user for #{command}" do
      described_class.start([command, '--repository', 'repository', *arguments])

      job = DeployJob.find(DeployJob.generate_id)
      expect(job.linux_user_name).to eq('alice')
      expect(job.slack_user_name).to be_nil
    end
  end

  it 'passes the login user to the workflow runner' do
    expect(Genova::Deploy::Workflow::Runner).to receive(:call).with(
      'workflow', instance_of(Genova::Deploy::Step::StdoutHook),
      hash_including(linux_user_name: 'alice', mode: DeployJob.mode.find_value(:manual))
    )

    described_class.start(['workflow', '--name', 'workflow'])
  end
end

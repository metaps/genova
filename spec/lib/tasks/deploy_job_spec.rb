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
      expect(job.build_only?).to be(false)
    end

    it "records build-only execution for #{command}" do
      described_class.start([command, '--repository', 'repository', *arguments, '--build-only'])

      expect(DeployJob.find(DeployJob.generate_id).build_only?).to be(true)
    end
  end

  it 'passes the login user to the workflow runner' do
    expect(Genova::Deploy::Workflow::Runner).to receive(:call).with(
      'workflow', instance_of(Genova::Deploy::Step::StdoutHook),
      hash_including(linux_user_name: 'alice', mode: DeployJob.mode.find_value(:manual))
    )

    described_class.start(['workflow', '--name', 'workflow'])
  end

  it 'passes build-only and no-cache options to the workflow runner' do
    expect(Genova::Deploy::Workflow::Runner).to receive(:call).with(
      'workflow', instance_of(Genova::Deploy::Step::StdoutHook),
      hash_including(build_only: true, no_cache: true)
    )

    described_class.start(['workflow', '--name', 'workflow', '--build-only', '--no-cache'])
  end

  %w[--override-container --override-command].each do |option|
    it "rejects #{option} with --build-only before creating a job" do
      expect(DeployJob).not_to receive(:new)

      expect do
        described_class.start(['run-task', '-r', 'repository', '--run-task', 'task', '--build-only', option, 'value'])
      end.to raise_error(Genova::Exceptions::InvalidArgumentError, /cannot be combined/)
    end
  end
end

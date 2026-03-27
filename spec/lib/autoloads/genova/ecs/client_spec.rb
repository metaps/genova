require 'rails_helper'

module Genova
  module Ecs
    describe Client do
      describe 'deploy_service' do
        let(:deploy_job) do
          DeployJob.create!(
            id: DeployJob.generate_id,
            mode: DeployJob.mode.find_value(:manual),
            type: DeployJob.type.find_value(:service),
            account: Settings.github.account,
            repository: 'repository',
            cluster: 'cluster'
          )
        end
        let(:code_manager) { double(CodeManager::Git) }
        let(:client) { Ecs::Client.new(deploy_job, {}, ::Logger.new($stdout)) }
        let(:docker_client) { double(Genova::Docker::Client) }
        let(:ecr_client) { double(Ecr::Client) }
        let(:deploy_config) { double(Genova::Config::DeployConfig) }

        let(:task_definition) { double(Aws::ECS::Types::TaskDefinition) }
        let(:task_client) { double(Ecs::Task::Client) }

        before do
          DeployJob.collection.drop

          allow(docker_client).to receive(:build_image).and_return(0.0)
          allow(Genova::Docker::Client).to receive(:new).and_return(docker_client)

          allow(deploy_config).to receive(:find_service).and_return({})

          allow(code_manager).to receive(:deploy_config).and_return(deploy_config)
          allow(code_manager).to receive(:task_definition_config_path).and_return('task_definition_path')
          allow(code_manager).to receive(:base_path).and_return('/repo')
          allow(code_manager).to receive(:update)
          allow(code_manager).to receive(:update_submodule)
          allow(CodeManager::Git).to receive(:new).and_return(code_manager)

          allow(task_definition).to receive(:[]).with(:container_definitions).and_return(
            [{
              name: 'web',
              image: 'xxx.dkr.ecr.ap-northeast-1.amazonaws.com/xxx:latest'
            }]
          )
          allow(task_definition).to receive(:task_definition_arn).and_return('task_definition_arn')

          allow(task_client).to receive(:register).and_return(task_definition)
          allow(Ecs::Task::Client).to receive(:new).and_return(task_client)

          allow(ecr_client).to receive(:authenticate)
          allow(ecr_client).to receive(:push_image)
          allow(Ecr::Client).to receive(:new).and_return(ecr_client)
        end

        describe 'deploy_run_task' do
          let(:run_task_client) { double(Ecs::Deployer::RunTask::Client) }

          it 'should not error' do
            allow(deploy_config).to receive(:find_run_task).and_return(
              containers: [
                name: 'web',
                image: ' xxx.dkr.ecr.ap-northeast-1.amazonaws.com/xxx:latest'
              ]
            )

            allow(run_task_client).to receive(:execute)
            allow(Ecs::Deployer::RunTask::Client).to receive(:new).and_return(run_task_client)

            expect { client.deploy_run_task }.to_not raise_error
          end

          it 'resolves environment_from_files in container_overrides' do
            allow(File).to receive(:file?).with('/repo/config/app.env').and_return(true)
            allow(File).to receive(:file?).with('/repo/config/shared.yml').and_return(true)
            allow(File).to receive(:read).with('/repo/config/app.env').and_return("DOTENV_KEY=dotenv\nFILE_OVERRIDE=dotenv\nSHARED_KEY=dotenv\n")
            allow(File).to receive(:read).with('/repo/config/shared.yml').and_return(
              {
                'FILE_OVERRIDE' => 'yaml',
                'YAML_KEY' => 1,
                'SHARED_KEY' => 'yaml'
              }.to_yaml
            )

            allow(deploy_config).to receive(:find_run_task).and_return(
              containers: [
                name: 'web',
                image: ' xxx.dkr.ecr.ap-northeast-1.amazonaws.com/xxx:latest'
              ],
              container_overrides: [
                {
                  name: 'web',
                  environment_from_files: [
                    './app.env',
                    './shared.yml'
                  ],
                  environment: [
                    { 'INLINE_ONLY' => 'inline' },
                    { 'SHARED_KEY' => 'inline_override' }
                  ]
                }
              ]
            )

            expect(run_task_client).to receive(:execute) do |_task_definition_arn, options|
              expect(
                options[:container_overrides][0][:environment].to_h { |environment| [environment[:name], environment[:value]] }
              ).to eq(
                'DOTENV_KEY' => 'dotenv',
                'FILE_OVERRIDE' => 'yaml',
                'YAML_KEY' => '1',
                'INLINE_ONLY' => 'inline',
                'SHARED_KEY' => 'inline_override'
              )
            end
            allow(Ecs::Deployer::RunTask::Client).to receive(:new).and_return(run_task_client)

            expect { client.deploy_run_task }.to_not raise_error
          end
        end

        describe 'deploy_service' do
          let(:service_client) { double(Ecs::Deployer::Service::Client) }

          it 'should not error' do
            allow(deploy_config).to receive(:find_service).and_return(
              containers: [
                name: 'web'
              ]
            )
            allow(service_client).to receive(:update)
            allow(service_client).to receive(:exist?).and_return(true)
            allow(Ecs::Deployer::Service::Client).to receive(:new).and_return(service_client)

            expect { client.deploy_service }.to_not raise_error
          end
        end

        describe 'deploy_scheduled_task' do
          let(:scheduled_task_client) { double(Ecs::Deployer::ScheduledTask::Client) }

          it 'resolves environment_from_files in container_overrides' do
            allow(File).to receive(:file?).with('/repo/config/app.env').and_return(true)
            allow(File).to receive(:file?).with('/repo/config/shared.yml').and_return(true)
            allow(File).to receive(:read).with('/repo/config/app.env').and_return("DOTENV_KEY=dotenv\nFILE_OVERRIDE=dotenv\nSHARED_KEY=dotenv\n")
            allow(File).to receive(:read).with('/repo/config/shared.yml').and_return(
              {
                'FILE_OVERRIDE' => 'yaml',
                'YAML_KEY' => 1,
                'SHARED_KEY' => 'yaml'
              }.to_yaml
            )

            allow(deploy_config).to receive(:find_scheduled_task_rule).and_return(
              rule: 'nightly',
              expression: 'cron(0 0 * * ? *)',
              containers: [
                name: 'web',
                image: ' xxx.dkr.ecr.ap-northeast-1.amazonaws.com/xxx:latest'
              ]
            )
            allow(deploy_config).to receive(:find_scheduled_task_target).and_return(
              name: 'job',
              path: 'task.yml',
              containers: [
                name: 'web',
                image: ' xxx.dkr.ecr.ap-northeast-1.amazonaws.com/xxx:latest'
              ],
              container_overrides: [
                {
                  name: 'web',
                  environment_from_files: [
                    './app.env',
                    './shared.yml'
                  ],
                  environment: [
                    { 'INLINE_ONLY' => 'inline' },
                    { 'SHARED_KEY' => 'inline_override' }
                  ]
                }
              ]
            )

            expect(Ecs::Deployer::ScheduledTask::Target).to receive(:build) do |_deploy_job, _task_definition_arn, target_config, _logger|
              expect(
                target_config[:container_overrides][0][:environment].to_h { |environment| [environment[:name], environment[:value]] }
              ).to eq(
                'DOTENV_KEY' => 'dotenv',
                'FILE_OVERRIDE' => 'yaml',
                'YAML_KEY' => '1',
                'INLINE_ONLY' => 'inline',
                'SHARED_KEY' => 'inline_override'
              )
              { ecs_parameters: { task_definition_arn: 'task_definition_arn' } }
            end
            allow(scheduled_task_client).to receive(:update)
            allow(Ecs::Deployer::ScheduledTask::Client).to receive(:new).and_return(scheduled_task_client)

            expect { client.deploy_scheduled_task }.to_not raise_error
          end
        end
      end
    end
  end
end

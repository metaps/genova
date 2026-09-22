class DeployJobStreamsController < ActionController::Base
  include ActionController::Live

  POLL_INTERVAL = 1
  HEARTBEAT_INTERVAL = 20
  MAX_STREAM_SECONDS = 900
  FINISHED_STATUSES = %w[success failure cancel].freeze

  def show
    deploy_job = DeployJob.find(params[:id])
    return head(:not_found) if deploy_job.nil?

    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no'

    sent = (request.headers['Last-Event-ID'] || params[:offset]).to_i
    last_status = nil
    idle = 0
    deadline = Time.now + MAX_STREAM_SECONDS

    loop do
      deploy_job.reload
      logs = deploy_job.logs || []

      if logs.length > sent
        logs[sent..].each_with_index do |line, i|
          write_event(sent + i + 1, { type: 'log', line: })
        end

        sent = logs.length
        idle = 0
      end

      if deploy_job.status != last_status
        last_status = deploy_job.status
        write_event(nil, { type: 'status', status: deploy_job.status, finished: FINISHED_STATUSES.include?(deploy_job.status) })
        idle = 0
      end

      break if FINISHED_STATUSES.include?(deploy_job.status)

      idle += POLL_INTERVAL

      if idle >= HEARTBEAT_INTERVAL
        response.stream.write(": heartbeat\n\n")
        idle = 0
      end

      sleep POLL_INTERVAL
    end
  rescue ActionController::Live::ClientDisconnected, IOError
  ensure
    response.stream.close
  end

  private

  def write_event(id, payload)
    response.stream.write("id: #{id}\n") if id
    response.stream.write("data: #{payload.to_json}\n\n")
  end
end

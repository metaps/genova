# Streams a deploy job's logs and status to the console via Server-Sent Events
# so the page tails output like GitHub Actions. Kept separate from
# DeployJobsController because ActionController::Live changes response handling
# for every action in the controller it is included in.
class DeployJobStreamsController < ActionController::Base
  include ActionController::Live

  POLL_INTERVAL = 1
  HEARTBEAT_INTERVAL = 20
  # Cap how long a single connection holds a Puma thread. When the deploy is
  # still running past this, the stream closes and the browser's EventSource
  # reconnects, resuming from Last-Event-ID. This bounds thread occupancy so a
  # long-running or stuck deploy (or an abandoned open tab) cannot pin a thread
  # indefinitely.
  MAX_STREAM_SECONDS = 600
  FINISHED_STATUSES = %w[success failure cancel].freeze

  def show
    deploy_job = DeployJob.find(params[:id])
    return head(:not_found) if deploy_job.nil?

    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    # Tell nginx not to buffer this response so events flush immediately,
    # without requiring an nginx config change.
    response.headers['X-Accel-Buffering'] = 'no'

    # Resume from the last event the browser received (SSE reconnect) or from
    # the count of log lines the page already rendered server-side.
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
      break if Time.now >= deadline

      idle += POLL_INTERVAL
      if idle >= HEARTBEAT_INTERVAL
        response.stream.write(": heartbeat\n\n")
        idle = 0
      end

      sleep POLL_INTERVAL
    end
  rescue ActionController::Live::ClientDisconnected, IOError
    # Browser closed the connection; nothing to clean up beyond the ensure.
  ensure
    response.stream.close
  end

  private

  def write_event(id, payload)
    response.stream.write("id: #{id}\n") if id
    response.stream.write("data: #{payload.to_json}\n\n")
  end
end

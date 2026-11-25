# frozen_string_literal: true

require 'logger'
require 'active_job'

ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = Logger.new(nil)

class TestJob < ActiveJob::Base
  MAX_RETRIES = 5

  TestRetryError = Class.new(StandardError)
  TestDiscardError = Class.new(StandardError)
  TestSuppressError = Class.new(StandardError)
  TestEnqueueError = Class.new(StandardError)

  before_enqueue do |job|
    enqueue_error = (job.arguments.first || {})[:enqueue_error]
    raise enqueue_error unless enqueue_error.nil?
  end

  queue_as :default
  retry_on(TestRetryError, attempts: MAX_RETRIES)
  discard_on(TestDiscardError)
  rescue_from(TestSuppressError) { |_error| nil }

  def perform(error: nil)
    sleep 0.00123 # simulate work
    raise error unless error.nil?
  end
end

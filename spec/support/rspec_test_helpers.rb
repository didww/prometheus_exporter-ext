# frozen_string_literal: true

module RSpecTestHelpers
  # @param data [Hash]
  # @return [Hash]
  def deep_stringify_keys(data)
    JSON.parse JSON.generate(data)
  end
end

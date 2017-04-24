require 'httparty'
require 'date'
require 'json'

module Rubotnik
  class WitUnderstander
    include HTTParty
    # debug_output $stdout
    base_uri 'https://api.wit.ai/message'

    # TODO: Should the version be today? Or take value at init?
    def initialize(token)
      @header = "Bearer #{token}"
      @version = Date.today.to_s
      @cache = {}
    end

    # TODO: Compare the key AND the value in the cache 
    def full_response(string)
      options = {
        query: { v: @version, q: string },
        headers: { 'Authorization' => @header }
      }
      return @cache[string] if @cache.key?(string)
      puts "made a request to Wit API"
      start = Time.now
      @cache[string] = JSON.parse(self.class.get('', options).body,
                             symbolize_names: true)
      puts "Took #{Time.now - start} seconds"
      @cache[string]
    end

    def entities(string)
      full_response(string)[:entities]
    end

    def entity_values(string, entity_name)
      return [] unless entities(string).key?(entity_name)
      entities(string)[entity_name].map { |e| e[:value] }
    end
  end
end

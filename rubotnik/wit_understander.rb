require 'httparty'
require 'date'
require 'json'

module Rubotnik
  class WitUnderstander
    include HTTParty
    # debug_output $stdout
    base_uri 'https://api.wit.ai'

    # TODO: Mention explicit version setting in README
    def initialize(token, version: nil)
      @bearer = "Bearer #{token}"
      @version = version || Date.today.to_s
      @cache = {}
    end

    # TODO: Compare the key AND the value in the cache
    def full_response(string)
      options = {
        query: { v: @version, q: string },
        headers: { 'Authorization' => @bearer }
      }
      # grab a response from cache if it was done in the lifetime of an instance
      # TODO: account for learning
      return @cache[string] if @cache.key?(string)
      # make a request if not found in cache
      puts "made a request to Wit API"
      start = Time.now
      @cache[string] = JSON.parse(self.class.get('/message', options).body,
                             symbolize_names: true)
      puts "Took #{Time.now - start} seconds"
      @cache[string]
    end

    def train(string, trait_entity: nil, word_entities: nil)
      body = self.class.build_training_sample(string, trait_entity: trait_entity,
                                              word_entities: word_entities)
      options = {
        headers: {
          'Authorization' => @bearer,
          'Content-Type' => 'application/json'
        },
        body: body.to_json
      }
      self.class.post('/samples', options)
    end
    
    def entities(string)
      full_response(string)[:entities]
    end

    def entity_values(string, entity_name)
      return [] unless entities(string).key?(entity_name)
      entities(string)[entity_name].map { |e| e[:value] }
    end

    # CLASS METHODS

    # takes an original string, a string of substrings
    # and an entity name as symbol, separates sunstrings on 'OR' or ','
    # returns an array of "entity" hashes
    def self.build_word_entities(string, substrings, entity_name)
      words = substrings.split(", ") # split on comma if not separated by 'or's
      words = substrings.split(" or ") if substrings =~ / or /
      words.each.map do |word|
        { "entity" => entity_name.to_s }.merge(substring_offset(string, word))
      end
    end

    # Takes original string and a trait name as symbol
    def self.build_trait_entity(trait, value)
      {
        "entity" => trait.to_s,
        "value" => value
      }
    end

    # takes an original string, hash generated by assign_trait_entity
    # and array of hashes generated by assign_word_entities
    def self.build_training_sample(string, trait_entity: nil, word_entities: nil)
      entities = []
      entities << trait_entity unless trait_entity.nil?
      entities += word_entities unless word_entities.nil?
      [{ "text" => string, "entities" => entities }]
    end


    # returns a hash of form {"start" => start_index, "end" => end_index}
    def self.substring_offset(string, substring)
      match = string.match(/#{substring}/i)
      return nil if match.nil?
      match.offset(0).zip(%w[start end]).to_h.invert
    end

    private_class_method :substring_offset

  end
end
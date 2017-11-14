# frozen_string_literal: true
module Valkyrie::Persistence::CloudSearch::Queries
  class FindAllQuery
    attr_reader :connection, :resource_factory, :model
    def initialize(connection:, resource_factory:, model: nil)
      @connection = connection
      @resource_factory = resource_factory
      @model = model
    end

    def run
      enum_for(:each)
    end

    def each
      cursor = 'initial'
      loop do
        response = connection.search(query: query, query_parser: 'structured', size: 100, cursor: cursor)
        break if response.hits.hit.empty?
        cursor = response.hits.cursor
        response.hits.hit.each do |hit|
          yield resource_factory.to_resource(object: hit)
        end
      end
    end

    def query
      if !model
        "matchall"
      else
        "#{Valkyrie::Persistence::CloudSearch::Queries::MODEL}:'#{model}'"
      end
    end
  end
end

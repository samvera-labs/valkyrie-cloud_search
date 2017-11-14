# frozen_string_literal: true
module Valkyrie::Persistence::CloudSearch::Queries
  class FindReferencesQuery
    attr_reader :resource, :property, :connection, :resource_factory
    def initialize(resource:, property:, connection:, resource_factory:)
      @resource = resource
      @property = property
      @connection = connection
      @resource_factory = resource_factory
    end

    def run
      enum_for(:each)
    end

    def each
      ids = Array.wrap(resource.send(property.to_sym))
      ids.each do |find_id|
        response = connection.search(query: "join_id_ssi:'id-#{find_id}'", query_parser: 'structured', size: 1)
        response.hits.hit.each do |hit|
          yield resource_factory.to_resource(object: hit)
        end
      end
    end

    def id
      resource.id.to_s
    end
  end
end

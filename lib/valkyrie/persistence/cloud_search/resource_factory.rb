# frozen_string_literal: true
module Valkyrie::Persistence::CloudSearch
  class ResourceFactory
    require 'valkyrie/persistence/cloud_search/orm_converter'
    require 'valkyrie/persistence/cloud_search/model_converter'
    attr_reader :resource_indexer
    def initialize(resource_indexer:)
      @resource_indexer = resource_indexer
    end

    # @param object [Hash] The CloudSearch hit to convert to a
    #   resource.
    # @return [Valkyrie::Resource]
    def to_resource(object:)
      ORMConverter.new(object).convert!
    end

    # @param resource [Valkyrie::Resource] The resource to convert to a CloudSearch hash.
    # @return [Hash] The CloudSearch document represented as a hash.
    def from_resource(resource:)
      Valkyrie::Persistence::CloudSearch::ModelConverter.new(resource, resource_factory: self).convert!
    end
  end
end

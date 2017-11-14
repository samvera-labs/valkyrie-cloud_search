# frozen_string_literal: true
require 'aws-sdk-cloudsearchdomain'
module Valkyrie::Persistence::CloudSearch
  require 'valkyrie/persistence/cloud_search/persister'
  require 'valkyrie/persistence/cloud_search/query_service'
  require 'valkyrie/persistence/cloud_search/resource_factory'
  class BasicMetadataAdapter
    attr_reader :connection, :resource_indexer
    # @param connection [Aws::CloudSearchDomain::Client] The CloudSearch connection to index to.
    # @param resource_indexer [Class, #to_search_doc] An indexer which is able to
    #   receive a `resource` argument and then has an instance method `#to_search_doc`
    def initialize(connection:, resource_indexer: NullIndexer)
      @connection = connection
      @resource_indexer = resource_indexer
    end

    # @return [Valkyrie::Persistence::CloudSearch::Persister] The CloudSearch persister.
    def persister
      Valkyrie::Persistence::CloudSearch::Persister.new(adapter: self)
    end

    # @return [Valkyrie::Persistence::CloudSearch::QueryService] The CloudSearch query
    #   service.
    def query_service
      @query_service ||= Valkyrie::Persistence::CloudSearch::QueryService.new(
        connection: connection,
        resource_factory: resource_factory
      )
    end

    # @return [Valkyrie::Persistence::CloudSearch::ResourceFactory] A resource factory
    #   to convert a resource to a CloudSearch document and back.
    def resource_factory
      Valkyrie::Persistence::CloudSearch::ResourceFactory.new(resource_indexer: resource_indexer)
    end

    class NullIndexer
      def initialize(_); end

      def to_search_doc
        {}
      end
    end
  end
end

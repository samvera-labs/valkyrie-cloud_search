# frozen_string_literal: true
module Valkyrie::Persistence::CloudSearch
  require 'valkyrie/persistence/cloud_search/queries'
  class QueryService
    attr_reader :connection, :resource_factory
    # @param connection [Aws::CloudSearchDomain::Client]
    # @param resource_factory [Valkyrie::Persistence::CloudSearch::ResourceFactory]
    def initialize(connection:, resource_factory:)
      @connection = connection
      @resource_factory = resource_factory
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_by)
    def find_by(id:)
      validate_id(id)
      Valkyrie::Persistence::CloudSearch::Queries::FindByIdQuery.new(id, connection: connection, resource_factory: resource_factory).run
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_all)
    def find_all
      Valkyrie::Persistence::CloudSearch::Queries::FindAllQuery.new(connection: connection, resource_factory: resource_factory).run
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_all_of_model)
    def find_all_of_model(model:)
      Valkyrie::Persistence::CloudSearch::Queries::FindAllQuery.new(connection: connection, resource_factory: resource_factory, model: model).run
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_parents)
    def find_parents(resource:)
      find_inverse_references_by(resource: resource, property: :member_ids)
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_members)
    def find_members(resource:, model: nil)
      Valkyrie::Persistence::CloudSearch::Queries::FindMembersQuery.new(resource: resource, model: model, connection: connection, resource_factory: resource_factory).run
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_references_by)
    def find_references_by(resource:, property:)
      Valkyrie::Persistence::CloudSearch::Queries::FindReferencesQuery.new(resource: resource, property: property, connection: connection, resource_factory: resource_factory).run
    end

    # (see Valkyrie::Persistence::Memory::QueryService#find_inverse_references_by)
    def find_inverse_references_by(resource:, property:)
      Valkyrie::Persistence::CloudSearch::Queries::FindInverseReferencesQuery.new(resource: resource, property: property, connection: connection, resource_factory: resource_factory).run
    end

    def custom_queries
      @custom_queries ||= ::Valkyrie::Persistence::CustomQueryContainer.new(query_service: self)
    end

    private

      def validate_id(id)
        raise ArgumentError, 'id must be a Valkyrie::ID' unless id.is_a? Valkyrie::ID
      end
  end
end

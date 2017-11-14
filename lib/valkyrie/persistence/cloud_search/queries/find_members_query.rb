# frozen_string_literal: true
module Valkyrie::Persistence::CloudSearch::Queries
  class FindMembersQuery
    attr_reader :resource, :connection, :resource_factory, :model
    def initialize(resource:, connection:, resource_factory:, model:)
      @resource = resource
      @connection = connection
      @resource_factory = resource_factory
      @model = model
    end

    def run
      enum_for(:each)
    end

    def each
      return [] unless resource.id.present?
      unordered_members.sort_by { |x| member_ids.index(x.id) }.each do |member|
        yield member
      end
    end

    def unordered_members
      docs.map do |doc|
        resource_factory.to_resource(object: doc)
      end
    end

    def docs
      # TODO: Replace the naive iterator with a smarter compound query
      options = { query_parser: 'structured', size: 1 }
      options[:filter_query] = "internal_resource_ssim:'#{model}'" if model
      Array.wrap(member_ids).collect { |member_id| connection.search(options.merge(query: "id:'#{member_id}'")).hits.hit.first }.compact
    end

    def member_ids
      return [] unless resource.respond_to?(:member_ids)
      Array.wrap(resource.member_ids)
    end

    def id
      resource.id.to_s
    end
  end
end

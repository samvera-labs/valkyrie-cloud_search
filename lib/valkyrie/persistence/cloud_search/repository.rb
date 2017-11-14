# frozen_string_literal: true
module Valkyrie::Persistence::CloudSearch
  class Repository
    attr_reader :resources, :connection, :resource_factory
    def initialize(resources:, connection:, resource_factory:)
      @resources = resources
      @connection = connection
      @resource_factory = resource_factory
    end

    def persist
      documents = resources.map do |resource|
        generate_id(resource) if resource.id.blank?
        {
          type: 'add',
          id: resource.id.to_s,
          fields: cloud_search_document(resource)
        }
      end
      connection.upload_documents documents: documents.to_json, content_type: 'application/json'
      result = documents.map do |document|
        resource_factory.to_resource(object: document.stringify_keys)
      end
      result
    end

    def delete
      batch = resources.map do |resource|
        { type: 'delete', id: resource.id.to_s }
      end
      connection.upload_documents documents: batch.to_json, content_type: 'application/json'
      resources
    end

    def cloud_search_document(resource)
      resource_factory.from_resource(resource: resource).to_h
    end

    def generate_id(resource)
      Valkyrie.logger.warn "The CloudSearch adapter is not meant to persist new resources, but is now generating an ID."
      resource.id = SecureRandom.uuid
    end
  end
end

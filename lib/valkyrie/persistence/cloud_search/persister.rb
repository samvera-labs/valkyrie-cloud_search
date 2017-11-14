# frozen_string_literal: true
module Valkyrie::Persistence::CloudSearch
  require 'valkyrie/persistence/cloud_search/repository'
  class Persister
    attr_reader :adapter
    delegate :connection, :resource_factory, to: :adapter
    # @param adapter [Valkyrie::Persistence::CloudSearch::MetadataAdapter] The adapter with the
    #   configured CloudSearch connection.
    def initialize(adapter:)
      @adapter = adapter
    end

    # (see Valkyrie::Persistence::Memory::Persister#save)
    def save(resource:)
      repository([resource]).persist.first
    end

    # (see Valkyrie::Persistence::Memory::Persister#save_all)
    def save_all(resources:)
      repository(resources).persist
    end

    # (see Valkyrie::Persistence::Memory::Persister#delete)
    def delete(resource:)
      repository([resource]).delete.first
    end

    def wipe!
      batch = find_all_ids.collect { |id| { type: 'delete', id: id } }
      return if batch.empty?
      connection.upload_documents(documents: batch.to_json, content_type: 'application/json')
    end

    def repository(resources)
      Valkyrie::Persistence::CloudSearch::Repository.new(resources: resources, connection: connection, resource_factory: resource_factory)
    end

    private

      def find_all_ids
        [].tap do |ids|
          cursor = 'initial'
          loop do
            result = connection.search(query: "matchall", query_parser: 'structured', size: 10_000, return: '_no_fields', cursor: cursor)
            break if result.hits.hit.empty?
            ids.concat result.hits.hit.collect(&:id)
            cursor = result.hits.cursor
          end
        end
      end
  end
end

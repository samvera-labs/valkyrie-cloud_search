# frozen_string_literal: true
module Valkyrie::Persistence::CloudSearch
  class CompositeIndexer
    attr_reader :indexers
    def initialize(*indexers)
      @indexers = indexers
    end

    def new(resource:)
      Instance.new(indexers, resource: resource)
    end

    class Instance
      attr_reader :indexers, :resource
      def initialize(indexers, resource:)
        @resource = resource
        @indexers = indexers.map { |i| i.new(resource: resource) }
      end

      def to_search_doc
        indexers.map(&:to_search_doc).inject({}, &:merge)
      end
    end
  end
end

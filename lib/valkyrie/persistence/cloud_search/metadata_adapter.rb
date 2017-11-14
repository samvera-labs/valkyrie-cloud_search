# frozen_string_literal: true
module Valkyrie::Persistence::CloudSearch
  class MetadataAdapter
    attr_reader :caching_adapter, :primary, :cache

    def initialize(cloud_search:, redis: Redis.new, expiration: 30.minutes, resource_indexer: Valkyrie::Persistence::CloudSearch::BasicMetadataAdapter::NullIndexer)
      instance_id = cloud_search.config.endpoint.hostname.split('.').first.split('-').last
      @primary = ::Valkyrie::Persistence::CloudSearch::BasicMetadataAdapter.new(connection: cloud_search, resource_indexer: resource_indexer)
      @cache   = ::Valkyrie::Persistence::Redis::MetadataAdapter.new(redis: redis, expiration: expiration, cache_prefix: "_valk_#{instance_id}_")
      @caching_adapter = ::Valkyrie::Persistence::WriteCached::MetadataAdapter.new(primary_adapter: primary, cache_adapter: cache)
    end

    delegate :persister, :query_service, to: :caching_adapter
  end
end

# frozen_string_literal: true
module Valkyrie::Persistence::CloudSearch
  class ModelConverter
    attr_reader :resource, :resource_factory
    delegate :resource_indexer, to: :resource_factory
    def initialize(resource, resource_factory:)
      @resource = resource
      @resource_factory = resource_factory
    end

    def convert!
      to_h.merge(Valkyrie::Persistence::CloudSearch::Queries::MODEL.to_sym => [resource.internal_resource])
          .merge(indexer_cloud_search(resource))
    end

    def indexer_cloud_search(resource)
      resource_indexer.new(resource: resource).to_search_doc
    end

    # @return [String] The CloudSearch document ID
    def id
      resource.id.to_s
    end

    # @return [String] ISO-8601 timestamp in UTC of the created_at for this CloudSearch
    #   document.
    def created_at
      resource_attributes[:created_at] || Time.current.utc.iso8601
    end

    # @return [Hash] CloudSearch document to index.
    def to_h
      {
        "id": id,
        "join_id_ssi": "id-#{id}",
        "created_at_dtsi": created_at
      }.merge(attribute_hash)
    end

    private

      def attribute_hash
        properties.each_with_object({}) do |property, hsh|
          CloudSearchMapperValue.for(Property.new(property, resource_attributes[property])).result.apply_to(hsh)
        end
      end

      def properties
        resource_attributes.keys - [:id, :created_at, :updated_at]
      end

      def resource_attributes
        @resource_attributes ||= resource.attributes
      end

      ##
      # A container resource for holding a `key`, `value, and `scope` of a value
      # in a resource together for casting.
      class Property
        attr_reader :key, :value, :scope
        # @param key [Symbol] Property identifier.
        # @param value [Object] Value or list of values which are underneath the
        #   key.
        # @param scope [Object] The resource or point where the key and values
        #   came from.
        def initialize(key, value, scope = [])
          @key = key
          @value = value
          @scope = scope
        end
      end

      ##
      # Represents a key/value combination in the CloudSearch document, used for isolating logic around
      # how to apply a value to a hash.
      class CloudSearchRow
        attr_reader :key, :fields, :values
        # @param key [Symbol] CloudSearch key.
        # @param fields [Array<Symbol>] Field suffixes to index into.
        # @param values [Array] Values to index into the given fields.
        def initialize(key:, fields:, values:)
          @key = key
          @fields = Array.wrap(fields)
          @values = Array.wrap(values)
        end

        # @param hsh [Hash] The CloudSearch hash to apply to.
        # @return [Hash] The updated CloudSearch hash.
        def apply_to(hsh)
          return hsh if values.blank?
          fields.each do |field|
            hsh["#{key}_#{field}".to_sym] ||= []
            hsh["#{key}_#{field}".to_sym] += values
          end
          hsh
        end
      end

      ##
      # Wraps up multiple CloudSearchRows to apply them all at once, while looking like
      # just one.
      class CompositeCloudSearchRow
        attr_reader :cloud_search_rows
        def initialize(cloud_search_rows)
          @cloud_search_rows = cloud_search_rows
        end

        # @see Valkyrie::Persistence::CloudSearch::Mapper::CloudSearchRow#apply_to
        def apply_to(hsh)
          cloud_search_rows.each do |cloud_search_row|
            cloud_search_row.apply_to(hsh)
          end
          hsh
        end
      end

      # Container for casting mappers.
      class CloudSearchMapperValue < ::Valkyrie::ValueMapper
      end

      # Casts nested resources into a JSON string in CloudSearch.
      class NestedObjectValue < ::Valkyrie::ValueMapper
        CloudSearchMapperValue.register(self)
        def self.handles?(value)
          value.value.is_a?(Hash)
        end

        def result
          CloudSearchRow.new(key: value.key, fields: ["tsim"], values: "serialized-#{value.value.to_json}")
        end
      end

      # Casts enumerable values one by one.
      class EnumerableValue < ::Valkyrie::ValueMapper
        CloudSearchMapperValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.value.is_a?(Array)
        end

        def result
          CompositeCloudSearchRow.new(
            value.value.map do |val|
              calling_mapper.for(Property.new(value.key, val, value.value)).result
            end
          )
        end
      end

      # Skips nil values.
      class NilPropertyValue < ::Valkyrie::ValueMapper
        CloudSearchMapperValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.value.nil?
        end

        def result
          CloudSearchRow.new(key: value.key, fields: [], values: nil)
        end
      end

      # Casts {Valkyrie::ID} values into a recognizable string in CloudSearch.
      class IDPropertyValue < ::Valkyrie::ValueMapper
        CloudSearchMapperValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.value.is_a?(::Valkyrie::ID)
        end

        def result
          calling_mapper.for(Property.new(value.key, "id-#{value.value.id}")).result
        end
      end

      # Casts {RDF::URI} values into a recognizable string in CloudSearch.
      class URIPropertyValue < ::Valkyrie::ValueMapper
        CloudSearchMapperValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.value.is_a?(::RDF::URI)
        end

        def result
          calling_mapper.for(Property.new(value.key, "uri-#{value.value}")).result
        end
      end

      # Casts {Integer} values into a recognizable string in CloudSearch.
      class IntegerPropertyValue < ::Valkyrie::ValueMapper
        CloudSearchMapperValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.value.is_a?(Integer)
        end

        def result
          calling_mapper.for(Property.new(value.key, "integer-#{value.value}")).result
        end
      end

      # Casts {DateTime} values into a recognizable string in CloudSearch.
      class DateTimePropertyValue < ::Valkyrie::ValueMapper
        CloudSearchMapperValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && (value.value.is_a?(Time) || value.value.is_a?(DateTime))
        end

        def result
          calling_mapper.for(Property.new(value.key, "datetime-#{JSON.parse(to_datetime(value.value).to_json)}")).result
        end

        private

          def to_datetime(value)
            return value.utc if value.is_a?(DateTime)
            return value.to_datetime.utc if value.respond_to?(:to_datetime)
          end
      end

      # Handles casting language-tagged strings when there are both
      # language-tagged and non-language-tagged strings in CloudSearch. Assumes English
      # for non-language-tagged strings.
      class SharedStringPropertyValue < ::Valkyrie::ValueMapper
        CloudSearchMapperValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.value.is_a?(String) && value.scope.find { |x| x.is_a?(::RDF::Literal) }.present?
        end

        def result
          CompositeCloudSearchRow.new(
            [
              calling_mapper.for(Property.new(value.key, value.value)).result,
              calling_mapper.for(Property.new("#{value.key}_lang", "eng")).result
            ]
          )
        end
      end

      # Handles casting strings.
      class StringPropertyValue < ::Valkyrie::ValueMapper
        CloudSearchMapperValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.value.is_a?(String)
        end

        def result
          CloudSearchRow.new(key: value.key, fields: fields, values: value.value)
        end

        def fields
          if value.value.length > 1000
            [:tsim]
          else
            [:tsim, :ssim, :tesim]
          end
        end
      end

      # Handles casting language-typed {RDF::Literal}s
      class LiteralPropertyValue < ::Valkyrie::ValueMapper
        CloudSearchMapperValue.register(self)
        def self.handles?(value)
          value.is_a?(Property) && value.value.is_a?(::RDF::Literal)
        end

        def result
          CompositeCloudSearchRow.new(
            [
              calling_mapper.for(Property.new(value.key, value.value.to_s)).result,
              calling_mapper.for(Property.new("#{value.key}_lang", value.value.language.to_s)).result
            ]
          )
        end
      end
  end
end

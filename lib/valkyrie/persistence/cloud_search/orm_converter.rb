# frozen_string_literal: true
module Valkyrie::Persistence::CloudSearch
  ##
  # Converts a CloudSearch doc to a {Valkyrie::Resource}
  class ORMConverter
    class UnknownResource < Valkyrie::Resource
      attribute :id, Valkyrie::Types::ID.optional
    end

    attr_reader :doc
    def initialize(doc)
      @doc = doc['fields'].stringify_keys
    end

    def convert!
      resource
    end

    def resource
      resource_klass.new(attributes.symbolize_keys)
    rescue
      UnknownResource.new(attributes.symbolize_keys)
    end

    def resource_klass
      internal_resource.constantize
    end

    def internal_resource
      doc[Valkyrie::Persistence::CloudSearch::Queries::MODEL].first
    end

    def attributes
      attribute_hash.merge("id" => id, internal_resource: internal_resource, created_at: created_at, updated_at: updated_at)
    end

    def created_at
      DateTime.parse(doc["created_at_dtsi"].to_s).utc
    end

    def updated_at
      DateTime.parse(doc["timestamp"] || doc["created_at_dtsi"].to_s).utc
    end

    def id
      Array.wrap(doc['id']).first
    end

    def attribute_hash
      build_literals(strip_tsim(doc.select do |k, _v|
        k.end_with?("tsim")
      end))
    end

    def strip_tsim(hsh)
      Hash[
        hsh.map do |k, v|
          [k.gsub("_tsim", ""), v]
        end
      ]
    end

    class Property
      attr_reader :key, :value, :document
      def initialize(key, value, document)
        @key = key
        @value = value
        @document = document
      end
    end

    def build_literals(hsh)
      hsh.each_with_object({}) do |(key, value), output|
        next if key.end_with?("_lang")
        output[key] = CloudSearchValue.for(Property.new(key, value, hsh)).result
      end
    end

    class CloudSearchValue < ::Valkyrie::ValueMapper
    end

    # Converts a stored language typed literal from two fields into one
    #   {RDF::Literal}
    class LanguagePropertyValue < ::Valkyrie::ValueMapper
      CloudSearchValue.register(self)
      def self.handles?(value)
        value.is_a?(Property) && value.document["#{value.key}_lang"]
      end

      def result
        value.value.zip(languages).map do |literal, language|
          if language == "eng"
            literal
          else
            RDF::Literal.new(literal, language: language)
          end
        end
      end

      def languages
        value.document["#{value.key}_lang"]
      end
    end
    class PropertyValue < ::Valkyrie::ValueMapper
      CloudSearchValue.register(self)
      def self.handles?(value)
        value.is_a?(Property)
      end

      def result
        calling_mapper.for(value.value).result
      end
    end
    class EnumerableValue < ::Valkyrie::ValueMapper
      CloudSearchValue.register(self)
      def self.handles?(value)
        value.respond_to?(:each)
      end

      def result
        value.map do |element|
          calling_mapper.for(element).result
        end
      end
    end

    # Converts a stored ID value in CloudSearch into a {Valkyrie::ID}
    class IDValue < ::Valkyrie::ValueMapper
      CloudSearchValue.register(self)
      def self.handles?(value)
        value.to_s.start_with?("id-")
      end

      def result
        Valkyrie::ID.new(value.gsub(/^id-/, ''))
      end
    end

    # Converts a stored URI value in CloudSearch into a {RDF::URI}
    class URIValue < ::Valkyrie::ValueMapper
      CloudSearchValue.register(self)
      def self.handles?(value)
        value.to_s.start_with?("uri-")
      end

      def result
        ::RDF::URI.new(value.gsub(/^uri-/, ''))
      end
    end

    # Converts a nested resource in CloudSearch into a {Valkyrie::Resource}
    class NestedResourceValue < ::Valkyrie::ValueMapper
      CloudSearchValue.register(self)
      def self.handles?(value)
        value.to_s.start_with?("serialized-")
      end

      def result
        NestedResourceConverter.for(JSON.parse(json, symbolize_names: true)).result
      end

      def json
        value.gsub(/^serialized-/, '')
      end
    end

    class NestedResourceConverter < ::Valkyrie::ValueMapper
    end

    class NestedEnumerable < ::Valkyrie::ValueMapper
      NestedResourceConverter.register(self)
      def self.handles?(value)
        value.is_a?(Array)
      end

      def result
        value.map do |v|
          calling_mapper.for(v).result
        end
      end
    end

    class NestedResourceID < ::Valkyrie::ValueMapper
      NestedResourceConverter.register(self)
      def self.handles?(value)
        value.is_a?(Hash) && value[:id] && !value[:internal_resource]
      end

      def result
        Valkyrie::ID.new(value[:id])
      end
    end

    class NestedResourceURI < ::Valkyrie::ValueMapper
      NestedResourceConverter.register(self)
      def self.handles?(value)
        value.is_a?(Hash) && value[:@id]
      end

      def result
        RDF::URI(value[:@id])
      end
    end

    class NestedResourceLiteral < ::Valkyrie::ValueMapper
      NestedResourceConverter.register(self)
      def self.handles?(value)
        value.is_a?(Hash) && value[:@value]
      end

      def result
        RDF::Literal.new(value[:@value], language: value[:@language])
      end
    end

    class NestedResourceHash < ::Valkyrie::ValueMapper
      NestedResourceConverter.register(self)
      def self.handles?(value)
        value.is_a?(Hash)
      end

      def result
        Hash[
          value.map do |k, v|
            [k, calling_mapper.for(v).result]
          end
        ]
      end
    end

    # Converts an integer in CloudSearch into an {Integer}
    class IntegerValue < ::Valkyrie::ValueMapper
      CloudSearchValue.register(self)
      def self.handles?(value)
        value.to_s.start_with?("integer-")
      end

      def result
        value.gsub(/^integer-/, '').to_i
      end
    end

    # Converts a datetime in CloudSearch into a {DateTime}
    class DateTimeValue < ::Valkyrie::ValueMapper
      CloudSearchValue.register(self)
      def self.handles?(value)
        return false unless value.to_s.start_with?("datetime-")
        DateTime.iso8601(value.gsub(/^datetime-/, '')).utc
      rescue
        false
      end

      def result
        DateTime.parse(value.gsub(/^datetime-/, '')).utc
      end
    end
  end
end

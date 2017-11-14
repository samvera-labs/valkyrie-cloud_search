# frozen_string_literal: true
require 'spec_helper'
require 'valkyrie/specs/shared_specs'

RSpec.describe Valkyrie::Persistence::CloudSearch::CompositeIndexer do
  let(:adapter) { Valkyrie::Persistence::CloudSearch::BasicMetadataAdapter.new(connection: client, resource_indexer: composite_indexer) }
  let(:composite_indexer) { described_class.new indexer }
  let(:indexer) { ResourceIndexer }
  let(:client) { CloudSearchTestHarness.create }
  let(:resource) { Resource.new(title: ["Test"], other_title: ["Author"]) }

  before do
    class ResourceIndexer
      attr_reader :resource

      def initialize(resource:)
        @resource = resource
      end

      def to_search_doc
        {
          "combined_title_ssim" => resource.title + resource.other_title
        }
      end
    end
    class Resource < Valkyrie::Resource
      attribute :id, Valkyrie::Types::ID.optional
      attribute :title, Valkyrie::Types::Set
      attribute :other_title, Valkyrie::Types::Set
    end
  end
  after do
    Object.send(:remove_const, :ResourceIndexer)
    Object.send(:remove_const, :Resource)
  end

  it "adds custom indexing from the embedded Indexer" do
    expect(adapter.resource_factory.from_resource(resource: resource)["combined_title_ssim"]).to eq ["Test", "Author"]
  end
end

# frozen_string_literal: true
require 'spec_helper'
require 'valkyrie/specs/shared_specs'

RSpec.describe Valkyrie::Persistence::CloudSearch::MetadataAdapter do
  context "without a valid CloudSearch endpoint", if: ENV['CLOUDSEARCH_ENDPOINT'].nil? do
    it "doesn't execute any tests" do
      pending("Set ENV['CLOUDSEARCH_ENDPOINT'] to test AWS CloudSearch")
      expect(ENV['CLOUDSEARCH_ENDPOINT']).to be
    end
  end

  context "with a valid CloudSearch endpoint", unless: ENV['CLOUDSEARCH_ENDPOINT'].nil? do
    before do
      described_class.new(cloud_search: client).persister.wipe!
    end

    let(:adapter) { described_class.new(cloud_search: client) }
    let(:query_service) { adapter.query_service }
    let(:persister) { adapter.persister }
    let(:client) { Aws::CloudSearchDomain::Client.new(endpoint: ENV['CLOUDSEARCH_ENDPOINT']) }
    it_behaves_like "a Valkyrie::MetadataAdapter"
    it_behaves_like "a Valkyrie::Persister"
    it_behaves_like "a Valkyrie query provider"
  end
end

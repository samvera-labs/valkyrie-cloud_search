# frozen_string_literal: true
require 'spec_helper'
require 'valkyrie/specs/shared_specs'

RSpec.describe Valkyrie::Persistence::CloudSearch::BasicMetadataAdapter do
  let(:adapter) { described_class.new(connection: client) }
  let(:client) { CloudSearchTestHarness.create }
  it_behaves_like "a Valkyrie::MetadataAdapter"
end

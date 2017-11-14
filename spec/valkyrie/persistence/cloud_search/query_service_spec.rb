# frozen_string_literal: true
require 'spec_helper'
require 'valkyrie/specs/shared_specs'

RSpec.describe Valkyrie::Persistence::CloudSearch::QueryService do
  let(:adapter) { Valkyrie::Persistence::CloudSearch::BasicMetadataAdapter.new(connection: client) }
  let(:client) { CloudSearchTestHarness.create }
  it_behaves_like "a Valkyrie query provider"
end

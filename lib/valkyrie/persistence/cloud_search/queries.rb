# frozen_string_literal: true
module Valkyrie::Persistence::CloudSearch
  module Queries
    MEMBER_IDS = 'member_ids_ssim'
    MODEL = 'internal_resource_ssim'
    require 'valkyrie/persistence/cloud_search/queries/find_all_query'
    require 'valkyrie/persistence/cloud_search/queries/find_by_id_query'
    require 'valkyrie/persistence/cloud_search/queries/find_inverse_references_query'
    require 'valkyrie/persistence/cloud_search/queries/find_members_query'
    require 'valkyrie/persistence/cloud_search/queries/find_references_query'
  end
end

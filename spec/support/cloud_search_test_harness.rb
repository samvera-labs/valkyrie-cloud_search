# frozen_string_literal: true
# If ENV['CLOUDSEARCH_ENDPOINT'] is set, the test will be run against the live CloudSearch instance. Otherwise,
# it will use a "live stub" that puts a thin subset of the CloudSearchDomain Ruby API in front of Solr.

class CloudSearchTestHarness
  def self.create
    @harness ||= SolrClient.new(solr: RSolr.connect(url: SOLR_TEST_URL))
  end

  class SolrClient
    def initialize(solr:)
      @solr = solr
    end

    def search(options = {})
      solr_params = {
        cursorMark: options[:cursor] == 'initial' ? '*' : options[:cursor],
        fq: options[:filter_query].nil? ? nil : requote_query(options[:filter_query]),
        q: options[:query] == 'matchall' ? '*:*' : requote_query(options[:query]),
        defType: 'lucene',
        return: 'json',
        rows: options[:size],
        sort: [options[:sort], 'id desc'].compact.join(' '),
        start: options[:start]
      }
      solr_params.delete_if { |_k, v| v.nil? }
      response = @solr.get("select", params: solr_params)
      convert_solr_search_response(response)
    end

    def suggest(_options = {})
      raise "Not Implemented"
    end

    def upload_documents(options = {})
      i = 1
      docs = JSON.parse(options[:documents])
      solr_batch = docs.each.with_object({}) do |odoc, hash|
        doc = odoc.stringify_keys
        case doc['type']
        when 'add'
          hash["add__UNIQUE_SOLR_DOC_SUFFIX_#{i += 1}"] = { doc: doc['fields'].merge('id' => doc['id']) }
        when 'delete'
          hash["delete__UNIQUE_SOLR_DOC_SUFFIX_#{i += 1}"] = { id: doc['id'] }
        end
      end.to_json.gsub(/__UNIQUE_SOLR_DOC_SUFFIX_\d+/, '')
      response = @solr.update(data: solr_batch, headers: { 'Content-Type' => 'application/json' })
      @solr.commit
      convert_solr_update_response(response, docs)
    end

    private

      def requote_query(q)
        return nil if q.nil?
        q.gsub(/:'(.+?)'/, ':"\1"')
      end

      def convert_solr_update_response(response, docs)
        Aws::CloudSearchDomain::Types::UploadDocumentsResponse.new(
          adds: docs.count { |doc| doc['type'] == 'add' },
          deletes: docs.count { |doc| doc['type'] == 'delete' },
          status: "#{response['responseHeader']['QTime']}ms"
        )
      end

      def convert_solr_search_response(response)
        hit_list = response['response']['docs'].collect do |doc|
          Aws::CloudSearchDomain::Types::Hit.new(id: doc['id'], fields: doc)
        end
        Aws::CloudSearchDomain::Types::SearchResponse.new(
          status: Aws::CloudSearchDomain::Types::SearchStatus.new(rid: SecureRandom.uuid,
                                                                  timems: response['responseHeader']['QTime']),
          hits: Aws::CloudSearchDomain::Types::Hits.new(cursor: response['nextCursorMark'],
                                                        found: response['response']['numFound'],
                                                        start: response['response']['start'],
                                                        hit: hit_list),
          facets: nil,
          stats: nil
        )
      end
  end
end

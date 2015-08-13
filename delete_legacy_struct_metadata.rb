q = "struct_metadata__order_ssi:[* TO *]"
results = ActiveFedora::SolrService.query(q, rows: 999999)
puts "Found #{results.count} objects with legacy structural metadata."
results.each do |result|
  obj = ActiveFedora::Base.find(result['id'])
  if obj.structMetadata.content.present?
    puts "Deleting legacy structural metadata from #{obj.pid}"
    obj.datastreams['structMetadata'].delete
    obj.save!
  end
end

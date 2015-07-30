q = "#{Ddr::IndexFields::ORDER}:[* TO *]"
results = ActiveFedora::SolrService.query(q, rows: 999999)
results.each do |result|
  obj = ActiveFedora::Base.find(result['id'])
  if obj.structMetadata.content.present?
    puts "Deleting legacy structural metadata from #{obj.pid}"
    obj.datastreams['structMetadata'].delete
    obj.save!
  end
end
rows = ENV["ROWS"] || 100

def migrate_identifier(pid)
  puts "Migrating DPC identifier for #{pid}"
  obj = ActiveFedora::Base.find(pid)
  identifiers = obj.desc_metadata_values(:identifier)
  obj.local_id = identifiers.shift
  obj.set_desc_metadata_values(:identifier, identifiers)
  obj.datastreams['descMetadata'].delete if obj.descMetadata.content == ''
  # obj.save!
end

def get_governed(coll_pid)
  internal_uri_for_query = "info:fedora/#{coll_pid}".gsub(':', '\:')
  q = "is_governed_by_ssim:#{internal_uri_for_query}"
  response = ActiveFedora::SolrService.query(q, rows: 999999, fl:['id'])
end

q = 'active_fedora_model_ssi:Collection AND admin_set_ssi:dc'

dpc_colls_response = ActiveFedora::SolrService.query(q, row: rows.to_i, fl: ['id'])

puts "#{dpc_colls_response.size} DPC collection objects found."

dpc_colls_response.each do |r|
  governed = get_governed(r['id'])
  governed.each do |g|
    migrate_identifier(g['id'])
  end
end

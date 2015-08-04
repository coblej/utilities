require "resque"

rows = ENV["ROWS"] || 100

q = "content_size_isi:*"

fq = "-techmd_fits_version_ssi:*"

docs = ActiveFedora::SolrService.query(q, fq: fq, rows: rows.to_i, fl: ['id'])

puts "#{docs.size} objects found needing content characterization."

docs.each do |doc|
#  Resque.enqueue(Ddr::Jobs::FitsFileCharacterization, doc["id"])
  puts "Queued FITS content characterization for #{doc['id']}"
end

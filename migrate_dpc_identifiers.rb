admin_set = ENV['ADMIN_SET']
limit = ENV['LIMIT'] || 10

def get_governed(coll_pid)
  internal_uri_for_query = "info:fedora/#{coll_pid}".gsub(':', '\:')
  q = "is_governed_by_ssim:#{internal_uri_for_query}"
  response = ActiveFedora::SolrService.query(q, rows: 999999, fl:['id'])
end

@migrated = 0

if admin_set.present?
  admin_set_q = "active_fedora_model_ssi:Collection AND admin_set_ssi:#{admin_set}"
  admin_set_response = ActiveFedora::SolrService.query(admin_set_q, rows: 999999, fl: [ 'id' ])
  admin_set_colls = admin_set_response.map { |r| r['id'] }
end

q = "-local_id_ssi:*"
response = ActiveFedora::SolrService.query(q, rows: 999999, fl: [ 'id', 'is_governed_by_ssim' ])
puts "Examining #{response.size} objects for DPC identifier migration"
puts "Will migrate DPC identifiers for up to #{limit} objects"

response.each do |resp|
  if admin_set.present?
    if resp['is_governed_by_ssim'].present?
      coll_pid = resp['is_governed_by_ssim'].first.gsub('info:fedora/', '')
      if admin_set_colls.include?(coll_pid)
        puts "Queueing DPC identifier migration for #{resp['id']}"
        Resque.enqueue(DulHydra::Jobs::MoveFirstIdentifierToLocalId, resp['id'])
        @migrated += 1
      end
    end
  else
    puts "Queueing DPC identifier migration for #{resp['id']}"
    Resque.enqueue(DulHydra::Jobs::MoveFirstIdentifierToLocalId, resp['id'])
    @migrated += 1
  end
  break if @migrated == limit.to_i
end

puts "Queued DPC identifier migration for #{@migrated} objects"

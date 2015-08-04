require "resque"

rows = ENV["ROWS"] || 100

query = <<-EOS
discover_access_group_ssim:* OR discover_access_person_ssim:* OR
read_access_group_ssim:* OR read_access_person_ssim:* OR
edit_access_group_ssim:* OR edit_access_person_ssim:* OR
inheritable_discover_access_group_ssim:* OR
inheritable_discover_access_person_ssim:* OR
inheritable_read_access_group_ssim:* OR
inheritable_read_access_person_ssim:* OR
inheritable_edit_access_group_ssim:* OR
inheritable_edit_access_person_ssim:* OR admin_metadata__downloader_ssim:*
EOS

docs = ActiveFedora::SolrService.query(query, rows: rows.to_i, fl: ['id'])

puts "#{docs.size} objects found for legacy authorization migration."

docs.each do |doc|
  Resque.enqueue(Ddr::Jobs::MigrateLegacyAuthorization, doc["id"])
  puts "Queued legacy authorization migration for #{doc['id']}"
end

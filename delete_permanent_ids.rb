def existing_permanent_ids(rows)
  q = "#{DulHydra::IndexFields::PERMANENT_ID}:[* TO *]"
  ActiveFedora::SolrService.query(q, rows: rows)
end

puts "================================="
puts "Deleting Permanent ID's (where existing)"
puts "================================="
rows = ENV['ROWS'] || 10
deleted = 0
pids = existing_permanent_ids(rows).map { |row| row["id"] }
pids.each do |pid|
  obj = ActiveFedora::Base.find(pid)
  if obj.permanent_id.present?
    event_args = { pid: pid, summary: "Removed permanent ID" }
    begin
      old_perm_id = obj.permanent_id
      obj.permanent_id = nil
      puts "WARNING: Object #{pid} does not validate ... saving anyway" unless obj.valid?
      if obj.save(validate: false)
        deleted += 1
	MintedId.find_by(minted_id: old_perm_id).delete
        puts "Deleted permanent ID #{old_perm_id} from #{pid}"
        event_args[:outcome] = Event::SUCCESS
        event_args[:detail] = "Deleted permanent ID #{old_perm_id} from #{pid}"
      else
        raise "Unable to save object"
      end
    rescue Exception => e
      puts "Unable to delete permanent ID from #{pid}: #{e}"
      event_args[:outcome] = Event::FAILURE
      event_args[:detail] = "Unable to delete permanent ID from #{pid}"
      Rails.logger.error("Error deleting permanent ID from #{pid}: #{e}")
    end
    DulHydra::Notifications.notify_event(:update, event_args)
  end
end
puts "================================="
puts "Found #{pids.count} objects with permanent ID's"
puts "Deleted #{deleted} Permanent ID's"
puts "================================="

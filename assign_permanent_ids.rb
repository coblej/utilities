def missing_permanent_ids(rows)
  q = "-#{DulHydra::IndexFields::PERMANENT_ID}:[* TO *]"
  ActiveFedora::SolrService.query(q, rows: rows)
end

puts "================================="
puts "Assigning Permanent ID's (where needed)"
puts "================================="
rows = 20
assigned = 0
pids = missing_permanent_ids(rows).map { |row| row["id"] }
pids.each do |pid|
  obj = ActiveFedora::Base.find(pid)
  unless obj.permanent_id.present?
    event_args = { pid: pid, summary: "Assigned permanent ID" }
    begin
      obj.permanent_id = DulHydra::Services::IdService.mint
      puts "WARNING: Object #{pid} does not validate ... saving anyway" unless obj.valid?
      if obj.save(validate: false)
        assigned += 1
        puts "Assigned permanent ID #{obj.permanent_id} to #{pid}"
        event_args[:outcome] = Event::SUCCESS
        event_args[:detail] = "Assigned permanent ID #{obj.permanent_id} to #{pid}"
      # else
      #   raise "Unable to save object"
      end
    rescue Exception => e
      puts "Unable to assign permanent ID to #{pid}: #{e}"
      event_args[:outcome] = Event::FAILURE
      event_args[:detail] = "Unable to assign permanent ID to #{pid}"
      Rails.logger.error("Error assigning permanent ID to #{pid}: #{e}")
    end
    DulHydra::Notifications.notify_event(:update, event_args)
  end
end
puts "================================="
puts "Found #{pids.count} objects missing permanent ID's"
puts "Assigned #{assigned} Permanent ID's"
puts "================================="
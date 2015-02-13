puts "================================="
puts "Removing 'DPC' Component creators"
puts "================================="
count = 0
Component.find_each do |component|
  if component.creator.present?
    if component.creator == ['DPC']
      begin
        event_args = { pid: component.pid, summary: "Removed 'DPC' creator attribute" }
        component.creator = nil
        puts "Invalid component #{component.pid} ... Saving anyway" unless component.valid?
        if component.save(validate: false)
          count += 1
          event_args[:outcome] = Event::SUCCESS
          event_args[:detail] = "Removed 'DPC' creator attribute from #{component.pid}"
        else
          raise "Unable to save object"
        end
      rescue Exception => e
        puts "Unable to remove 'DPC' creator attribute from #{component.pid}: #{e}"
        event_args[:outcome] = Event::FAILURE
        event_args[:detail] = "Unable to remove 'DPC' creator attribute from #{component.pid}"
        Rails.logger.error("Error removing 'DPC' creator attribute from #{component.pid}: #{e}")
      end
      DulHydra::Notifications.notify_event(:update, event_args)
    else
      puts "WARNING: #{component.pid} has 'creator' set to #{component.creator}"
    end
  end
end
puts "================================="
puts "Removed #{count} 'DPC' Component creators"
puts "================================="


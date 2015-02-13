def handle_object(obj)
  puts "==============================="
  puts "Handling #{obj.pid}"
  @examined += 1
  details = []
  @fields.each do |field|
    field_sym = field.to_sym
    if obj.descMetadata.send(field_sym).present?
      old_values = obj.descMetadata.send(field_sym)
      new_values = []
      old_values.each do |old_value|
        new_entries = old_value.split(@delimiter)
        new_entries.each { |new_entry| new_values << new_entry.strip }
      end
      unless old_values == new_values
        puts "#{obj.pid}: Replacing '#{field}' #{old_values} with #{new_values}"
        details << "Replaced '#{field}' #{old_values} with #{new_values}"
        obj.descMetadata.send("#{field_sym}=", new_values)
      end
    end
  end
  update_object(obj, details) if obj.descMetadata.changed? && !@dryrun
  puts "==============================="
end

def update_object(obj, details)
  event_args = { pid: obj.pid, summary: "Split repeating field values", detail: details.join('; ') }
  puts "Saving updated object #{obj.pid}"
  unless @dryrun
    if obj.save
      @updated += 1
      event_args[:outcome] = Event::SUCCESS
    else
      @errored += 1
      event_args[:outcome] = Event::FAILURE
      puts "ERROR: Unable to save object #{obj.pid}: #{obj.errors}"
    end
  end
  puts "Event arguments: #{event_args}"
  DulHydra::Notifications.notify_event(:update, event_args) unless @dryrun
end

puts "==============================="
puts "Splitting repeated field values"
puts "==============================="
# Get environment variables
pid = ENV['PID']
@dryrun = ENV['DRYRUN'] == 'true' ? true : false
@fields = ENV.fetch('FIELDS', 'language:subject').split(':')
@delimiter = ENV.fetch('DELIMITER', ';')
children = ENV['CHILDREN'] == 'false' ? false : true
# Echo run parameters
puts "PID = #{pid}"
puts "DRYRUN = #{@dryrun}"
puts "FIELDS = #{@fields}"
puts "DELIMITER = #{@delimiter}"
puts "CHILDREN = #{children}"
# Find object
raise ArgumentError, 'Missing PID' unless pid.present?
object = ActiveFedora::Base.find(pid)
# Set up counters
@examined = 0
@updated = 0
@errored = 0
# Handle object
handle_object(object)
# Optionally, handle object children
if children
  if object.children.present?
    object.children.each { |child| handle_object(child) }
  end
end
puts "==============================="
puts "Examined #{@examined} objects"
puts "Updated #{@updated} objects"
puts "Encountered #{@errored} errors"
puts "===============================" 

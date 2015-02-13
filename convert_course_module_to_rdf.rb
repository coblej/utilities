command = ENV['COMMAND'] || 'report'

# Main processing block
GenericFile.find_each() do |gf|
  next unless gf.datastreams.include?("properties")
  doc = Nokogiri::XML(gf.datastreams['properties'].content) { |config| config.noblanks }
  if doc.errors.empty?
    if command == 'remove'
      properties_changed = false
      doc.root.children.each do |node|
        if node.name == "course"
          if gf.course == node.content
            puts "#{gf.pid}: Removing 'course' node"
            node.remove
            properties_changed = true
          else
            puts "ERROR -- #{gf.pid}: Cannot remove 'course' node because gf.course not properly set"
          end
        end
        if node.name == "module"
          if gf.module_number == node.content
            puts "#{gf.pid}: Removing 'module' node"
            node.remove
            properties_changed = true
          else
            puts "ERROR -- #{gf.pid}: Cannot remove 'module' node because gf.module_number not properly set"
          end
        end
        if properties_changed
          gf.datastreams['properties'].content = doc.to_xml
          puts "Saving updated #{gf.pid}"
          unless gf.valid?
            puts "WARNING -- #{gf.pid} does not validate! Saving anyway ..."
          end
          gf.save(validate: false)          
        end
      end
    else
      properties_course = nil
      properties_module = nil
      doc.root.children.each do |node|
        if node.name == "course"
          properties_course = node.content
        end
        if node.name == "module"
          properties_module = node.content
        end
      end
      case command
      when 'report'
        puts "#{gf.pid}: course: #{properties_course} module: #{properties_module}"
      when 'convert'
        gf.course = properties_course unless properties_course.blank?
        gf.module_number = properties_module unless properties_module.blank?
        if gf.datastreams['descMetadata'].changed?
          puts "Saving updated #{gf.pid}"
          unless gf.valid?
            puts "WARNING -- #{gf.pid} does not validate! Saving anyway ..."
          end
          gf.save(validate: false)
        end
      else
        puts "Unknown command: #{command}"
      end
    end
  else
    puts "Unable to parse #{gf.pid} properties as XML ... skipped"
  end
end
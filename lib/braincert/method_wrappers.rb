module Braincert
  module MethodWrappers
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # attributes returned by certain API calls that we don't model at all
      UNUSED_API_ATTRIBUTES = %w(status description published label privacy)

      def find(id)
        dummy = Braincert::LiveClass.new
        if (result_list = dummy.do_request('getclass', :class_id => id))
          Braincert::LiveClass.new(Braincert::LiveClass.from_attributes(result_list.first))
        end
      end

      def all
        if (json = self.do_request('listclass'))
          # success means we have an array of hashes.  Each one has "id" key which is class ID,
          # but also has some attributes that aren't modeled on our side: 
        end
      end

      # convert attributes retrieved from API call to attributes suitable for calling constructor
      def from_attributes(a)
        # recover the zone info
        a['start_time_with_zone'] = recover_time_with_zone(*(a.values_at('date', 'start_time', 'timezone')))
        # some keys we don't model at all
        a.delete('end_time')      # will be computed from duration and given a zone
        # string keys that must be turned into integers
        %w(duration repeat seat_attendees end_classes_count ispaid record id).each { |k| a[k] = a[k].to_i }
        UNUSED_API_ATTRIBUTES.each { |att| a.delete att }
        a
      end

      def recover_time_with_zone(date, time, zone_code)
        temp = Time.zone        # save current zone
        Time.zone = Braincert::Timezones::ZONE_CODES[zone_code]
        local_time = Time.zone.parse "#{date} #{time}"
        Time.zone = temp
        local_time
      end
    end      

    # API instance methods


    # Save a created course. Freezes the local copy since the API does not support modifying.
    def save
      errors.add(:connection, "Existing classes cannot be updated") and return nil if @persisted
      return nil unless valid?
      if (json = self.do_request('schedule', self.attributes))
        @id = json['class_id']
        @persisted = true
        self.freeze
      else
        nil
      end
    end

    def save!
      save or raise Braincert::LiveClass::SaveError, self.errors.full_messages.join(', ')
    end

    # The launch_url accepts two parameters: a role (Teacher or Student) and the name to be
    # displayed in the classroom
    # might need to take into account isTeacher they might return different urls
    # Request for launch_url can return an error response if the class did not start
    def launch_url(role_in_classroom, username)
      json_response = self.do_request('getclasslaunch', self.launch_url_params(role_in_classroom, username))
      return nil if (json_response.nil? || json_response['status'] == 'error')
      json_response['encryptedlaunchurl']
    end

    # serialize to JSON for creation

    def attributes
      attrs = {
        'title' => title,
        'timezone' => timezone,      
        'start_time' => start_time,    
        'end_time' => end_time,
        'date' => date,
        'seat_attendees' => seat_attendees,
        'record' => record,
        'format' => 'json'
      }
      if is_recurring > 0
        attrs['is_recurring'] = 1
        attrs['repeat'] = repeat
        attrs['end_classes_count'] = end_classes_count
      end
      if ispaid > 0
        attrs['currency'] = currency
        attrs['ispaid'] =  1
      end
      attrs
    end

    # serialize to JSON for launchurl request
    # role should be either Braincert::LiveClass::STUDENT or Braincert::LiveClass::TEACHER

    def launch_url_params(role, username)
      {
        'class_id' => id,
        'user_id' => user_id,
        'userName' => username,
        'isTeacher' => role,
        'lessonName' => title,
        'courseName' => title,
        'format' => 'json'
      }
    end
  end

end

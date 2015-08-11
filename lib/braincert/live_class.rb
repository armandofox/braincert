require 'active_model'
require 'active_support/core_ext/time/zones'
require 'active_support/core_ext/time/calculations'

module Braincert
  # Possible values for the "recurring course" setting
  REPEAT_DAILY, REPEAT_MON_THRU_SAT, REPEAT_MON_THRU_FRI,
  REPEAT_WEEKLY, REPEAT_MONTHLY = *(1..5)

  class LiveClass
    require_relative 'timezones'

    include ActiveModel::Validations

    include Braincert::Request
    include Braincert::MethodWrappers
    
    class SaveError < RuntimeError ; end

    # constants to represent teachers and students
    LiveClass::STUDENT = 0
    LiveClass::TEACHER = 1

    # Public attributes auto-assigned by API after creation
    attr_accessor :id, :user_id
    
    # Public required attributes on creation
    attr_accessor :title
    validates_presence_of :title

    # +timezone+ must be a timezone code.  We provide a convenience
    # method to convert Rails/IANA timezone names to these codes.
    attr_accessor :timezone
    validates_inclusion_of :timezone, :in => Braincert::Timezones::ZONE_CODES.keys

    # +start_time+, +end_time+, and +date+ must be provided in very
    # specific formats for the API.  We provide convenience methods
    # to set these up.
    attr_accessor :start_time, :end_time
    validates_format_of :start_time, :with => /\A\d\d:\d\d[AP]M\Z/
    validates_format_of :end_time, :with => /\A\d\d:\d\d[AP]M\Z/

    # a class doesn't have to repeat, but if it is repeating, then
    # we need a repeat type and number of classes.
    validates_numericality_of :end_classes_count, :in => (1..30), :if => :recurring?
    validates_numericality_of :repeat, :in => (1..5), :if => :recurring?

    attr_accessor :date
    validates_format_of :date, :with => /\A\d\d\d\d-\d\d-\d\d\Z/
    
    # Optional attributes on creation
    attr_accessor :currency, :ispaid, :is_recurring, :repeat, :end_classes_count, :end_date, :seat_attendees, :record, :format


    # attributes that are returned by GETs but don't seem to be specified at creation
    attr_accessor :duration     # in seconds
    attr_accessor :privacy      # 0=public
    attr_accessor :label        # ???
    
    attr_reader :errors         # like ActiveRecord::Errors object
    
    # default values for optional attributes on create
    DEFAULT_ATTRIBUTES = {
      :ispaid => 0,             # not paid (from Braincert point of view)
      :currency => 'USD',
      :is_recurring => 0,
      :repeat => nil,
      :end_classes_count => 1,
      :seat_attendees => 2,     # free-plan limit
      :record => 1,             # 0=don't record
      :format => 'json',
      :privacy => 1
    }

    def initialize(attrs = {})
      DEFAULT_ATTRIBUTES.merge(attrs).each_pair { |k,v| self.send("#{k}=", v) }
      @persisted = false
      @errors = ActiveModel::Errors.new(self)
    end

    def recurring? ; is_recurring.to_i > 0 ; end

    def repeat=(val)
      @repeat = val
      @is_recurring = (@repeat ? 1 : 0)
    end
    
    def start_time_with_zone=(time_with_zone)
      zone_name = time_with_zone.time_zone.name
      @localtime = time_with_zone.in_time_zone(zone_name)
      @timezone = Timezones::ZONES[zone_name]
      @start_time = @localtime.strftime('%I:%M%p')
      @date = @localtime.strftime('%Y-%m-%d')
      set_end_time_from_duration
    end

    def duration=(duration)
      @duration = duration
      set_end_time_from_duration
    end

    private

    def set_end_time_from_duration
      if (@duration.to_i > 0 && @localtime)
        @end_time = (@localtime + @duration).strftime('%I:%M%p')
      end
    end
  end
end

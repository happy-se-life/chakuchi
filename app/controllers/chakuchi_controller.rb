class ChakuchiController < ApplicationController
  unloadable
  before_action :global_authorize
  
  def index

    # Discard session
    if params[:clear].to_i == 1 then
      discard_session
    end

    # Restore session
    restore_params_from_session

    # Initialize params
    initialize_params

    # Store session
    store_params_to_session

    # Create array of display user IDs
    @user_id_array = []
    @user_id_array = @project.users.ids

    # Add Not Assigned
    @user_id_array << nil;

    # Hash for view
    @users_hash = {}
    @number_of_issues_hash = {}
    @start_date_hash = {}
    @due_date_hash = {}
    @total_estimated_hours_hash = {}
    @estimated_hours_today_hash = {}
    @total_spent_hours_hash = {}
    @earned_value_total_hash = {}
    @days_late_hash = {}
    @total_due_date_hash = {}
    @estimated_completion_date_hash = {}

    today = Time.now
    @today_date = today.strftime("%Y-%m-%d")
    
    if !@version.nil? then
      @workdays_left = @version.due_date.nil? ? "-" : get_workdays(today, @version.due_date)
    end

    # Users loop
    @user_id_array.each {|user_id|
      
      # Get all issues belongs to this version by user
      issues = Issue.where(assigned_to_id: user_id)
        .where(project_id: @project.id)
        .where(fixed_version_id: @version_id)
        .where(is_private: 0)
      
      # Reset counter
      earned_value_total = 0.0
      total_estimated_hours = 0.0
      total_spent_hours = 0.0

      # Earned value and other summary values
      issues.each {|issue|
        earned_value_total += (issue.estimated_hours || 0.0).to_f * (issue.done_ratio.to_f || 0) / 100.0
        total_estimated_hours += (issue.estimated_hours || 0.0).to_f
        total_spent_hours += (issue.spent_hours || 0.0).to_f
      }

      # Start and end date within the version
      real_start_date = issues.minimum('start_date')
      real_due_date = issues.maximum('due_date')

      # This is my unique definition for start date
      if real_start_date.nil? then
        real_start_date = today
      end

      # This is my unique definition for due date
      if real_due_date.nil? then
        nessesary_days = (total_estimated_hours / ChakuchiConstants::WORKING_HOURS_PER_DAY).ceil # Round up
        real_due_date = add_days_in_weekday(real_start_date, nessesary_days)
      end

      # Count workdays and calc. schedule progress rate (from 0.0@start_date to 1.0@due_date)
      if today <= real_start_date then
        schedule_progress_rate = 0.0
      elsif real_due_date <= today then
        schedule_progress_rate = 1.0
      elsif real_start_date < today && today < real_due_date then
        @workdays_total = get_workdays(real_start_date, real_due_date)
        @workdays_to_today = get_workdays(real_start_date, today)
        schedule_progress_rate = @workdays_to_today.to_f / @workdays_total.to_f
      else
        # can not in
        schedule_progress_rate = 0.0
      end

      # days_left > 0 is indicated schedule is delay
      estimated_hours_today = total_estimated_hours * schedule_progress_rate
      days_left = (estimated_hours_today - earned_value_total) / ChakuchiConstants::WORKING_HOURS_PER_DAY
      days_left = days_left.ceil # Round up

      # Estimated Completion Date
      if (total_estimated_hours - earned_value_total) <= 0 then
        # Already completed
        estimated_completion_date = "-"
      else
        if real_due_date.nil? then
          if real_start_date.nil? then
            estimated_completion_date = "-"
          else
            correct_days_left = days_left - (total_spent_hours / ChakuchiConstants::WORKING_HOURS_PER_DAY).ceil # Round up
            estimated_completion_date = add_days_in_weekday(real_start_date, correct_days_left).strftime("%Y-%m-%d")
          end
        else
          estimated_completion_date = add_days_in_weekday(real_due_date, days_left).strftime("%Y-%m-%d")
        end
      end

      # Store values for view
      @users_hash[user_id] = user_id.nil? ? nil : User.find(user_id)
      @number_of_issues_hash[user_id] = issues.nil? ? 0 : issues.length
      @start_date_hash[user_id] = real_start_date.nil? ? "-" : real_start_date.strftime("%Y-%m-%d")
      @due_date_hash[user_id] = real_due_date.nil? ? "-" : real_due_date.strftime("%Y-%m-%d")
      @total_estimated_hours_hash[user_id] = total_estimated_hours
      @estimated_hours_today_hash[user_id] = estimated_hours_today
      @total_spent_hours_hash[user_id] = total_spent_hours
      @earned_value_total_hash[user_id] = earned_value_total
      @days_late_hash[user_id] = days_left
      @total_due_date_hash[user_id] = real_due_date.nil? ? "-" : real_due_date.strftime("%Y-%m-%d")
      @estimated_completion_date_hash[user_id] = estimated_completion_date
    } # End of users loop

  end
  
  private
  #
  # Count workdays
  #
  def get_workdays(date_from, date_to)
    # Reverse
    if date_from > date_to then
      swap = date_from
      date_to = date_from
      date_to = swap
    end
    # Counter
    workdays = 0
    t = date_from
    while true do
      if t.saturday? || t.sunday? then
        # nothing to do
      else
        workdays += 1
      end      
      t += 1.days
      if t.strftime("%Y-%m-%d") >= date_to.strftime("%Y-%m-%d") then
        break
      end
    end
    return workdays == 0 ? 1 : workdays
  end

  #
  # Get date before/after n days except sat. & sun.
  #
  def add_days_in_weekday(ref_date, diff)
    # on schedule
    if diff == 0 then
      return ref_date
    end
    count = 0
    t = ref_date
    # when progress
    if diff < 0 then
      while true do
        if count == diff then
          break
        end
        t -= 1.days
        if t.saturday? || t.sunday? then
          # nothing to do
        else
          count -= 1
        end
      end
    end
    # when delay
    if diff > 0 then
      while true do
        if count == diff then
          break
        end
        t += 1.days
        if t.saturday? || t.sunday? then
          # nothing to do
        else
          count += 1
        end
      end
    end
    return t
  end

  #
  # Discard session
  #
  def discard_session
    session[:chakuchi] = nil
  end

  #
  # Store session
  #
  def store_params_to_session
    session_hash = {}
    session_hash["project_id"] = @project_id
    session_hash["version_id"] = @version_id
    session[:chakuchi] = session_hash
  end

  #
  # Restore session
  #
  def restore_params_from_session
    session_hash = session[:chakuchi]
    
    # Display version ID
    if !session_hash.blank? && params[:version_id].blank?
      @version_id = session_hash["version_id"]
    else
      @version_id = params[:version_id]
    end

    # If chenge project then reset version
    if !session_hash.blank? && !params[:project_id].blank?
      if session_hash["project_id"] != params[:project_id] then
        @version_id = nil
      end
    end
  end

  #
  # Initialize params
  #
  def initialize_params
    @project_id = params[:project_id]

    # Get current project
    @project = Project.find(@project_id)

    # Display version ID
    if @version_id.nil? || @version_id == "" then
      # no selection
      @version_id = ""
      @version = nil
    else
      # selected version
      @version = Version.find(@version_id)
    end
  end

  #
  # User logged in
  #
  def set_user
    @current_user ||= User.current
  end

  #
  # Need Login
  #
  def global_authorize
    set_user
    render_403 unless @current_user.type == 'User'
  end

end

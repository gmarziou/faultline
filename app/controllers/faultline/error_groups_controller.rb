# frozen_string_literal: true

module Faultline
  class ErrorGroupsController < ApplicationController
    before_action :set_error_group, only: [:show, :resolve, :unresolve, :ignore, :destroy, :create_github_issue]

    PER_PAGE = 25

    def index
      @error_groups = ErrorGroup.recent

      # Status filtering
      if params[:status].present?
        @error_groups = @error_groups.where(status: params[:status])
      end

      # Exception class filtering
      if params[:exception_class].present?
        @error_groups = @error_groups.where(exception_class: params[:exception_class])
      end

      # Full-text search with prefix matching
      @error_groups = @error_groups.search(params[:q])

      # Sorting
      case params[:sort]
      when "frequent"
        @error_groups = @error_groups.reorder(occurrences_count: :desc)
      when "oldest"
        @error_groups = @error_groups.reorder(first_seen_at: :asc)
      when "newest"
        @error_groups = @error_groups.reorder(first_seen_at: :desc)
      else
        @error_groups = @error_groups.reorder(last_seen_at: :desc)
      end

      # Simple pagination
      @page = (params[:page] || 1).to_i
      @total_count = @error_groups.count
      @total_pages = (@total_count.to_f / PER_PAGE).ceil
      @error_groups = @error_groups.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)

      # Sidebar stats
      @status_counts = ErrorGroup.group(:status).count
      @exception_classes = ErrorGroup.distinct.pluck(:exception_class).sort

      # Summary stats
      @occurrences_today = ErrorOccurrence.where("created_at >= ?", Time.current.beginning_of_day).count
      @occurrences_this_week = ErrorOccurrence.where("created_at >= ?", 7.days.ago).count

      # Chart data
      @chart_period = params[:chart_period].presence || "all"
      @chart_data = ErrorOccurrence.occurrences_over_time(period: @chart_period)
    end

    def show
      @page = (params[:page] || 1).to_i
      @total_count = @error_group.error_occurrences.count
      @total_pages = (@total_count.to_f / 20).ceil
      @occurrences = @error_group.error_occurrences.recent.offset((@page - 1) * 20).limit(20)
      @period = params[:period].presence || "all"

      if params[:zoom_start].present? && params[:zoom_end].present?
        @zoom_start = Time.zone.parse(params[:zoom_start])
        @zoom_end = Time.zone.parse(params[:zoom_end])
        @chart_data = @error_group.occurrences_in_range(start_time: @zoom_start, end_time: @zoom_end)
        @zoomed = true
      else
        @chart_data = @error_group.occurrences_over_time(period: @period)
        @zoomed = false
      end
    end

    def resolve
      @error_group.resolve!
      redirect_back fallback_location: error_groups_path, notice: "Error marked as resolved"
    end

    def unresolve
      @error_group.unresolve!
      redirect_back fallback_location: error_groups_path, notice: "Error marked as unresolved"
    end

    def ignore
      @error_group.ignore!
      redirect_back fallback_location: error_groups_path, notice: "Error ignored"
    end

    def destroy
      @error_group.destroy
      redirect_to error_groups_path, notice: "Error group deleted"
    end

    def create_github_issue
      unless Faultline.configuration.github_configured?
        return redirect_back fallback_location: error_group_path(@error_group),
                            alert: "GitHub integration not configured"
      end

      occurrence = @error_group.error_occurrences.order(created_at: :desc).first

      result = GithubIssueCreator.new(
        error_group: @error_group,
        error_occurrence: occurrence
      ).create

      if result[:success]
        redirect_back fallback_location: error_group_path(@error_group),
                      notice: "GitHub issue created: ##{result[:issue_number]}"
      else
        redirect_back fallback_location: error_group_path(@error_group),
                      alert: result[:error]
      end
    end

    def bulk_action
      ids = Array(params[:error_group_ids])
      action = params[:bulk_action]

      return redirect_to error_groups_path, alert: "No errors selected" if ids.empty?

      error_groups = ErrorGroup.where(id: ids)

      case action
      when "resolve"
        error_groups.update_all(status: "resolved", resolved_at: Time.current, updated_at: Time.current)
        notice = "#{error_groups.count} errors marked as resolved"
      when "unresolve"
        error_groups.update_all(status: "unresolved", resolved_at: nil, updated_at: Time.current)
        notice = "#{error_groups.count} errors marked as unresolved"
      when "ignore"
        error_groups.update_all(status: "ignored", updated_at: Time.current)
        notice = "#{error_groups.count} errors ignored"
      when "delete"
        count = error_groups.count
        error_groups.destroy_all
        notice = "#{count} errors deleted"
      else
        return redirect_to error_groups_path, alert: "Unknown action"
      end

      redirect_to error_groups_path, notice: notice
    end

    private

    def set_error_group
      @error_group = ErrorGroup.find(params[:id])
    end
  end
end

class DashboardController < ApplicationController
  def index
    @employee = current_employee
    @employee_id = current_employee_id
    @is_owner = owner?
  end
end

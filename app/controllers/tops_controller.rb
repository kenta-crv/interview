class TopsController < ApplicationController

  def interview
    @situations = Situation.where(archived: false).order(:title)
  end
  private

end

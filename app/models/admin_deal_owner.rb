# Admin管理商談で client が未紐付けのときのプラン相当の振る舞い
class AdminDealOwner
  DEFAULT_EMAIL = "info@okey.work".freeze

  def email
    Admin.order(:id).pick(:email).presence || DEFAULT_EMAIL
  end

  def situations
    Situation.none
  end

  def on_trial?
    false
  end

  def prospect_follow_up_enabled?
    true
  end

  def click_analytics_enabled?
    true
  end

  def faq_required_for_publish?
    false
  end

  def show_knowledge_coverage?
    true
  end

  def gap_analysis_suggest_only?
    false
  end

  def gap_analysis_question_limit
    8
  end

  def stress_test_question_limit
    8
  end

  def knowledge_tools_full?
    true
  end

  def knowledge_section_optional?
    false
  end
end

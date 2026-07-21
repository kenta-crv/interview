module TopsHelper
  HERO_FEATURE_CARDS = [
    ["fa-chart-line", "AI予測分析", "商談結果から最適な提案を自動生成"],
    ["fa-bullseye", "最適アプローチ提案", "顧客属性に合わせた営業戦略を提示"],
    ["fa-chart-column", "リアルタイム分析", "商談中の関心度をその場で可視化"],
    ["fa-list-check", "自動タスク生成", "フォローアップを見逃さず自動化"],
    ["fa-shield-halved", "セキュアな環境", "企業向けセキュリティ基準に準拠"]
  ].freeze

  HERO_FEATURE_CARDS_EN = [
    ["fa-chart-line", "AI forecasting", "Auto-generate next-best proposals from deal outcomes"],
    ["fa-bullseye", "Best-fit approach", "Sales strategy tailored to each buyer profile"],
    ["fa-chart-column", "Live analytics", "See interest signals during the conversation"],
    ["fa-list-check", "Auto tasking", "Never miss follow-ups — automate them"],
    ["fa-shield-halved", "Secure by design", "Built for enterprise security expectations"]
  ].freeze

  LP_NAV_ITEMS = [
    { key: "whats", label: "Meetiaとは", href: "#whats" },
    { key: "service", label: "サービス", href: "#service" },
    { key: "features", label: "機能", href: "#features" },
    { key: "pricing", label: "料金", href: "#pricing" },
    { key: "reviews", label: "レビュー", href: "#reviews" },
    { key: "faq", label: "FAQ", href: "#faq" },
    { key: "company", label: "会社概要", href: "#company" },
    { key: "columns", label: "お役立ち記事", href: "/columns" }
  ].freeze

  LP_NAV_ITEMS_EN = [
    { key: "whats", label: "About", href: "#whats" },
    { key: "service", label: "Service", href: "#service" },
    { key: "features", label: "Features", href: "#features" },
    { key: "pricing", label: "Pricing", href: "#pricing" },
    { key: "reviews", label: "Reviews", href: "#reviews" },
    { key: "faq", label: "FAQ", href: "#faq" },
    { key: "company", label: "Company", href: "#company" },
    { key: "columns", label: "Articles", href: "/columns" }
  ].freeze

  FEATURED_COLUMNS = [
    { title: "AI商談が変える営業スタイルの未来", path: "/columns/ai-sales-negotiation-future" },
    { title: "営業代行におけるAIツールの選び方と活用法", path: "/columns/ai-sales-outsourcing-tool-selection" },
    { title: "AI営業の成功事例：営業代行での実践的なアプローチ", path: "/columns/ai-sales-success-case-study" },
    { title: "AI商談がもたらす営業の効率化", path: "/columns/ai-sales-negotiation-efficiency" },
    { title: "Zoom営業からAI商談への移行ガイド", path: "/columns/zoom-sales-to-ai-negotiation-guide" }
  ].freeze

  FEATURED_COLUMNS_EN = [
    { title: "How AI deal rooms reshape modern sales", path: "/columns/ai-sales-negotiation-future" },
    { title: "Choosing AI tools for outsourced sales teams", path: "/columns/ai-sales-outsourcing-tool-selection" },
    { title: "AI sales success stories in practice", path: "/columns/ai-sales-success-case-study" },
    { title: "Efficiency gains from AI-led conversations", path: "/columns/ai-sales-negotiation-efficiency" },
    { title: "From Zoom sales to AI deal rooms", path: "/columns/zoom-sales-to-ai-negotiation-guide" }
  ].freeze

  FEATURE_TABS = [
    %w[docs 資料解析],
    %w[voice 音声商談],
    %w[analytics 分析],
    %w[follow フォロー]
  ].freeze

  FEATURE_TABS_EN = [
    %w[docs Documents],
    %w[voice Voice deals],
    %w[analytics Analytics],
    %w[follow Follow-up]
  ].freeze

  FEATURE_ROWS = [
    ["01", "fa-file-lines", "資料解析・AI学習", "高精度での解析により、商品の特徴を正確に把握。アップロードした資料をAIが深く理解し、商談に活用します。", %w[PDF/PPTX対応 FAQ自動抽出 台本自動生成]],
    ["02", "fa-microphone-lines", "台本自動生成・音声化", "AIが最適な台本を生成し、自然な音声合成で自動対話を実現。人的な営業トークを再現します。", %w[リアルタイム音声 アバター案内 双方向FAQ]],
    ["03", "fa-door-open", "24時間AI商談ルーム", "待機時間ゼロ。24時間365日、いつでも商談可能なAIルームを提供します。", %w[URL共有のみ 深夜・休日対応 即時入室]],
    ["04", "fa-comments", "リアルタイムFAQ対話", "社内FAQを活用し、顧客の質問にリアルタイムで回答。双方向の対話で疑問をその場で解消します。", %w[BANT抽出 操作ログ リード管理]],
    ["05", "fa-chart-line", "見込み度・離脱分析", "商談中の顧客の関心度をスコアリングし、離脱ポイントを分析。データに基づいた改善提案を行います。", %w[離脱分析 関心スライド A〜D判定]],
    ["06", "fa-envelope", "フォローメール自動配信", "商談後のフォローアップを自動化。パーソナライズされたメールを最適なタイミングで配信します。", %w[自動配信 開封追跡 見送り管理]]
  ].freeze

  FEATURE_ROWS_EN = [
    ["01", "fa-file-lines", "Document parsing & AI learning", "High-accuracy parsing captures product strengths. AI deeply understands uploaded materials and uses them in every deal.", ["PDF/PPTX", "Auto FAQ extraction", "Script generation"]],
    ["02", "fa-microphone-lines", "Scripting & voice synthesis", "AI writes the best script and speaks naturally — recreating strong human sales talk.", ["Real-time voice", "Avatar guidance", "Two-way FAQ"]],
    ["03", "fa-door-open", "24/7 AI deal room", "Zero wait time. Share a room that is always open for buyers.", ["URL only", "Nights & weekends", "Instant join"]],
    ["04", "fa-comments", "Live FAQ dialogue", "Answer buyer questions in real time with your internal FAQ — clear doubts on the spot.", ["BANT capture", "Action logs", "Lead management"]],
    ["05", "fa-chart-line", "Intent & drop-off analysis", "Score interest during the session and analyze where buyers leave — then improve with data.", ["Drop-off insights", "Interest slides", "A–D grading"]],
    ["06", "fa-envelope", "Automated follow-up email", "Personal follow-ups at the right time, with open and click tracking.", ["Auto send", "Open tracking", "Nurture control"]]
  ].freeze

  FAQ_ITEMS = [
    { category: "service", q: "資料をアップロードするだけで、本当に適切な商談ができますか？", a: "はい、可能です。PDFやドキュメントから自社の強みや製品仕様を正確に抽出し、ユーザーの個別の質問に合わせて回答・音声化を行います。" },
    { category: "pricing", q: "無料トライアルの期間は？", a: "#{Subscription::TRIAL_DAYS}日間の無料トライアルをご用意しています。クレジットカード登録後、すぐに商談ルームを作成できます。" },
    { category: "service", q: "既存の営業資料は使えますか？", a: "PDF形式の営業資料・FAQ・料金表などをそのままアップロードして利用できます。" },
    { category: "security", q: "セキュリティ対策は？", a: "通信の暗号化、アクセス制御、データの適切な管理を行い、企業向けのセキュリティ要件に対応しています。" },
    { category: "setup", q: "導入までどのくらいかかりますか？", a: "資料をアップロードすれば、数時間以内にAI処理が完了し、商談ルームURLを共有できます。" },
    { category: "service", q: "見込み度や離脱理由はどう可視化されますか？", a: "操作ログから関心スライド・離脱ポイントをAIが分析し、A〜Dランクの見込み度としてダッシュボードに表示します。" },
    { category: "support", q: "商談後のフォローアップは？", a: "検討時期に合わせたフォローメールを自動配信。開封・クリックも追跡できます。" },
    { category: "pricing", q: "プラン変更は可能ですか？", a: "管理画面からいつでもプランのアップグレード・ダウングレードが可能です。" }
  ].freeze

  FAQ_ITEMS_EN = [
    { category: "service", q: "Can uploading documents really create a solid sales conversation?", a: "Yes. Meetia extracts strengths and specs from PDFs/docs, then answers and speaks to each buyer’s questions." },
    { category: "pricing", q: "How long is the free trial?", a: "You get a #{Subscription::TRIAL_DAYS}-day free trial. After card registration you can create a deal room immediately." },
    { category: "service", q: "Can we use our existing sales materials?", a: "Yes — upload PDFs such as decks, FAQs, and pricing sheets as they are." },
    { category: "security", q: "What about security?", a: "Encryption, access control, and careful data handling support enterprise requirements." },
    { category: "setup", q: "How long until we can go live?", a: "After upload, AI processing usually finishes within hours and you can share the deal-room URL." },
    { category: "service", q: "How is intent and drop-off visualized?", a: "AI analyzes action logs, interest slides, and drop-off points, then shows A–D prospect grades on the dashboard." },
    { category: "support", q: "What about post-meeting follow-up?", a: "Timed follow-up emails are sent automatically, with open and click tracking." },
    { category: "pricing", q: "Can we change plans later?", a: "Yes. Upgrade or downgrade anytime from the admin dashboard." }
  ].freeze

  REVIEW_CARDS = [
    { meta: "IT・SaaSベンダー（マーケティング責任者）", title: "問い合わせ直後の離脱が激減。商談獲得コストが半減しました", quote: "「資料請求後に架電するまでにタイムラグがあり、競合に流れるケースが多くありました。Meetia導入後は、その場でAI商談が始まるため、熱量が最も高い状態を逃さず移行率が跳ね上がりました。」", metric: "+35% 商談化率" },
    { meta: "人材紹介・コンサルティング（営業取締役）", title: "営業負担がゼロになり、夜間・休日の取りこぼしが利益に", quote: "「深夜や休日のWebアクセスに対して、AIが完璧なヒアリングと初期提案を代行。月曜朝には見込み度の高い商談結果が管理画面に並んでいる状態は、これまでの営業の常識を覆す体験です。」", metric: "24h 対応実現" },
    { meta: "BtoB製造メーカー（営業部マネージャー）", title: "商談品質のばらつきが消え、成約率が安定しました", quote: "「担当者ごとのトーク力差が課題でしたが、Meetiaなら誰が対応しても同じレベルの提案が24時間提供されます。営業チームはクロージングと既存深耕に集中できるようになりました。」", metric: "+28% 成約率" },
    { meta: "HRテック企業（カスタマーサクセス責任者）", title: "資料請求後の初動が劇的に速くなり、リードが冷めません", quote: "「以前は営業が手空きになるまで待つことが多く、熱量の高い見込み客を逃していました。今は請求直後にAI商談が始まるため、フォローのタイミングに悩まなくなりました。」", metric: "初動対応 即時化" },
    { meta: "マーケティング支援会社（代表取締役）", title: "少人数でも商談対応を止めずに回せるようになりました", quote: "「少人数体制だと問い合わせが重なると対応が遅れがちでした。Meetia導入後はAIが一次対応を担い、人間は見込み度の高い案件だけに集中。チームの生産性そのものが変わりました。」", metric: "対応工数 -40%" }
  ].freeze

  REVIEW_CARDS_EN = [
    { meta: "IT / SaaS vendor (Marketing lead)", title: "Post-inquiry drop-off collapsed. Cost per meeting halved.", quote: "“We used to lose warm leads while waiting to call back. With Meetia, AI starts the conversation immediately — conversion jumped.”", metric: "+35% meetings" },
    { meta: "Recruiting / consulting (Sales director)", title: "Zero after-hours leakage — nights and weekends now convert", quote: "“AI handles night and weekend traffic with solid discovery. Monday mornings start with qualified deal results waiting.”", metric: "24/7 coverage" },
    { meta: "B2B manufacturer (Sales manager)", title: "Consistent quality — close rates stabilized", quote: "“Rep skill gaps used to hurt us. Meetia delivers the same high-quality pitch 24/7 so humans focus on closing.”", metric: "+28% close rate" },
    { meta: "HR tech (Customer success lead)", title: "First response is instant — leads stay warm", quote: "“We no longer wait for a free rep. AI engages right after the download.”", metric: "Instant first touch" },
    { meta: "Marketing agency (CEO)", title: "A small team can keep conversations moving", quote: "“AI takes first-line work; people only touch high-intent deals. Productivity changed overnight.”", metric: "-40% effort" }
  ].freeze

  PROBLEM_ITEMS = [
    { icon: "fa-clock", text: "資料請求後の架電までタイムラグがあり、<br>見込み客の熱量が冷めてしまう", desc: "問い合わせ直後が最も興味が高いのに、営業が対応できるまでに時間がかかり機会損失が発生している。" },
    { icon: "fa-moon", text: "夜間・休日の問い合わせに<br>対応できず取りこぼしている", desc: "Webからのアクセスは時間を選ばないのに、人的リソースでは24時間対応が難しく商談機会を逃している。" },
    { icon: "fa-users", text: "営業担当のスキル差で<br>商談品質にばらつきが出る", desc: "トーク力や資料説明の質が人によって異なり、チーム全体の成約率が安定しない。" },
    { icon: "fa-clipboard-list", text: "商談メモや分析が属人化し、<br>改善の打ち手が見えない", desc: "記録の粒度がバラバラで、見込み度や離脱理由をチームで共有・活用できていない。" },
    { icon: "fa-headset", text: "一次対応に工数がかかり、<br>クロージングに集中できない", desc: "ヒアリングや資料説明に時間が取られ、本来注力すべき案件への深掘りが後回しになっている。" },
    { icon: "fa-chart-line", text: "リードはあるのに<br>商談化率が伸び悩んでいる", desc: "流入は増えているが、初動対応とフォローの仕組みが弱く、成果につながらない。" }
  ].freeze

  PROBLEM_ITEMS_EN = [
    { icon: "fa-clock", text: "Callback lag after downloads<br>cools buyer interest", desc: "Interest peaks right after inquiry, but human response time creates lost opportunities." },
    { icon: "fa-moon", text: "Nights and weekends<br>go unanswered", desc: "Web traffic never sleeps — human coverage can’t match it." },
    { icon: "fa-users", text: "Rep skill gaps create<br>inconsistent deal quality", desc: "Pitch quality varies by person, so team close rates stay unstable." },
    { icon: "fa-clipboard-list", text: "Notes and analysis are siloed<br>so improvements stall", desc: "Uneven logging makes intent and drop-off hard to share and act on." },
    { icon: "fa-headset", text: "First-line work eats time<br>needed for closing", desc: "Discovery and deck walkthroughs crowd out high-value closing work." },
    { icon: "fa-chart-line", text: "Leads arrive, but<br>meeting conversion stalls", desc: "Traffic grows, yet weak first response and follow-up block results." }
  ].freeze

  SERVICE_CARDS = [
    { num: "01", icon: "fa-cloud-arrow-up", orbit: "fa-file-lines", title: "資料アップロード → AI学習", desc: "PDFやFAQをアップロードするだけ。AIが内容を読解し、商談台本とナレッジを生成します。" },
    { num: "02", icon: "fa-microphone-lines", orbit: "fa-comments", title: "AI商談ルームで音声対話", desc: "訪問者はURLから入室。資料を見せながらAIが音声で提案・ヒアリングを行います。" },
    { num: "03", icon: "fa-envelope-circle-check", orbit: "fa-chart-pie", title: "見込み度分析・フォロー自動化", desc: "商談ログから関心度を分析。見込み度判定とフォローメール配信まで自動で完結します。" }
  ].freeze

  SERVICE_CARDS_EN = [
    { num: "01", icon: "fa-cloud-arrow-up", orbit: "fa-file-lines", title: "Upload docs → AI learning", desc: "Upload PDFs and FAQs. AI reads them and builds scripts plus knowledge." },
    { num: "02", icon: "fa-microphone-lines", orbit: "fa-comments", title: "Voice dialogue in the deal room", desc: "Buyers join via URL. AI presents and discovers needs with voice." },
    { num: "03", icon: "fa-envelope-circle-check", orbit: "fa-chart-pie", title: "Intent scoring & follow-up automation", desc: "Analyze interest from logs, grade prospects, and send follow-ups automatically." }
  ].freeze

  COMPANY_PROFILE = [
    ["会社名", "株式会社J Work"],
    ["代表取締役", "奥山　健太"],
    ["設立", "2023年8月22日"],
    ["資本金", "5,000,000円"],
    ["所在地", "東京都港区浜松町２丁目２番１５号２Ｆ"],
    ["事業内容", "AI商談代行サービス「Meetia」の開発・提供"]
  ].freeze

  COMPANY_PROFILE_EN = [
    ["Company", "J Work Inc."],
    ["CEO", "Kenta Okuyama"],
    ["Founded", "August 22, 2023"],
    ["Capital", "JPY 5,000,000"],
    ["Address", "2F, 2-2-15 Hamamatsucho, Minato-ku, Tokyo"],
    ["Business", "Development and delivery of Meetia, an AI sales agent"]
  ].freeze

  COMPANY_STATS = [
    { icon: "fa-calendar", label: "サービス開始", num: "2024", unit: "年" },
    { icon: "fa-building", label: "導入企業", num: "1,200", unit: "+社" },
    { icon: "fa-clock", label: "対応体制", num: "24", unit: "時間" }
  ].freeze

  COMPANY_STATS_EN = [
    { icon: "fa-calendar", label: "Launched", num: "2024", unit: "" },
    { icon: "fa-building", label: "Customers", num: "1,200", unit: "+" },
    { icon: "fa-clock", label: "Coverage", num: "24", unit: "h" }
  ].freeze

  COMPARE_ROWS = [
    { label: "初回対応", icon: "fa-bolt", legacy: "資料請求後に架電までタイムラグ", meetia: "アクセス直後にAI商談開始" },
    { label: "対応時間", icon: "fa-clock", legacy: "営業担当の稼働時間に依存", meetia: "24時間365日対応" },
    { label: "分析・記録", icon: "fa-chart-line", legacy: "議事録・分析が属人化", meetia: "ログ・見込み度を自動可視化" }
  ].freeze

  COMPARE_ROWS_EN = [
    { label: "First response", icon: "fa-bolt", legacy: "Lag between download and callback", meetia: "AI conversation starts on access" },
    { label: "Availability", icon: "fa-clock", legacy: "Limited to rep working hours", meetia: "24/7/365 coverage" },
    { label: "Analytics", icon: "fa-chart-line", legacy: "Notes and analysis stay siloed", meetia: "Logs and intent scored automatically" }
  ].freeze

  FAQ_CATEGORIES = [
    ["service", "サービスについて", "fa-comments"],
    ["pricing", "料金", "fa-yen-sign"],
    ["setup", "導入", "fa-rocket"],
    ["security", "セキュリティ", "fa-shield-halved"],
    ["support", "サポート", "fa-headset"]
  ].freeze

  FAQ_CATEGORIES_EN = [
    ["service", "Service", "fa-comments"],
    ["pricing", "Pricing", "fa-yen-sign"],
    ["setup", "Setup", "fa-rocket"],
    ["security", "Security", "fa-shield-halved"],
    ["support", "Support", "fa-headset"]
  ].freeze

  TRIAL_FEATURES = [
    { icon: "fa-rocket", label: "即日スタート", desc: "資料をアップロードするだけで、すぐにAI商談ルームを体験できます。" },
    { icon: "fa-shield-halved", label: "セキュア設計", desc: "通信暗号化とアクセス制御で、企業利用にも安心の環境を提供します。" },
    { icon: "fa-chart-simple", label: "成果を可視化", desc: "見込み度判定や商談ログをダッシュボードで確認できます。" }
  ].freeze

  TRIAL_FEATURES_EN = [
    { icon: "fa-rocket", label: "Start today", desc: "Upload materials and try an AI deal room right away." },
    { icon: "fa-shield-halved", label: "Secure design", desc: "Encryption and access controls for business use." },
    { icon: "fa-chart-simple", label: "Visible results", desc: "Review intent grades and session logs on the dashboard." }
  ].freeze

  def lp_english?
    I18n.locale.to_s == "en"
  end

  def lp_nav_items
    lp_english? ? LP_NAV_ITEMS_EN : LP_NAV_ITEMS
  end

  def hero_feature_cards
    lp_english? ? HERO_FEATURE_CARDS_EN : HERO_FEATURE_CARDS
  end

  def featured_columns_for_lp
    lp_english? ? FEATURED_COLUMNS_EN : FEATURED_COLUMNS
  end

  def feature_tabs
    lp_english? ? FEATURE_TABS_EN : FEATURE_TABS
  end

  def feature_rows
    lp_english? ? FEATURE_ROWS_EN : FEATURE_ROWS
  end

  def faq_items
    lp_english? ? FAQ_ITEMS_EN : FAQ_ITEMS
  end

  def review_cards
    lp_english? ? REVIEW_CARDS_EN : REVIEW_CARDS
  end

  def problem_items
    lp_english? ? PROBLEM_ITEMS_EN : PROBLEM_ITEMS
  end

  def service_cards
    lp_english? ? SERVICE_CARDS_EN : SERVICE_CARDS
  end

  def company_profile_rows
    lp_english? ? COMPANY_PROFILE_EN : COMPANY_PROFILE
  end

  def company_stats
    lp_english? ? COMPANY_STATS_EN : COMPANY_STATS
  end

  def compare_rows
    lp_english? ? COMPARE_ROWS_EN : COMPARE_ROWS
  end

  def faq_categories
    lp_english? ? FAQ_CATEGORIES_EN : FAQ_CATEGORIES
  end

  def trial_features
    lp_english? ? TRIAL_FEATURES_EN : TRIAL_FEATURES
  end

  def lp_nav_active?(key)
    @lp_page == key.to_s
  end

  def lp_sign_up_path
    new_client_registration_path
  end

  def lp_trial_experience_path
    if client_signed_in? || admin_signed_in? || user_signed_in?
      lp_login_path
    else
      new_client_registration_path
    end
  end

  def lp_trial_experience_link_options
    { target: "_blank", rel: "noopener noreferrer" }
  end

  def lp_login_path
    if client_signed_in?
      dashboard_root_path
    elsif admin_signed_in?
      dashboard_root_path
    elsif user_signed_in?
      interview_path
    else
      new_client_session_path
    end
  end

  def lp_login_label
    if client_signed_in? || admin_signed_in? || user_signed_in?
      I18n.t("meetia.lp.mypage")
    else
      I18n.t("meetia.lp.login")
    end
  end
end

module TopsHelper
  HERO_FEATURE_CARDS = [
    ["fa-chart-line", "AI予測分析", "商談結果から最適な提案を自動生成"],
    ["fa-bullseye", "最適アプローチ提案", "顧客属性に合わせた営業戦略を提示"],
    ["fa-chart-column", "リアルタイム分析", "商談中の関心度をその場で可視化"],
    ["fa-list-check", "自動タスク生成", "フォローアップを見逃さず自動化"],
    ["fa-shield-halved", "セキュアな環境", "企業向けセキュリティ基準に準拠"]
  ].freeze

  LP_NAV_ITEMS = [
    { key: "whats", label: "Meetiaとは", href: "#whats" },
    { key: "service", label: "サービス", href: "#service" },
    { key: "features", label: "機能", href: "#features" },
    { key: "pricing", label: "料金", href: "#pricing" },
    { key: "reviews", label: "レビュー", href: "#reviews" },
    { key: "faq", label: "FAQ", href: "#faq" },
    { key: "company", label: "会社概要", href: "#company" }
  ].freeze

  FEATURE_TABS = [
    %w[docs 資料解析],
    %w[voice 音声商談],
    %w[analytics 分析],
    %w[follow フォロー]
  ].freeze

  FEATURE_ROWS = [
    ["01", "fa-file-lines", "資料解析・AI学習", "高精度での解析により、商品の特徴を正確に把握。アップロードした資料をAIが深く理解し、商談に活用します。", %w[PDF/PPTX対応 FAQ自動抽出 台本自動生成]],
    ["02", "fa-microphone-lines", "台本自動生成・音声化", "AIが最適な台本を生成し、自然な音声合成で自動対話を実現。人的な営業トークを再現します。", %w[リアルタイム音声 アバター案内 双方向FAQ]],
    ["03", "fa-door-open", "24時間AI商談ルーム", "待機時間ゼロ。24時間365日、いつでも商談可能なAIルームを提供します。", %w[URL共有のみ 深夜・休日対応 即時入室]],
    ["04", "fa-comments", "リアルタイムFAQ対話", "社内FAQを活用し、顧客の質問にリアルタイムで回答。双方向の対話で疑問をその場で解消します。", %w[BANT抽出 操作ログ リード管理]],
    ["05", "fa-chart-line", "見込み度・離脱分析", "商談中の顧客の関心度をスコアリングし、離脱ポイントを分析。データに基づいた改善提案を行います。", %w[離脱分析 関心スライド A〜D判定]],
    ["06", "fa-envelope", "フォローメール自動配信", "商談後のフォローアップを自動化。パーソナライズされたメールを最適なタイミングで配信します。", %w[自動配信 開封追跡 見送り管理]]
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

  REVIEW_CARDS = [
    { meta: "IT・SaaSベンダー（マーケティング責任者）", title: "問い合わせ直後の離脱が激減。商談獲得コストが半減しました", quote: "「資料請求後に架電するまでにタイムラグがあり、競合に流れるケースが多くありました。Meetia導入後は、その場でAI商談が始まるため、熱量が最も高い状態を逃さず移行率が跳ね上がりました。」", metric: "+35% 商談化率" },
    { meta: "人材紹介・コンサルティング（営業取締役）", title: "営業負担がゼロになり、夜間・休日の取りこぼしが利益に", quote: "「深夜や休日のWebアクセスに対して、AIが完璧なヒアリングと初期提案を代行。月曜朝には見込み度の高い商談結果が管理画面に並んでいる状態は、これまでの営業の常識を覆す体験です。」", metric: "24h 対応実現" },
    { meta: "BtoB製造メーカー（営業部マネージャー）", title: "商談品質のばらつきが消え、成約率が安定しました", quote: "「担当者ごとのトーク力差が課題でしたが、Meetiaなら誰が対応しても同じレベルの提案が24時間提供されます。営業チームはクロージングと既存深耕に集中できるようになりました。」", metric: "+28% 成約率" },
    { meta: "HRテック企業（カスタマーサクセス責任者）", title: "資料請求後の初動が劇的に速くなり、リードが冷めません", quote: "「以前は営業が手空きになるまで待つことが多く、熱量の高い見込み客を逃していました。今は請求直後にAI商談が始まるため、フォローのタイミングに悩まなくなりました。」", metric: "初動対応 即時化" },
    { meta: "マーケティング支援会社（代表取締役）", title: "少人数でも商談対応を止めずに回せるようになりました", quote: "「少人数体制だと問い合わせが重なると対応が遅れがちでした。Meetia導入後はAIが一次対応を担い、人間は見込み度の高い案件だけに集中。チームの生産性そのものが変わりました。」", metric: "対応工数 -40%" }
  ].freeze

  PROBLEM_ITEMS = [
    { icon: "fa-clock", text: "資料請求後の架電までタイムラグがあり、<br>見込み客の熱量が冷めてしまう", desc: "問い合わせ直後が最も興味が高いのに、営業が対応できるまでに時間がかかり機会損失が発生している。" },
    { icon: "fa-moon", text: "夜間・休日の問い合わせに<br>対応できず取りこぼしている", desc: "Webからのアクセスは時間を選ばないのに、人的リソースでは24時間対応が難しく商談機会を逃している。" },
    { icon: "fa-users", text: "営業担当のスキル差で<br>商談品質にばらつきが出る", desc: "トーク力や資料説明の質が人によって異なり、チーム全体の成約率が安定しない。" },
    { icon: "fa-clipboard-list", text: "商談メモや分析が属人化し、<br>改善の打ち手が見えない", desc: "記録の粒度がバラバラで、見込み度や離脱理由をチームで共有・活用できていない。" },
    { icon: "fa-headset", text: "一次対応に工数がかかり、<br>クロージングに集中できない", desc: "ヒアリングや資料説明に時間が取られ、本来注力すべき案件への深掘りが後回しになっている。" },
    { icon: "fa-chart-line", text: "リードはあるのに<br>商談化率が伸び悩んでいる", desc: "流入は増えているが、初動対応とフォローの仕組みが弱く、成果につながらない。" }
  ].freeze

  SERVICE_CARDS = [
    { num: "01", icon: "fa-cloud-arrow-up", orbit: "fa-file-lines", title: "資料アップロード → AI学習", desc: "PDFやFAQをアップロードするだけ。AIが内容を読解し、商談台本とナレッジを生成します。" },
    { num: "02", icon: "fa-microphone-lines", orbit: "fa-comments", title: "AI商談ルームで音声対話", desc: "訪問者はURLから入室。資料を見せながらAIが音声で提案・ヒアリングを行います。" },
    { num: "03", icon: "fa-envelope-circle-check", orbit: "fa-chart-pie", title: "見込み度分析・フォロー自動化", desc: "商談ログから関心度を分析。見込み度判定とフォローメール配信まで自動で完結します。" }
  ].freeze

  COMPANY_PROFILE = [
    ["会社名", "Meetia株式会社"],
    ["設立", "2024年"],
    ["所在地", "東京都渋谷区"],
    ["代表取締役", "代表取締役 CEO"],
    ["資本金", "1億円"],
    ["事業内容", "AI商談代行サービス「Meetia」の開発・提供"]
  ].freeze

  COMPANY_STATS = [
    { icon: "fa-calendar", label: "サービス開始", num: "2024", unit: "年" },
    { icon: "fa-building", label: "導入企業", num: "1,200", unit: "+社" },
    { icon: "fa-clock", label: "対応体制", num: "24", unit: "時間" }
  ].freeze

  COMPARE_ROWS = [
    { label: "初回対応", icon: "fa-bolt", legacy: "資料請求後に架電までタイムラグ", meetia: "アクセス直後にAI商談開始" },
    { label: "対応時間", icon: "fa-clock", legacy: "営業担当の稼働時間に依存", meetia: "24時間365日対応" },
    { label: "分析・記録", icon: "fa-chart-line", legacy: "議事録・分析が属人化", meetia: "ログ・見込み度を自動可視化" }
  ].freeze

  FAQ_CATEGORIES = [
    ["service", "サービスについて", "fa-comments"],
    ["pricing", "料金", "fa-yen-sign"],
    ["setup", "導入", "fa-rocket"],
    ["security", "セキュリティ", "fa-shield-halved"],
    ["support", "サポート", "fa-headset"]
  ].freeze

  TRIAL_FEATURES = [
    { icon: "fa-rocket", label: "即日スタート", desc: "資料をアップロードするだけで、すぐにAI商談ルームを体験できます。" },
    { icon: "fa-shield-halved", label: "セキュア設計", desc: "通信暗号化とアクセス制御で、企業利用にも安心の環境を提供します。" },
    { icon: "fa-chart-simple", label: "成果を可視化", desc: "見込み度判定や商談ログをダッシュボードで確認できます。" }
  ].freeze

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
      "マイページ"
    else
      "ログイン"
    end
  end
end

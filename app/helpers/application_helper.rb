module ApplicationHelper
  def default_meta_tags
    {
      site: "Meetia",
      title: "AI商談代行サービス",
      description: "資料アップロードだけで24時間365日、AIが音声商談を代行。商談結果の分析・見込み度判定・自動フォローまで一気通貫で営業工数を削減します。",
      canonical: request.original_url,
      charset: "UTF-8",
      reverse: true,
      separator: '|',
      icon: [
        { href: image_path('favicon.ico') },
        { href: image_path('favicon.ico'), rel: 'apple-touch-icon' },
      ],
    }
  end

end

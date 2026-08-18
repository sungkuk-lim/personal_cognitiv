/* 모담넷 웹 이용 가이드 — 앱 설정 언어(?lang=)에 맞춰 표시합니다. */
(function (global) {
  var LANGS = [
    { id: "ko", label: "한국어" },
    { id: "en", label: "English" },
    { id: "ja", label: "日本語" },
    { id: "zh-Hans", label: "简体中文" },
    { id: "zh-Hant", label: "繁體中文" },
    { id: "es", label: "Español" },
    { id: "fr", label: "Français" },
    { id: "de", label: "Deutsch" },
    { id: "pt-BR", label: "Português" },
    { id: "vi", label: "Tiếng Việt" },
  ];

  function norm(lang) {
    if (!lang) return "ko";
    var s = String(lang).replace("_", "-");
    if (s === "zh") return "zh-Hans";
    if (s === "pt") return "pt-BR";
    var ids = LANGS.map(function (l) { return l.id; });
    if (ids.indexOf(s) >= 0) return s;
    var base = s.split("-")[0];
    if (ids.indexOf(base) >= 0) return base;
    return "en";
  }

  var T = {
    en: {
      title: "Modamnet (MemoryOS) user guide",
      h1: "Modamnet (MemoryOS)<br>User guide",
      tagline: "From saving memories to the graph, recall, and settings",
      badge: "Version 1.0.29 · August 2026",
      nav: ["Contents", "Start", "Timeline", "Search", "Graph", "Recall", "Memory film", "Settings", "Free · Pro", "FAQ", "Privacy", "Terms"],
    },
    ja: {
      title: "モダムネット(MemoryOS) ユーザーガイド",
      h1: "モダムネット(MemoryOS)<br>使い方ガイド",
      tagline: "記憶の保存から関係網・想起・設定まで",
      badge: "バージョン 1.0.29 · 2026年8月",
      nav: ["目次", "開始", "タイムライン", "検索", "関係網", "想起", "記憶フィルム", "設定", "無料・Pro", "FAQ", "プライバシー", "利用規約"],
    },
    "zh-Hans": {
      title: "模谈网 (MemoryOS) 使用指南",
      h1: "模谈网 (MemoryOS)<br>使用指南",
      tagline: "从保存记忆到关系网、回想与设置",
      badge: "版本 1.0.29 · 2026年8月",
      nav: ["目录", "开始", "时间线", "搜索", "关系网", "回想", "记忆影片", "设置", "免费 · Pro", "FAQ", "隐私", "条款"],
    },
    "zh-Hant": {
      title: "模談網 (MemoryOS) 使用指南",
      h1: "模談網 (MemoryOS)<br>使用指南",
      tagline: "從儲存記憶到關係網、回想與設定",
      badge: "版本 1.0.29 · 2026年8月",
      nav: ["目錄", "開始", "時間軸", "搜尋", "關係網", "回想", "記憶影片", "設定", "免費 · Pro", "FAQ", "隱私", "條款"],
    },
    es: {
      title: "Guía de Modamnet (MemoryOS)",
      h1: "Modamnet (MemoryOS)<br>Guía de uso",
      tagline: "De guardar recuerdos al grafo, el recall y los ajustes",
      badge: "Versión 1.0.29 · agosto 2026",
      nav: ["Índice", "Inicio", "Línea de tiempo", "Búsqueda", "Grafo", "Recall", "Película", "Ajustes", "Gratis · Pro", "FAQ", "Privacidad", "Términos"],
    },
    fr: {
      title: "Guide Modamnet (MemoryOS)",
      h1: "Modamnet (MemoryOS)<br>Guide d’utilisation",
      tagline: "Des souvenirs au graphe, au rappel et aux réglages",
      badge: "Version 1.0.29 · août 2026",
      nav: ["Sommaire", "Démarrer", "Fil", "Recherche", "Graphe", "Rappel", "Film", "Réglages", "Gratuit · Pro", "FAQ", "Confidentialité", "Conditions"],
    },
    de: {
      title: "Modamnet (MemoryOS) Handbuch",
      h1: "Modamnet (MemoryOS)<br>Benutzerhandbuch",
      tagline: "Von Erinnerungen über das Netzwerk bis zu Einstellungen",
      badge: "Version 1.0.29 · August 2026",
      nav: ["Inhalt", "Start", "Zeitlinie", "Suche", "Netz", "Rückblick", "Film", "Einstellungen", "Gratis · Pro", "FAQ", "Datenschutz", "AGB"],
    },
    "pt-BR": {
      title: "Guia do Modamnet (MemoryOS)",
      h1: "Modamnet (MemoryOS)<br>Guia de uso",
      tagline: "De salvar memórias ao grafo, recall e configurações",
      badge: "Versão 1.0.29 · agosto de 2026",
      nav: ["Índice", "Começar", "Linha do tempo", "Busca", "Grafo", "Recall", "Filme", "Ajustes", "Grátis · Pro", "FAQ", "Privacidade", "Termos"],
    },
    vi: {
      title: "Hướng dẫn Modamnet (MemoryOS)",
      h1: "Modamnet (MemoryOS)<br>Hướng dẫn sử dụng",
      tagline: "Từ lưu ký ức đến mạng quan hệ, hồi tưởng và cài đặt",
      badge: "Phiên bản 1.0.29 · tháng 8/2026",
      nav: ["Mục lục", "Bắt đầu", "Dòng thời gian", "Tìm kiếm", "Mạng", "Hồi tưởng", "Phim", "Cài đặt", "Miễn phí · Pro", "FAQ", "Riêng tư", "Điều khoản"],
    },
    ko: {
      title: "모담넷(MemoryOS) 상세 이용 가이드",
      h1: "모담넷(MemoryOS)<br>상세 이용 가이드",
      tagline: "사용자용 — 기억 저장부터 관계망·회상·설정까지 한눈에",
      badge: "버전 1.0.29 (33) · 2026년 8월",
      nav: ["목차", "시작", "타임라인", "검색", "관계망", "회상", "기억 영상", "설정", "무료·Pro", "FAQ", "개인정보", "이용약관"],
    },
  };

  var MAIN = {};
  MAIN.en = '<section id="toc" class="toc"><h2>Contents</h2><ol><li><a href="#about">What is Modamnet</a></li><li><a href="#start">Getting started</a></li><li><a href="#timeline">Timeline</a></li><li><a href="#search">Search</a></li><li><a href="#graph">Relationship graph</a></li><li><a href="#replay">Recall</a></li><li><a href="#film">Memory film (Pro)</a></li><li><a href="#settings">Settings</a></li><li><a href="#pro">Free and Pro</a></li><li><a href="#faq">FAQ</a></li></ol></section>'
    + '<section id="about"><h2>1. What is Modamnet?</h2><p>Modamnet (MemoryOS) is a <strong>personal memory app</strong> that stores voice, photos, video, and text on a timeline and reconnects people, places, and events in a <strong>relationship graph</strong>.</p><div class="tip"><strong>Tip:</strong> speak naturally. Names, places, dates, and feelings make search, graph, and recall more accurate.</div></section>'
    + '<section id="start"><h2>2. Getting started</h2><ol><li>Use <strong>Guest</strong> immediately, or sign in with email for cloud and Pro.</li><li>Tabs: Timeline · Search · Graph · Recall (gear for Settings).</li><li>Save a 30-second voice note, e.g. “Dinner with mom at Gwangalli today.”</li><li>(Pro) Settings → Create memory film, or the highlight on Recall.</li></ol></section>'
    + '<section id="timeline"><h2>3. Timeline — save memories</h2><p>Mic for speech or typing, camera/gallery for photos (several per card). Tap a card to edit text, tags, and media.</p><div class="tip">Cards group by date. Keywords scroll sideways.</div></section>'
    + '<section id="search"><h2>4. Search</h2><p>Ask in natural language. Signed-in Pro users also get an AI summary. Guest and privacy modes search on-device only.</p><div class="warn">Privacy/guest mode turns off cloud AI search.</div></section>'
    + '<section id="graph"><h2>5. Relationship graph</h2><p>Hubs and satellites show how people, places, and events connect. Pinch to zoom, drag empty space to pan, long-press a hub to move its group.</p></section>'
    + '<section id="replay"><h2>6. Recall</h2><p>Monthly galleries, swipe, and a mini-graph. Top <strong>Highlights</strong> use labeled buttons: <strong>View</strong> (photo slideshow), <strong>Film</strong> (Pro memory film), <strong>Graph</strong> (focus the relationship graph). Duplicate cards with the same memories are merged. After you export a film, a thumbnail on that card plays it immediately. Place alerts (~250 m) need Always location, notifications, and unrestricted battery.</p></section>'
    + '<section id="film"><h2>6.1 Memory film (Pro)</h2><p>Build a short film from photos and save/share an MP4. Choose length (including TikTok 15s and YouTube 60s shorts), photo count, template, transitions (including fade-to-white), voice, and several music tracks that play to match the film length. Group faces stay in frame; landscape photos export landscape. Films made from a highlight appear as thumbnails on that card.</p></section>'
    + '<section id="settings"><h2>7. Settings</h2><p>Language at the top changes menus, in-app help, and this web guide. Help → User guide opens PDF or this page in your language. Purchases work on the Play Store install.</p></section>'
    + '<section id="pro"><h2>8. Free and MemoryOS Pro</h2><p>Saving, local graph, and keyword search work free. Meaning search, photo AI, graph AI, and memory films are Pro. Restore purchases on the same Google account from a Play Store install.</p></section>'
    + '<section id="faq"><h2>9. FAQ</h2><p>No recall alerts: Always location + battery unrestricted. Film export stopped: reopen the app and continue. Faces cropped: use the latest app and portrait-safe templates. Restore fails: confirm Play Store install.</p></section>';

  MAIN.ja = '<section id="toc" class="toc"><h2>目次</h2><ol><li><a href="#about">モダムネットとは</a></li><li><a href="#start">はじめ方</a></li><li><a href="#timeline">タイムライン</a></li><li><a href="#search">検索</a></li><li><a href="#graph">関係網</a></li><li><a href="#replay">想起</a></li><li><a href="#film">記憶フィルム (Pro)</a></li><li><a href="#settings">設定</a></li><li><a href="#pro">無料とPro</a></li><li><a href="#faq">FAQ</a></li></ol></section>'
    + '<section id="about"><h2>1. モダムネットとは？</h2><p>音声・写真・動画・テキストの記憶をタイムラインに残し、<strong>関係網</strong>で人・場所・出来事をつなぐ個人記憶アプリです。</p><div class="tip">自然な言葉で入力すると検索・関係網・想起が正確になります。</div></section>'
    + '<section id="start"><h2>2. はじめ方</h2><ol><li>ゲストですぐ使うか、メールでログインしてクラウドとProを使います。</li><li>タブ：タイムライン・検索・関係網・想起（設定は歯車）。</li><li>30秒だけ話して保存してみてください。</li></ol></section>'
    + '<section id="timeline"><h2>3. タイムライン</h2><p>マイク、カメラ／ギャラリー。カードをタップして本文・タグ・メディアを編集します。</p></section>'
    + '<section id="search"><h2>4. 検索</h2><p>自然文で質問します。ProはAI要約も表示。ゲスト／プライバシーは端末内のみです。</p></section>'
    + '<section id="graph"><h2>5. 関係網</h2><p>ハブと衛星でつながりを表示。ピンチで拡大、空所ドラッグで移動。</p></section>'
    + '<section id="replay"><h2>6. 想起</h2><p>月別ギャラリーとスワイプ。上部ハイライトは<strong>見る・映像・関係</strong>の文字ボタンです。同じ内容のカードは1枚にまとめ、作った映像はサムネイルから再生できます。場所通知は「常に許可」と電池の最適化オフが必要です。</p></section>'
    + '<section id="film"><h2>6.1 記憶フィルム (Pro)</h2><p>写真から短いフィルムを作りMP4で保存・共有します。TikTok 15秒・YouTube 60秒のショート、複数BGM、顔が切れない構図に対応します。</p></section>'
    + '<section id="settings"><h2>7. 設定</h2><p>上部の言語がメニュー・アプリ内ガイド・このWebガイドに反映されます。</p></section>'
    + '<section id="pro"><h2>8. 無料とPro</h2><p>保存とローカル検索は無料。意味検索・写真AI・関係網AI・記憶フィルムはProです。</p></section>'
    + '<section id="faq"><h2>9. FAQ</h2><p>通知が来ない：位置情報を常に許可。書き出し中断：アプリを再度開いて続行。</p></section>';

  MAIN["zh-Hans"] = '<section id="toc" class="toc"><h2>目录</h2><ol><li><a href="#about">什么是模谈网</a></li><li><a href="#start">开始使用</a></li><li><a href="#timeline">时间线</a></li><li><a href="#search">搜索</a></li><li><a href="#graph">关系网</a></li><li><a href="#replay">回想</a></li><li><a href="#film">记忆影片 (Pro)</a></li><li><a href="#settings">设置</a></li><li><a href="#pro">免费与 Pro</a></li><li><a href="#faq">常见问题</a></li></ol></section>'
    + '<section id="about"><h2>1. 什么是模谈网？</h2><p>用语音、照片、视频和文字保存记忆，并用<strong>关系网</strong>把人、地点和事件连起来的个人记忆应用。</p><div class="tip">请用自然语言输入姓名、地点、日期和感受。</div></section>'
    + '<section id="start"><h2>2. 开始使用</h2><ol><li>可用访客模式，或用邮箱登录以使用云端和 Pro。</li><li>底部：时间线 · 搜索 · 关系网 · 回想（设置在齿轮）。</li><li>先用麦克风保存 30 秒语音。</li></ol></section>'
    + '<section id="timeline"><h2>3. 时间线</h2><p>麦克风、相机/相册。点卡片可编辑正文、标签和媒体。</p></section>'
    + '<section id="search"><h2>4. 搜索</h2><p>用自然语言提问。Pro 另有 AI 摘要。访客/隐私模式仅搜索本机。</p></section>'
    + '<section id="graph"><h2>5. 关系网</h2><p>枢纽与卫星显示连接。捏合缩放，拖动空白处移动。</p></section>'
    + '<section id="replay"><h2>6. 回想</h2><p>按月图库与滑动。顶部精彩卡片用<strong>查看 · 影片 · 关系</strong>文字按钮。内容相同的卡片会合为一张；做好的记忆影片可点缩略图直接播放。地点提醒需要“始终允许”定位并关闭电池优化。</p></section>'
    + '<section id="film"><h2>6.1 记忆影片 (Pro)</h2><p>用照片制作短片并保存/分享 MP4。支持 TikTok 15 秒、YouTube 60 秒竖屏短视频、多首背景音乐，以及不裁切人脸。</p></section>'
    + '<section id="settings"><h2>7. 设置</h2><p>顶部语言会同步到菜单、应用内指南和本网页。</p></section>'
    + '<section id="pro"><h2>8. 免费与 Pro</h2><p>保存与本地搜索免费。语义搜索、照片 AI、关系网 AI 和记忆影片为 Pro。</p></section>'
    + '<section id="faq"><h2>9. 常见问题</h2><p>没有提醒：请设为始终允许定位。导出中断：重新打开应用继续。</p></section>';

  MAIN["zh-Hant"] = '<section id="toc" class="toc"><h2>目錄</h2><ol><li><a href="#about">什麼是模談網</a></li><li><a href="#start">開始使用</a></li><li><a href="#timeline">時間軸</a></li><li><a href="#search">搜尋</a></li><li><a href="#graph">關係網</a></li><li><a href="#replay">回想</a></li><li><a href="#film">記憶影片 (Pro)</a></li><li><a href="#settings">設定</a></li><li><a href="#pro">免費與 Pro</a></li><li><a href="#faq">常見問題</a></li></ol></section>'
    + '<section id="about"><h2>1. 什麼是模談網？</h2><p>以語音、照片、影片與文字保存記憶，並用<strong>關係網</strong>連結人、地點與事件的個人記憶 App。</p></section>'
    + '<section id="start"><h2>2. 開始使用</h2><ol><li>可用訪客模式，或電子郵件登入以使用雲端與 Pro。</li><li>底部：時間軸 · 搜尋 · 關係網 · 回想。</li></ol></section>'
    + '<section id="timeline"><h2>3. 時間軸</h2><p>麥克風、相機／相簿。點卡片可編輯正文、標籤與媒體。</p></section>'
    + '<section id="search"><h2>4. 搜尋</h2><p>用自然語言提問。Pro 另有 AI 摘要。</p></section>'
    + '<section id="graph"><h2>5. 關係網</h2><p>樞紐與衛星顯示連結。雙指縮放，拖曳空白處移動。</p></section>'
    + '<section id="replay"><h2>6. 回想</h2><p>按月相簿與滑動。頂部精彩卡片以<strong>查看 · 影片 · 關係</strong>文字按鈕操作。內容幾乎相同的卡片會合併；做好的記憶影片可點縮圖直接播放。地點提醒需「一律允許」定位。</p></section>'
    + '<section id="film"><h2>6.1 記憶影片 (Pro)</h2><p>用照片製作短片並儲存／分享 MP4。支援 TikTok 15 秒、YouTube 60 秒直式短片與多首背景音樂。</p></section>'
    + '<section id="settings"><h2>7. 設定</h2><p>頂端語言會套用到選單、App 內說明與本網頁。</p></section>'
    + '<section id="pro"><h2>8. 免費與 Pro</h2><p>儲存與本機搜尋免費。語意搜尋、照片 AI、關係網 AI 與記憶影片為 Pro。</p></section>'
    + '<section id="faq"><h2>9. 常見問題</h2><p>沒有通知：請設為一律允許定位。匯出中斷：重新開啟 App 繼續。</p></section>';

  MAIN.es = '<section id="toc" class="toc"><h2>Índice</h2><ol><li><a href="#about">Qué es Modamnet</a></li><li><a href="#start">Empezar</a></li><li><a href="#timeline">Línea de tiempo</a></li><li><a href="#search">Búsqueda</a></li><li><a href="#graph">Grafo</a></li><li><a href="#replay">Recall</a></li><li><a href="#film">Película (Pro)</a></li><li><a href="#settings">Ajustes</a></li><li><a href="#pro">Gratis y Pro</a></li><li><a href="#faq">FAQ</a></li></ol></section>'
    + '<section id="about"><h2>1. Qué es Modamnet</h2><p>App de memoria personal: voz, fotos, vídeo y texto en una línea de tiempo, con un <strong>grafo de relaciones</strong>.</p></section>'
    + '<section id="start"><h2>2. Empezar</h2><ol><li>Modo invitado o inicio de sesión por correo para la nube y Pro.</li><li>Pestañas: Línea de tiempo · Búsqueda · Grafo · Recall.</li></ol></section>'
    + '<section id="timeline"><h2>3. Línea de tiempo</h2><p>Micrófono y cámara/galería. Toque una tarjeta para editar.</p></section>'
    + '<section id="search"><h2>4. Búsqueda</h2><p>Pregunte en lenguaje natural. Pro añade un resumen de IA.</p></section>'
    + '<section id="graph"><h2>5. Grafo</h2><p>Nodos hub y satélite. Pellizque para zoom.</p></section>'
    + '<section id="replay"><h2>6. Recall</h2><p>Galería mensual. Destacados con botones <strong>Ver · Película · Grafo</strong>. Las tarjetas duplicadas se unen; pulse la miniatura para ver la película. Alertas de lugar: ubicación Siempre y batería sin restricción.</p></section>'
    + '<section id="film"><h2>6.1 Película de recuerdos (Pro)</h2><p>Cree un MP4. Incluye cortos TikTok 15 s y YouTube 60 s, varias músicas y encuadre de todos los rostros.</p></section>'
    + '<section id="settings"><h2>7. Ajustes</h2><p>El idioma superior cambia menús, la guía in-app y esta web.</p></section>'
    + '<section id="pro"><h2>8. Gratis y Pro</h2><p>Guardar y buscar en el dispositivo es gratis. Búsqueda semántica, IA y películas son Pro.</p></section>'
    + '<section id="faq"><h2>9. FAQ</h2><p>Sin avisos: ubicación Siempre. Exportación interrumpida: reabra la app y continúe.</p></section>';

  MAIN.fr = '<section id="toc" class="toc"><h2>Sommaire</h2><ol><li><a href="#about">Qu’est-ce que Modamnet</a></li><li><a href="#start">Démarrer</a></li><li><a href="#timeline">Fil</a></li><li><a href="#search">Recherche</a></li><li><a href="#graph">Graphe</a></li><li><a href="#replay">Rappel</a></li><li><a href="#film">Film (Pro)</a></li><li><a href="#settings">Réglages</a></li><li><a href="#pro">Gratuit et Pro</a></li><li><a href="#faq">FAQ</a></li></ol></section>'
    + '<section id="about"><h2>1. Qu’est-ce que Modamnet ?</h2><p>Application de mémoire personnelle : voix, photos, vidéo, texte, et un <strong>graphe de relations</strong>.</p></section>'
    + '<section id="start"><h2>2. Démarrer</h2><ol><li>Mode invité ou connexion e-mail pour le cloud et Pro.</li><li>Onglets : Fil · Recherche · Graphe · Rappel.</li></ol></section>'
    + '<section id="timeline"><h2>3. Fil</h2><p>Micro et appareil photo / galerie. Touchez une carte pour modifier.</p></section>'
    + '<section id="search"><h2>4. Recherche</h2><p>Posez une question en langage naturel. Pro ajoute un résumé IA.</p></section>'
    + '<section id="graph"><h2>5. Graphe</h2><p>Hubs et satellites. Pincez pour zoomer.</p></section>'
    + '<section id="replay"><h2>6. Rappel</h2><p>Galerie mensuelle. Boutons <strong>Voir · Film · Graphe</strong> sur les temps forts. Les cartes identiques sont fusionnées ; la miniature relance le film. Alertes de lieu : localisation Toujours.</p></section>'
    + '<section id="film"><h2>6.1 Film souvenir (Pro)</h2><p>Créez un MP4. Shorts TikTok 15 s et YouTube 60 s, plusieurs musiques, visages conservés.</p></section>'
    + '<section id="settings"><h2>7. Réglages</h2><p>La langue en haut s’applique aux menus, au guide in-app et à cette page.</p></section>'
    + '<section id="pro"><h2>8. Gratuit et Pro</h2><p>Enregistrement et recherche locale gratuits. Recherche sémantique, IA et films sont Pro.</p></section>'
    + '<section id="faq"><h2>9. FAQ</h2><p>Pas d’alertes : localisation Toujours. Export interrompu : rouvrez l’app.</p></section>';

  MAIN.de = '<section id="toc" class="toc"><h2>Inhalt</h2><ol><li><a href="#about">Was ist Modamnet</a></li><li><a href="#start">Start</a></li><li><a href="#timeline">Zeitlinie</a></li><li><a href="#search">Suche</a></li><li><a href="#graph">Netz</a></li><li><a href="#replay">Rückblick</a></li><li><a href="#film">Film (Pro)</a></li><li><a href="#settings">Einstellungen</a></li><li><a href="#pro">Gratis und Pro</a></li><li><a href="#faq">FAQ</a></li></ol></section>'
    + '<section id="about"><h2>1. Was ist Modamnet?</h2><p>Persönliche Erinnerungs-App für Sprache, Fotos, Video und Text mit einem <strong>Beziehungsnetz</strong>.</p></section>'
    + '<section id="start"><h2>2. Start</h2><ol><li>Gastmodus oder E-Mail-Login für Cloud und Pro.</li><li>Tabs: Zeitlinie · Suche · Netz · Rückblick.</li></ol></section>'
    + '<section id="timeline"><h2>3. Zeitlinie</h2><p>Mikrofon und Kamera/Galerie. Tippen Sie eine Karte zum Bearbeiten.</p></section>'
    + '<section id="search"><h2>4. Suche</h2><p>Fragen Sie in natürlicher Sprache. Pro zeigt eine KI-Zusammenfassung.</p></section>'
    + '<section id="graph"><h2>5. Netz</h2><p>Hubs und Satelliten. Zum Zoomen zusammenziehen.</p></section>'
    + '<section id="replay"><h2>6. Rückblick</h2><p>Monatliche Galerie. Highlights mit <strong>Ansehen · Film · Netz</strong>. Doppelte Karten werden zusammengeführt; Miniatur startet den Film. Ortsbenachrichtigungen: Standort Immer zulassen.</p></section>'
    + '<section id="film"><h2>6.1 Erinnerungsfilm (Pro)</h2><p>MP4 aus Fotos. TikTok 15 s und YouTube 60 s, mehrere Musiktitel, Gesichter bleiben im Bild.</p></section>'
    + '<section id="settings"><h2>7. Einstellungen</h2><p>Die Sprache oben gilt für Menüs, In-App-Hilfe und diese Seite.</p></section>'
    + '<section id="pro"><h2>8. Gratis und Pro</h2><p>Speichern und lokale Suche sind gratis. Semantische Suche, KI und Filme sind Pro.</p></section>'
    + '<section id="faq"><h2>9. FAQ</h2><p>Keine Hinweise: Standort Immer. Export unterbrochen: App erneut öffnen.</p></section>';

  MAIN["pt-BR"] = '<section id="toc" class="toc"><h2>Índice</h2><ol><li><a href="#about">O que é o Modamnet</a></li><li><a href="#start">Começar</a></li><li><a href="#timeline">Linha do tempo</a></li><li><a href="#search">Busca</a></li><li><a href="#graph">Grafo</a></li><li><a href="#replay">Recall</a></li><li><a href="#film">Filme (Pro)</a></li><li><a href="#settings">Ajustes</a></li><li><a href="#pro">Grátis e Pro</a></li><li><a href="#faq">FAQ</a></li></ol></section>'
    + '<section id="about"><h2>1. O que é o Modamnet?</h2><p>App de memória pessoal: voz, fotos, vídeo e texto, com um <strong>grafo de relações</strong>.</p></section>'
    + '<section id="start"><h2>2. Começar</h2><ol><li>Modo convidado ou login por e-mail para nuvem e Pro.</li><li>Abas: Linha do tempo · Busca · Grafo · Recall.</li></ol></section>'
    + '<section id="timeline"><h2>3. Linha do tempo</h2><p>Microfone e câmera/galeria. Toque no cartão para editar.</p></section>'
    + '<section id="search"><h2>4. Busca</h2><p>Pergunte em linguagem natural. O Pro mostra um resumo de IA.</p></section>'
    + '<section id="graph"><h2>5. Grafo</h2><p>Hubs e satélites. Belisque para zoom.</p></section>'
    + '<section id="replay"><h2>6. Recall</h2><p>Galeria mensal. Destaques com <strong>Ver · Filme · Grafo</strong>. Cartões iguais são unidos; toque na miniatura para reproduzir. Alertas de lugar: localização Sempre.</p></section>'
    + '<section id="film"><h2>6.1 Filme de memórias (Pro)</h2><p>Crie um MP4. Shorts TikTok 15 s e YouTube 60 s, várias músicas, rostos visíveis.</p></section>'
    + '<section id="settings"><h2>7. Ajustes</h2><p>O idioma no topo vale para menus, o guia no app e esta página.</p></section>'
    + '<section id="pro"><h2>8. Grátis e Pro</h2><p>Salvar e buscar no aparelho é grátis. Busca semântica, IA e filmes são Pro.</p></section>'
    + '<section id="faq"><h2>9. FAQ</h2><p>Sem alertas: localização Sempre. Exportação interrompida: reabra o app.</p></section>';

  MAIN.vi = '<section id="toc" class="toc"><h2>Mục lục</h2><ol><li><a href="#about">Modamnet là gì</a></li><li><a href="#start">Bắt đầu</a></li><li><a href="#timeline">Dòng thời gian</a></li><li><a href="#search">Tìm kiếm</a></li><li><a href="#graph">Mạng quan hệ</a></li><li><a href="#replay">Hồi tưởng</a></li><li><a href="#film">Phim (Pro)</a></li><li><a href="#settings">Cài đặt</a></li><li><a href="#pro">Miễn phí và Pro</a></li><li><a href="#faq">FAQ</a></li></ol></section>'
    + '<section id="about"><h2>1. Modamnet là gì?</h2><p>Ứng dụng ký ức cá nhân: giọng nói, ảnh, video, chữ, với <strong>mạng quan hệ</strong>.</p></section>'
    + '<section id="start"><h2>2. Bắt đầu</h2><ol><li>Chế độ khách hoặc đăng nhập email cho đám mây và Pro.</li><li>Tab: Dòng thời gian · Tìm kiếm · Mạng · Hồi tưởng.</li></ol></section>'
    + '<section id="timeline"><h2>3. Dòng thời gian</h2><p>Micro và camera/thư viện. Chạm thẻ để sửa.</p></section>'
    + '<section id="search"><h2>4. Tìm kiếm</h2><p>Hỏi bằng ngôn ngữ tự nhiên. Pro có tóm tắt AI.</p></section>'
    + '<section id="graph"><h2>5. Mạng quan hệ</h2><p>Hub và vệ tinh. Véot để phóng to.</p></section>'
    + '<section id="replay"><h2>6. Hồi tưởng</h2><p>Thư viện theo tháng. Nút <strong>Xem · Phim · Mạng</strong> trên điểm nổi bật. Thẻ trùng được gộp; chạm ảnh thu nhỏ để phát. Cảnh báo địa điểm: vị trí Luôn luôn.</p></section>'
    + '<section id="film"><h2>6.1 Phim ký ức (Pro)</h2><p>Tạo MP4. Short TikTok 15 giây và YouTube 60 giây, nhiều bài nhạc, không cắt mặt.</p></section>'
    + '<section id="settings"><h2>7. Cài đặt</h2><p>Ngôn ngữ phía trên áp dụng cho menu, hướng dẫn trong app và trang này.</p></section>'
    + '<section id="pro"><h2>8. Miễn phí và Pro</h2><p>Lưu và tìm trên máy là miễn phí. Tìm theo nghĩa, AI và phim là Pro.</p></section>'
    + '<section id="faq"><h2>9. FAQ</h2><p>Không có thông báo: cấp vị trí Luôn luôn. Xuất bị dừng: mở lại app.</p></section>';

  function applyUserGuideLang(raw) {
    var lang = norm(raw);
    document.documentElement.lang = lang === "zh-Hans" || lang === "zh-Hant" ? "zh" : lang.split("-")[0];
    var pack = T[lang] || T.en;
    document.title = pack.title;
    var h1 = document.querySelector(".hero h1");
    var tag = document.querySelector(".hero .tagline");
    var badge = document.querySelector(".hero .badge");
    if (h1) h1.innerHTML = pack.h1;
    if (tag) tag.textContent = pack.tagline;
    if (badge) badge.textContent = pack.badge;
    var nav = document.querySelectorAll("nav.top a");
    for (var i = 0; i < nav.length && i < pack.nav.length; i++) {
      nav[i].textContent = pack.nav[i];
    }
    var main = document.querySelector("main");
    if (main && lang !== "ko" && MAIN[lang]) {
      main.innerHTML = MAIN[lang];
    }
    var bar = document.getElementById("langBar");
    if (bar) {
      bar.innerHTML = "";
      LANGS.forEach(function (item) {
        var b = document.createElement("button");
        b.type = "button";
        b.textContent = item.label;
        if (item.id === lang) b.className = "active";
        b.onclick = function () {
          var u = new URL(location.href);
          u.searchParams.set("lang", item.id);
          location.href = u.toString();
        };
        bar.appendChild(b);
      });
    }
  }

  global.applyUserGuideLang = applyUserGuideLang;
})(window);

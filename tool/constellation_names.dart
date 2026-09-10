/// Имена созвездий на пяти языках: slug → язык → имя.
///
/// Пятьдесят тем × пять языков (`de`, `uk`, `ru`, `en`, `it`) = 250 строк.
/// Отсюда их разносит по исходникам `tool/import_phrasebook.dart`: немецкое
/// имя уезжает полем `name:` в шапку `content/phrases/de/<тема>.yaml`, а
/// остальные четыре — в раздел `constellations:` файла
/// `content/lang/<код>.yaml`.
///
/// **Почему имена живут в коде, а не в исходниках контента.** Импорт удаляет
/// и пересоздаёт `content/phrases/de/` целиком. Имя, дописанное руками в
/// сгенерированный файл, следующий импорт снёс бы молча — так же, как снесёт
/// любую правку этих файлов. Единственное место, откуда имя переживёт
/// пересборку, — исходник импорта. Ровно по этой же причине рядом лежит
/// [constellationSlugs] в `import_phrasebook.dart`: slug решает, как тема
/// называется в базе и в памяти игрока, и автоматическая транслитерация
/// превратила бы правку заголовка в потерю прогресса.
///
/// **Что будет, если тему здесь забыть.** Импорт откажется работать и назовёт
/// пропущенные пары «тема/язык» — до того, как удалит существующие файлы.
/// Молча уехать латинскому слагу на карту эта таблица не даёт: он и был тем,
/// от чего v6 избавляется.
///
/// ── Как имена написаны ─────────────────────────────────────────────────────
///
/// Четыре прохода, и каждый следующий видел то, чего не видел предыдущий.
///
/// 1. Первый писал имена **по ярусу**, читая двадцать фраз каждой темы.
/// 2. Второй проверял каждый ярус с заданием опровергать, а не одобрять:
///    двадцать восемь имён из 250 переписаны, десяток — по содержимому темы, а
///    не по языку. «Убедительное обращение» из заголовка источника оказалось
///    двадцатью фразами про жалобу и требование; «Культура и впечатления» —
///    про кино и книги.
/// 3. Третий смотрел на **набор целиком**, глазами игрока, у которого все
///    пятьдесят подписей на одной карте, — и нашёл то, чего по одной теме не
///    видно: семь пар, которые игрок спутает («Советы и решения» против
///    «Совещания и решения» — 0.80, самое высокое сходство из 4900 пар),
///    семь имён, врущих о содержимом («Подорож і готель» — дороги в теме нет
///    ни одной фразы, тринадцать про стойку отеля), и разнобой украинского
///    союза.
/// 4. Четвёртый сверял **итог** и нашёл то, что создали сами правки: пару
///    «Экология в быту» / «Цифровой быт» и усиленную союзом пару
///    «Самопочуття й лікар» / «Почуття й підтримка», где «почуття» целиком
///    лежит внутри «самопочуття».
///
/// Отсюда правило работы с этой таблицей: **правка имени проверяется против
/// всего набора своего языка, а не против той пары, ради которой делается.**
/// Развести одну пару, сблизив другую, здесь получалось трижды.
///
/// **Украинский союз выбирается по одному правилу, а не пятьдесят раз.**
/// Было: `і` в 24 именах, `й` в семи, `та` в семи — без правила, причём
/// эвфоническое чередование соблюдалось ровно там, где стоял `й`, и
/// нарушалось в двадцати случаях из двадцати четырёх. Стало:
///
/// * `й` — после гласного перед согласным («Дорога й транспорт»);
/// * `і` — между согласным и гласным и между двумя согласными
///   («Лікар і аптека», «Випадок і наслідки»);
/// * `та` — там, где и `й`, и `і` дали бы стык одинаковых звуков («Кафе та
///   їжа»), где сходятся два гласных («Покупки та оплата») и после читаемой
///   по буквам аббревиатуры на «І» («ШІ та довіра»). Последний выход
///   **орфографический, а не фонетический**: по звукам стык в «ШІ» тождествен
///   «Гроші й договори», и правило требовало бы `й`; сказано это прямо, потому
///   что молчаливое исключение из правила — это отсутствие правила.
///
/// **Двадцать четыре знака — потолок, и охраняет он не то, что казалось.**
/// Прежняя запись объясняла его «подписью под созвездием на карте». Подписей
/// на карте нет: `SkyMap` не рисует текста вовсе, имя показывается в нижней
/// карточке после нажатия и в строке профиля — оба раза в переносящемся
/// тексте, который длинное имя выдержал бы. Потолок остаётся по двум
/// настоящим причинам: имя уезжает в **одну строку пуш-напоминания**, где
/// переноса нет, и короткое имя игрок различает на карте быстрее длинного.
///
/// **`ecology_mobility` больше не про мобильность ни в одном из пяти имён** —
/// в теме девять фраз про бытовые привычки и четыре про транспорт, и имена
/// говорят о привычках. Slug оставлен как есть: он лежит в памяти игрока
/// ключом к прогрессу, и переименование стоило бы ему выученного.
library;

/// slug созвездия → код языка → имя темы.
///
/// Языки перечислены по порядку `rowLangs` источника разговорника: `de` первым
/// идёт как язык изучения — у него есть текст имени, а не перевод.
const Map<String, Map<String, String>> constellationNames = {
  // A0
  'first_contact': {
    'de': 'Erste Worte',
    'uk': 'Перші слова',
    'ru': 'Первые слова',
    'en': 'First Words',
    'it': 'Prime parole',
  },
  'about_me': {
    'de': 'Über mich',
    'uk': 'Про себе',
    'ru': 'О себе',
    'en': 'About Me',
    'it': 'Su di me',
  },
  'understanding': {
    'de': 'Verstehen und Nachfragen',
    'uk': 'Перепитування',
    'ru': 'Понимание и переспрос',
    'en': 'Understanding and Asking',
    'it': 'Capire e chiedere',
  },
  'needs_help': {
    'de': 'Hilfe und Bedürfnisse',
    'uk': 'Потреби й допомога',
    'ru': 'Потребности и помощь',
    'en': 'Needs and Help',
    'it': 'Bisogni e aiuto',
  },
  'place_time_price': {
    'de': 'Ort, Zeit und Preis',
    'uk': 'Місце, час і ціна',
    'ru': 'Место, время и цена',
    'en': 'Place, Time, Price',
    'it': 'Luogo, ora e prezzo',
  },
  // A1
  'people_family': {
    'de': 'Familie und Bekannte',
    'uk': 'Родина й знайомі',
    'ru': 'Семья и знакомые',
    'en': 'Family and Friends',
    'it': 'Famiglia e amici',
  },
  'daily_routine': {
    'de': 'Tagesablauf',
    'uk': 'Розпорядок дня',
    'ru': 'Обычный день',
    'en': 'Daily Routine',
    'it': 'Giornata tipo',
  },
  'cafe_food': {
    'de': 'Café und Restaurant',
    'uk': 'Кафе та їжа',
    'ru': 'Кафе и еда',
    'en': 'Eating Out',
    'it': 'Bar e ristorante',
  },
  'shopping_payment': {
    'de': 'Einkauf und Kasse',
    'uk': 'Покупки та оплата',
    'ru': 'Покупка и оплата',
    'en': 'Shopping and Payment',
    'it': 'Acquisti e pagamenti',
  },
  'transport': {
    'de': 'Bus und Bahn',
    'uk': 'Дорога й транспорт',
    'ru': 'Дорога и транспорт',
    'en': 'Getting Around',
    'it': 'Mezzi e indicazioni',
  },
  'travel_hotel': {
    'de': 'Hotel und Ausflüge',
    'uk': 'Готель і екскурсії',
    'ru': 'Гостиница и экскурсии',
    'en': 'Hotel and Sightseeing',
    'it': 'Albergo e visite',
  },
  'health_doctor': {
    'de': 'Arzt und Apotheke',
    'uk': 'Лікар і аптека',
    'ru': 'Врач и аптека',
    'en': 'Doctor and Pharmacy',
    'it': 'Medico e farmacia',
  },
  'plans_invitations': {
    'de': 'Pläne und Einladungen',
    'uk': 'Плани й запрошення',
    'ru': 'Планы и приглашения',
    'en': 'Plans and Invitations',
    'it': 'Programmi e inviti',
  },
  'study_contact': {
    'de': 'Unterricht und Kontakt',
    'uk': "Навчання й зв'язок",
    'ru': 'Учёба и связь',
    'en': 'Class and Devices',
    'it': 'Lezioni e dispositivi',
  },
  // A2
  'past_stories': {
    'de': 'Geschichten von früher',
    'uk': 'Історії з минулого',
    'ru': 'Рассказ о прошлом',
    'en': 'Stories from the Past',
    'it': 'Storie del passato',
  },
  'arrangements': {
    'de': 'Termine und Fristen',
    'uk': 'Домовленості й терміни',
    'ru': 'Договорённости и сроки',
    'en': 'Scheduling and Deadlines',
    'it': 'Impegni e scadenze',
  },
  'housing_repairs': {
    'de': 'Wohnung und Mängel',
    'uk': 'Житло й несправності',
    'ru': 'Жильё и неполадки',
    'en': 'Housing and Repairs',
    'it': 'Casa e guasti',
  },
  'returns_delivery': {
    'de': 'Rückgabe und Lieferung',
    'uk': 'Повернення й доставка',
    'ru': 'Возврат и доставка',
    'en': 'Returns and Deliveries',
    'it': 'Resi e consegne',
  },
  'travel_trouble': {
    'de': 'Reisepannen',
    'uk': 'Проблеми в дорозі',
    'ru': 'Проблемы в поездке',
    'en': 'Travel Trouble',
    'it': 'Imprevisti di viaggio',
  },
  'symptoms_treatment': {
    'de': 'Symptome und Behandlung',
    'uk': 'Симптоми й лікування',
    'ru': 'Симптомы и лечение',
    'en': 'Symptoms and Treatment',
    'it': 'Sintomi e cure',
  },
  'work_search': {
    'de': 'Jobsuche und Bewerbung',
    'uk': 'Вакансія й співбесіда',
    'ru': 'Вакансия и собеседование',
    'en': 'Job Search and Interview',
    'it': 'Candidatura e colloquio',
  },
  'learning_how': {
    'de': 'Lernen und Fortschritt',
    'uk': 'Практика й прогрес',
    'ru': 'Практика и прогресс',
    'en': 'Practice and Progress',
    'it': 'Pratica e progressi',
  },
  'feelings_support': {
    'de': 'Gefühle und Trost',
    'uk': 'Почуття й підтримка',
    'ru': 'Чувства и поддержка',
    'en': 'Feelings and Support',
    'it': 'Emozioni e sostegno',
  },
  'digital_life': {
    'de': 'Digitaler Alltag',
    'uk': 'Цифрове життя',
    'ru': 'Цифровой быт',
    'en': 'Digital Life',
    'it': 'Vita digitale',
  },
  'comparison_conditions': {
    'de': 'Wahl und Bedingungen',
    'uk': 'Порівняння та умови',
    'ru': 'Сравнение и условия',
    'en': 'Choices and Conditions',
    'it': 'Confronti e condizioni',
  },
  // B1
  'opinion_reasons': {
    'de': 'Meinung und Begründung',
    'uk': 'Думка й причини',
    'ru': 'Мнение и причины',
    'en': 'Opinion and Reasons',
    'it': 'Opinione e motivi',
  },
  'agree_object': {
    'de': 'Zustimmung und Einwand',
    'uk': 'Згода й заперечення',
    'ru': 'Согласие и возражение',
    'en': 'Agreement and Objection',
    'it': 'Accordo e disaccordo',
  },
  'advice_decisions': {
    'de': 'Rat und Entscheidung',
    'uk': 'Порада й вибір',
    'ru': 'Советы и выбор',
    'en': 'Advice and Next Steps',
    'it': 'Consigli e alternative',
  },
  'teamwork': {
    'de': 'Teamarbeit',
    'uk': 'Командна робота',
    'ru': 'Командная работа',
    'en': 'Teamwork',
    'it': 'Lavoro di squadra',
  },
  'letters_requests': {
    'de': 'Briefe und Anfragen',
    'uk': 'Листи й звернення',
    'ru': 'Письма и обращения',
    'en': 'Letters and Requests',
    'it': 'Lettere e richieste',
  },
  'relations_boundaries': {
    'de': 'Beziehung und Grenzen',
    'uk': 'Стосунки й межі',
    'ru': 'Отношения и границы',
    'en': 'Boundaries and Respect',
    'it': 'Relazioni e confini',
  },
  'health_lifestyle': {
    'de': 'Gesundheit im Alltag',
    'uk': "Здоров'я й спосіб життя",
    'ru': 'Здоровье и образ жизни',
    'en': 'Health and Lifestyle',
    'it': 'Salute e stile di vita',
  },
  'money_contracts': {
    'de': 'Geld und Verträge',
    'uk': 'Гроші й договори',
    'ru': 'Деньги и договоры',
    'en': 'Money and Contracts',
    'it': 'Soldi e contratti',
  },
  'culture_impressions': {
    'de': 'Filme und Bücher',
    'uk': 'Кіно й книги',
    'ru': 'Кино и книги',
    'en': 'Films and Books',
    'it': 'Film e libri',
  },
  'ecology_mobility': {
    'de': 'Grüne Gewohnheiten',
    'uk': 'Зелені звички',
    'ru': 'Зелёные привычки',
    'en': 'Green Habits',
    'it': 'Abitudini sostenibili',
  },
  'history_consequences': {
    'de': 'Erlebnis und Folgen',
    'uk': 'Випадок і наслідки',
    'ru': 'Случай и последствия',
    'en': 'Events and Consequences',
    'it': 'Vicenda e conseguenze',
  },
  'clarify_mediate': {
    'de': 'Klärung und Wiedergabe',
    'uk': 'Уточнення й переказ',
    'ru': 'Уточнение и пересказ',
    'en': 'Clarification and Recap',
    'it': 'Chiarimento e riepilogo',
  },
  // B2
  'argument_building': {
    'de': 'Thesen und Argumente',
    'uk': 'Побудова аргументації',
    'ru': 'Построение аргументации',
    'en': 'Building an Argument',
    'it': 'Tesi e argomenti',
  },
  'sources_evidence': {
    'de': 'Quellen und Belege',
    'uk': 'Джерела й докази',
    'ru': 'Источники и проверка',
    'en': 'Sources and Evidence',
    'it': 'Fonti e prove',
  },
  'hedging': {
    'de': 'Vorsichtige Aussagen',
    'uk': 'Обережні формулювання',
    'ru': 'Осторожные формулировки',
    'en': 'Hedging and Caveats',
    'it': 'Formulazioni prudenti',
  },
  'negotiation': {
    'de': 'Verhandlungen',
    'uk': 'Перемовини й компроміс',
    'ru': 'Переговоры и компромисс',
    'en': 'Terms and Compromise',
    'it': 'Negoziato e compromesso',
  },
  'meetings_decisions': {
    'de': 'Sitzungen und Beschlüsse',
    'uk': 'Наради й рішення',
    'ru': 'Совещания и решения',
    'en': 'Meetings and Decisions',
    'it': 'Riunioni e decisioni',
  },
  'presentations_data': {
    'de': 'Vortrag und Zahlen',
    'uk': 'Презентації й дані',
    'ru': 'Презентации и данные',
    'en': 'Presentations and Data',
    'it': 'Presentazioni e dati',
  },
  'ai_information': {
    'de': 'KI und Vertrauen',
    'uk': 'ШІ та довіра',
    'ru': 'ИИ и доверие',
    'en': 'AI and Trust',
    'it': 'IA e fiducia',
  },
  'society_rights': {
    'de': 'Gesellschaft und Rechte',
    'uk': 'Суспільство й права',
    'ru': 'Общество и права',
    'en': 'Society and Rights',
    'it': 'Società e diritti',
  },
  'ecology_decisions': {
    'de': 'Umwelt und Kosten',
    'uk': 'Довкілля й витрати',
    'ru': 'Экология и расходы',
    'en': 'Environment and Cost',
    'it': 'Ambiente e costi',
  },
  'work_change': {
    'de': 'Arbeit und Wandel',
    'uk': 'Робота й зміни',
    'ru': 'Работа и перемены',
    'en': 'Work and Change',
    'it': 'Cambiamenti nel lavoro',
  },
  'persuasion': {
    'de': 'Beschwerde und Forderung',
    'uk': 'Скарга й вимога',
    'ru': 'Жалоба и требование',
    'en': 'Complaints and Claims',
    'it': 'Reclami e solleciti',
  },
  'idioms_speech': {
    'de': 'Redewendungen',
    'uk': 'Розмовні ідіоми',
    'ru': 'Разговорные идиомы',
    'en': 'Everyday Idioms',
    'it': 'Modi di dire',
  },
  'summary_rethink': {
    'de': 'Fazit und Rückblick',
    'uk': 'Підсумок і переоцінка',
    'ru': 'Итог и переосмысление',
    'en': 'Wrap-Up and Hindsight',
    'it': 'Bilancio e ripensamenti',
  },
};

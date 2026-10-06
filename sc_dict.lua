-- =============================================================================
-- sc_dict.lua : 全14武器種 WS ＋ PUPオートマトンWS ＋ SMN契約の履行 統合マトリクス辞書 (v7.0.5)
-- =============================================================================

local sc_dict = {}

-- レベル別連携相関ルール
sc_dict.SC_ELEMENTS = {
    ["溶解"] = { level = 1, elements = {"Fire"} },
    ["硬化"] = { level = 1, elements = {"Ice"} },
    ["炸裂"] = { level = 1, elements = {"Wind"} },
    ["切断"] = { level = 1, elements = {"Earth"} },
    ["衝撃"] = { level = 1, elements = {"Thunder"} },
    ["振動"] = { level = 1, elements = {"Water"} },
    ["貫通"] = { level = 1, elements = {"Light"} },
    ["収縮"] = { level = 1, elements = {"Dark"} },

    ["核熱"] = { level = 2, elements = {"Fire", "Light"} },
    ["重力"] = { level = 2, elements = {"Earth", "Dark"} },
    ["分解"] = { level = 2, elements = {"Wind", "Thunder"} },
    ["湾曲"] = { level = 2, elements = {"Ice", "Water"} },

    ["光"]   = { level = 3, elements = {"Fire", "Wind", "Thunder", "Light"} },
    ["闇"]   = { level = 3, elements = {"Ice", "Earth", "Water", "Dark"} },

    ["極光"] = { level = 4, elements = {"Fire", "Wind", "Thunder", "Light"} },
    ["黒闇"] = { level = 4, elements = {"Ice", "Earth", "Water", "Dark"} },
}

-- 連携判定マトリクステーブル: [直前の属性/連携][締めWSの属性] = 発生する連携
-- 出典: FFXIwiki「技連携」 https://wiki.ffo.jp/html/341.html
-- (同属性の重ね打ちは光/闇のみ連携する。Lv2 同士の重ね打ちは不成立)
-- 光→光 / 闇→闇 はもう一度だけ Lv3 (光/闇) になり、以降は連携不可。
-- 極光/黒闇 (Lv4) はイオニックウェポンのアフターマス中のみ発生するため、ここでは予測しない。
sc_dict.SC_COMBO_MAP = {
    ["溶解"] = { ["切断"] = "切断", ["衝撃"] = "核熱" },
    ["硬化"] = { ["収縮"] = "収縮", ["振動"] = "分解", ["衝撃"] = "衝撃" },
    ["炸裂"] = { ["切断"] = "切断", ["収縮"] = "重力" },
    ["切断"] = { ["溶解"] = "溶解", ["振動"] = "振動", ["炸裂"] = "炸裂" },
    ["衝撃"] = { ["溶解"] = "溶解", ["炸裂"] = "炸裂" },
    ["振動"] = { ["硬化"] = "硬化", ["衝撃"] = "衝撃" },
    ["貫通"] = { ["収縮"] = "収縮", ["切断"] = "湾曲", ["振動"] = "振動" },
    ["収縮"] = { ["貫通"] = "貫通", ["炸裂"] = "炸裂" },

    ["核熱"] = { ["重力"] = "重力", ["分解"] = "光" },
    ["重力"] = { ["湾曲"] = "闇", ["分解"] = "分解" },
    ["分解"] = { ["核熱"] = "光", ["湾曲"] = "湾曲" },
    ["湾曲"] = { ["重力"] = "闇", ["核熱"] = "核熱" },

    ["光"]   = { ["光"] = "光" },
    ["闇"]   = { ["闇"] = "闇" }
}

-- 連携した結果これ以上連携を続けられないか (光→光 / 闇→闇 の後、および極光/黒闇)
function sc_dict.is_terminal_chain(prev_sc, result_sc)
    if result_sc == "極光" or result_sc == "黒闇" then return true end
    return (result_sc == "光" or result_sc == "闇") and prev_sc == result_sc
end

-- 英語属性から日本語属性への変換マップ
sc_dict.EN_TO_JA_SC = {
    -- res/*.lua の skillchain_a/b/c では闇は "Darkness" (旧表記 "Dark" も念のため残す)
    ['Light'] = '光', ['Darkness'] = '闇', ['Dark'] = '闇',
    ['Gravitation'] = '重力', ['Fragmentation'] = '分解',
    ['Distortion'] = '湾曲', ['Fusion'] = '核熱',
    ['Compression'] = '収縮', ['Liquefaction'] = '溶解',
    ['Induration'] = '硬化', ['Reverberation'] = '振動',
    ['Transfixion'] = '貫通', ['Scission'] = '切断',
    ['Detonation'] = '炸裂', ['Impaction'] = '衝撃',
    ['Radiance'] = '極光', ['Umbra'] = '黒闇'
}

-- ジョブ別使用可能武器種マップ (全22ジョブ)
sc_dict.JOB_WEAPONS = {
    ["WAR"] = {"両手斧", "片手斧", "両手剣", "片手剣", "両手槍", "片手棍", "格闘"},
    ["PLD"] = {"片手剣", "両手剣", "片手棍", "両手棍"},
    ["SAM"] = {"両手刀", "弓術", "両手槍", "片手刀"},
    ["THF"] = {"短剣", "片手剣", "弓術", "射撃"},
    ["DRK"] = {"両手鎌", "両手剣", "片手剣", "両手斧"},
    ["DRG"] = {"両手槍", "短剣", "片手剣"},
    ["MNK"] = {"格闘", "両手棍"},
    ["RDM"] = {"片手剣", "短剣", "片手棍", "両手棍"},
    ["BLU"] = {"片手剣", "短剣", "片手棍"},
    ["COR"] = {"射撃", "短剣", "片手剣"},
    ["DNC"] = {"短剣", "格闘"},
    ["RUN"] = {"両手剣", "片手剣", "両手斧", "片手斧"},
    ["RNG"] = {"弓術", "射撃", "短剣", "片手剣", "両手槍"},
    ["NIN"] = {"片手刀", "短剣", "両手刀"},
    ["BST"] = {"片手斧", "両手鎌", "片手棍"},
    ["BRD"] = {"短剣", "片手剣", "片手棍"},
    ["PUP"] = {"格闘", "短剣"},
    ["SCH"] = {"両手棍", "片手棍"},
    ["GEO"] = {"片手棍", "両手棍"},
    ["WHM"] = {"片手棍", "両手棍"},
    ["BLM"] = {"両手棍", "片手棍", "短剣"},
    ["SMN"] = {"両手棍", "片手棍"},
}

-- 全14武器種 ウェポンスキル ＆ 属性定義 (プライムWS対応)
sc_dict.WEAPON_WS = {
    ["格闘"] = {
        { ja = "マルカラ", en = "Maru Kala", sc = {"炸裂", "収縮", "湾曲"} },
        { ja = "ビクトリースマイト", en = "Victory Smite", sc = {"光", "分解"} },
        { ja = "四神円舞", en = "Shijin Spiral", sc = {"核熱", "振動"} },
        { ja = "双竜脚", en = "Dragon Kick", sc = {"分解"} },
        { ja = "夢想阿修羅拳", en = "Asuran Fists", sc = {"重力", "溶解"} },
        { ja = "連環六合圏", en = "Stringing Pummel", sc = {"重力", "溶解"} },
        { ja = "乱撃", en = "Raging Fists", sc = {"衝撃"} },
        { ja = "コンボ", en = "Combo", sc = {"衝撃"} },
        { ja = "タックル", en = "Shoulder Tackle", sc = {"振動", "衝撃"} },
        { ja = "短勁", en = "One Inch Punch", sc = {"収縮"} },
        { ja = "バックハンドブロー", en = "Backhand Blow", sc = {"炸裂"} },
        { ja = "スピンアタック", en = "Spinning Attack", sc = {"溶解", "衝撃"} },
        { ja = "空鳴拳", en = "Howling Fist", sc = {"貫通", "衝撃"} },
        { ja = "闘魂旋風脚", en = "Tornado Kick", sc = {"硬化", "衝撃", "炸裂"} },
        { ja = "ファイナルヘヴン", en = "Final Heaven", sc = {"光", "核熱"} },
        { ja = "アスケーテンツォルン", en = "Ascetic's Fury", sc = {"核熱", "貫通"} },
        { ja = "ファイナルパラダイス", en = "Final Paradise", sc = {"光"} },
        { ja = "ドラゴンブロウ", en = "Dragon Blow", sc = {"湾曲"} },
    },
    ["短剣"] = {
        { ja = "ルースレスストローク", en = "Ruthless Stroke", sc = {"溶解", "衝撃", "分解"} },
        { ja = "ルドラストーム", en = "Rudra's Storm", sc = {"闇", "湾曲"} },
        { ja = "エヴィサレーション", en = "Evisceration", sc = {"重力", "貫通"} },
        { ja = "イオリアンエッジ", en = "Aeolian Edge", sc = {"切断", "炸裂", "衝撃"} },
        { ja = "ピリッククレオス", en = "Pyrrhic Kleos", sc = {"湾曲", "切断"} },
        { ja = "マンダリクスタッブ", en = "Mandalic Stab", sc = {"核熱", "収縮"} },
        { ja = "モーダントライム", en = "Mordant Rime", sc = {"分解", "湾曲"} },
        { ja = "マーシーストローク", en = "Mercy Stroke", sc = {"闇", "重力"} },
        { ja = "ワスプスティング", en = "Wasp Sting", sc = {"切断"} },
        { ja = "バイパーバイト", en = "Viper Bite", sc = {"切断"} },
        { ja = "シャドーステッチ", en = "Shadowstitch", sc = {"振動"} },
        { ja = "ガストスラッシュ", en = "Gust Slash", sc = {"炸裂"} },
        { ja = "サイクロン", en = "Cyclone", sc = {"炸裂", "衝撃"} },
        { ja = "エナジースティール", en = "Energy Steal", sc = {"属性なし"} },
        { ja = "エナジードレイン", en = "Energy Drain", sc = {"属性なし"} },
        { ja = "ダンシングエッジ", en = "Dancing Edge", sc = {"切断", "炸裂"} },
        { ja = "シャークバイト", en = "Shark Bite", sc = {"分解"} },
        { ja = "エクゼンテレター", en = "Exenterator", sc = {"分解", "切断"} },
    },
    ["片手剣"] = {
        { ja = "インペラトル", en = "Imperator", sc = {"炸裂", "収縮", "湾曲"} },
        { ja = "サベッジブレード", en = "Savage Blade", sc = {"分解", "切断"} },
        { ja = "シャンデュシニュ", en = "Chant du Cygne", sc = {"光", "湾曲"} },
        { ja = "ロズレーファタール", en = "Death Blossom", sc = {"分解", "湾曲"} },
        { ja = "ロイエ", en = "Atonement", sc = {"核熱", "振動"} },
        { ja = "レクイエスカット", en = "Requiescat", sc = {"重力", "切断"} },
        { ja = "ボーパルブレード", en = "Vorpal Blade", sc = {"切断", "衝撃"} },
        { ja = "ファストブレード", en = "Fast Blade", sc = {"切断"} },
        { ja = "バーニングブレード", en = "Burning Blade", sc = {"溶解"} },
        { ja = "レッドロータス", en = "Red Lotus Blade", sc = {"溶解", "炸裂"} },
        { ja = "フラットブレード", en = "Flat Blade", sc = {"衝撃"} },
        { ja = "シャインブレード", en = "Shining Blade", sc = {"切断"} },
        { ja = "セラフブレード", en = "Seraph Blade", sc = {"切断"} },
        { ja = "サークルブレード", en = "Circle Blade", sc = {"振動", "衝撃"} },
        { ja = "スピリッツウィズイン", en = "Spirits Within", sc = {"属性なし"} },
        { ja = "スウィフトブレード", en = "Swift Blade", sc = {"重力"} },
        { ja = "サンギンブレード", en = "Sanguine Blade", sc = {"属性なし"} },
        { ja = "ナイツオブラウンド", en = "Knights of Round", sc = {"光", "核熱"} },
        { ja = "エクスピアシオン", en = "Expiacion", sc = {"湾曲", "切断"} },
        { ja = "ナイスオブラウンド", en = "Knights of Rotund", sc = {"光"} },
        { ja = "ウリエルブレード", en = "Uriel Blade", sc = {"光", "分解"} },
        { ja = "グローリースラッシュ", en = "Glory Slash", sc = {"光", "核熱"} },
        { ja = "ファストブレードII", en = "Fast Blade II", sc = {"核熱"} },
    },
    ["両手剣"] = {
        { ja = "フィンブルヴェト", en = "Fimbulvetr", sc = {"炸裂", "収縮", "湾曲"} },
        { ja = "デミディエーション", en = "Dimidiation", sc = {"光", "分解"} },
        { ja = "トアクリーバー", en = "Torcleaver", sc = {"光", "湾曲"} },
        { ja = "レゾルーション", en = "Resolution", sc = {"分解", "切断"} },
        { ja = "ハードスラッシュ", en = "Hard Slash", sc = {"切断"} },
        { ja = "パワースラッシュ", en = "Power Slash", sc = {"貫通"} },
        { ja = "フロストバイト", en = "Frostbite", sc = {"硬化"} },
        { ja = "フリーズバイト", en = "Freezebite", sc = {"硬化", "炸裂"} },
        { ja = "ショックウェーブ", en = "Shockwave", sc = {"振動"} },
        { ja = "スピンスラッシュ", en = "Spinning Slash", sc = {"分解"} },
        { ja = "グラウンドストライク", en = "Ground Strike", sc = {"分解", "湾曲"} },
        { ja = "スカージ", en = "Scourge", sc = {"光", "核熱"} },
        { ja = "クレセントムーン", en = "Crescent Moon", sc = {"切断"} },
        { ja = "シックルムーン", en = "Sickle Moon", sc = {"切断", "衝撃"} },
        { ja = "ヘラクレススラッシュ", en = "Herculean Slash", sc = {"硬化", "炸裂", "衝撃"} },
    },
    ["片手斧"] = {
        { ja = "ブリッツ", en = "Blitz", sc = {"溶解", "衝撃", "分解"} },
        { ja = "アバランチアクス", en = "Avalanche Axe", sc = {"切断", "衝撃"} },
        { ja = "ランページ", en = "Rampage", sc = {"切断"} },
        { ja = "カラミティ", en = "Calamity", sc = {"切断", "衝撃"} },
        { ja = "ミストラルアクス", en = "Mistral Axe", sc = {"核熱"} },
        { ja = "デシメーション", en = "Decimation", sc = {"核熱", "振動"} },
        { ja = "ルイネーター", en = "Ruinator", sc = {"湾曲", "炸裂"} },
        { ja = "オンスロート", en = "Onslaught", sc = {"闇", "重力"} },
        { ja = "クラウドスプリッタ", en = "Cloudsplitter", sc = {"闇", "分解"} },
        { ja = "プライマルレンド", en = "Primal Rend", sc = {"重力", "振動"} },
        { ja = "レイジングアクス", en = "Raging Axe", sc = {"炸裂", "衝撃"} },
        { ja = "スマッシュ", en = "Smash Axe", sc = {"硬化", "振動"} },
        { ja = "ラファールアクス", en = "Gale Axe", sc = {"炸裂"} },
        { ja = "スピニングアクス", en = "Spinning Axe", sc = {"溶解", "切断", "衝撃"} },
        { ja = "ボーラアクス", en = "Bora Axe", sc = {"炸裂", "切断"} },
    },
    ["両手斧"] = {
        { ja = "ディザスター", en = "Disaster", sc = {"貫通", "切断", "重力"} },
        { ja = "アップヒーバル", en = "Upheaval", sc = {"核熱", "収縮"} },
        { ja = "ウッコフューリー", en = "Ukko's Fury", sc = {"光", "分解"} },
        { ja = "キングズジャスティス", en = "King's Justice", sc = {"分解", "切断"} },
        { ja = "フェルクリーヴ", en = "Fell Cleave", sc = {"切断", "炸裂", "衝撃"} },
        { ja = "シールドブレイク", en = "Shield Break", sc = {"衝撃"} },
        { ja = "アイアンテンペスト", en = "Iron Tempest", sc = {"切断"} },
        { ja = "フルブレイク", en = "Full Break", sc = {"湾曲"} },
        { ja = "レイジングラッシュ", en = "Raging Rush", sc = {"硬化", "振動"} },
        { ja = "スチールサイクロン", en = "Steel Cyclone", sc = {"湾曲", "炸裂"} },
        { ja = "メタトロントーメント", en = "Metatron Torment", sc = {"光", "核熱"} },
        { ja = "シュトルムヴィント", en = "Sturmwind", sc = {"振動", "切断"} },
        { ja = "アーマーブレイク", en = "Armor Break", sc = {"衝撃"} },
        { ja = "キーンエッジ", en = "Keen Edge", sc = {"収縮"} },
        { ja = "ウェポンブレイク", en = "Weapon Break", sc = {"衝撃"} },
    },
    ["両手鎌"] = {
        { ja = "ジ・オリジン", en = "Origin", sc = {"硬化", "振動", "核熱"} },
        { ja = "クロスリーパー", en = "Cross Reaper", sc = {"湾曲"} },
        { ja = "エントロピー", en = "Entropy", sc = {"重力", "振動"} },
        { ja = "カタストロフィ", en = "Catastrophe", sc = {"闇", "重力"} },
        { ja = "クワイタス", en = "Quietus", sc = {"闇", "湾曲"} },
        { ja = "スライス", en = "Slice", sc = {"切断"} },
        { ja = "ダークハーベスト", en = "Dark Harvest", sc = {"振動"} },
        { ja = "ナイトメアサイス", en = "Nightmare Scythe", sc = {"収縮", "切断"} },
        { ja = "ギロティン", en = "Guillotine", sc = {"硬化"} },
        { ja = "スパイラルヘル", en = "Spiral Hell", sc = {"湾曲", "切断"} },
        { ja = "インサージェンシー", en = "Insurgency", sc = {"核熱", "収縮"} },
        { ja = "インファナルサイズ", en = "Infernal Scythe", sc = {"収縮", "振動"} },
        { ja = "シャドーオブデス", en = "Shadow of Death", sc = {"硬化", "振動"} },
        { ja = "スピニングサイス", en = "Spinning Scythe", sc = {"切断", "振動"} },
        { ja = "ボーパルサイス", en = "Vorpal Scythe", sc = {"貫通", "切断"} },
    },
    ["両手槍"] = {
        { ja = "ダーマット", en = "Diarmuid", sc = {"貫通", "切断", "重力"} },
        { ja = "インパルスドライヴ", en = "Impulse Drive", sc = {"重力", "硬化"} },
        { ja = "カムラン", en = "Camlann's Torment", sc = {"光", "分解"} },
        { ja = "スターダイバー", en = "Stardiver", sc = {"重力", "貫通"} },
        { ja = "雲蒸竜変", en = "Drakesbane", sc = {"核熱", "貫通"} },
        { ja = "ゲイルスコグル", en = "Geirskogul", sc = {"光", "湾曲"} },
        { ja = "ダブルスラスト", en = "Double Thrust", sc = {"貫通"} },
        { ja = "サンダースラスト", en = "Thunder Thrust", sc = {"貫通", "衝撃"} },
        { ja = "ライデンスラスト", en = "Raiden Thrust", sc = {"貫通", "衝撃"} },
        { ja = "足払い", en = "Leg Sweep", sc = {"衝撃"} },
        { ja = "ペンタスラスト", en = "Penta Thrust", sc = {"収縮"} },
        { ja = "ボーパルスラスト", en = "Vorpal Thrust", sc = {"振動", "貫通"} },
        { ja = "大車輪", en = "Wheeling Thrust", sc = {"核熱"} },
        { ja = "ソニックスラスト", en = "Sonic Thrust", sc = {"貫通", "切断"} },
        { ja = "スキュアー", en = "Skewer", sc = {"貫通", "衝撃"} },
    },
    ["片手刀"] = {
        { ja = "是生滅法", en = "Zesho Meppo", sc = {"硬化", "振動", "核熱"} },
        { ja = "臨", en = "Blade: Rin", sc = {"貫通"} },
        { ja = "烈", en = "Blade: Retsu", sc = {"切断"} },
        { ja = "滴", en = "Blade: Teki", sc = {"振動"} },
        { ja = "凍", en = "Blade: To", sc = {"硬化", "炸裂"} },
        { ja = "地", en = "Blade: Chi", sc = {"貫通", "衝撃"} },
        { ja = "影", en = "Blade: Ei", sc = {"収縮"} },
        { ja = "迅", en = "Blade: Jin", sc = {"炸裂", "衝撃"} },
        { ja = "天", en = "Blade: Ten", sc = {"重力"} },
        { ja = "空", en = "Blade: Ku", sc = {"重力", "貫通"} },
        { ja = "生者必滅", en = "Blade: Metsu", sc = {"闇", "分解"} },
        { ja = "カムハブリ", en = "Blade: Kamu", sc = {"分解", "収縮"} },
        { ja = "秘", en = "Blade: Hi", sc = {"闇", "重力"} },
        { ja = "瞬", en = "Blade: Shun", sc = {"核熱", "衝撃"} },
        { ja = "湧", en = "Blade: Yu", sc = {"振動", "切断"} },
    },
    ["両手刀"] = {
        { ja = "絶之太刀・無名", en = "Tachi: Mumei", sc = {"炸裂", "収縮", "湾曲"} },
        { ja = "壱之太刀・燕飛", en = "Tachi: Enpi", sc = {"貫通", "切断"} },
        { ja = "弐之太刀・鋒縛", en = "Tachi: Hobaku", sc = {"硬化"} },
        { ja = "参之太刀・轟天", en = "Tachi: Goten", sc = {"貫通", "衝撃"} },
        { ja = "四之太刀・陽炎", en = "Tachi: Kagero", sc = {"溶解"} },
        { ja = "五之太刀・陣風", en = "Tachi: Jinpu", sc = {"切断", "炸裂"} },
        { ja = "六之太刀・光輝", en = "Tachi: Koki", sc = {"振動", "衝撃"} },
        { ja = "七之太刀・雪風", en = "Tachi: Yukikaze", sc = {"硬化", "炸裂"} },
        { ja = "八之太刀・月光", en = "Tachi: Gekko", sc = {"湾曲", "振動"} },
        { ja = "九之太刀・花車", en = "Tachi: Kasha", sc = {"核熱", "収縮"} },
        { ja = "零之太刀・回天", en = "Tachi: Kaiten", sc = {"光", "分解"} },
        { ja = "十之太刀・乱鴉", en = "Tachi: Rana", sc = {"重力", "硬化"} },
        { ja = "十一之太刀・鳳蝶", en = "Tachi: Ageha", sc = {"収縮", "切断"} },
        { ja = "十二之太刀・照破", en = "Tachi: Shoha", sc = {"分解", "収縮"} },
        { ja = "祖之太刀・不動", en = "Tachi: Fudo", sc = {"光", "湾曲"} },
        { ja = "盛夏之太刀・西瓜割", en = "Tachi: Suikawari", sc = {"核熱"} },
    },
    ["片手棍"] = {
        { ja = "ダグダ", en = "Dagda", sc = {"貫通", "切断", "重力"} },
        { ja = "シャインストライク", en = "Shining Strike", sc = {"衝撃"} },
        { ja = "セラフストライク", en = "Seraph Strike", sc = {"衝撃"} },
        { ja = "ブレインシェイカー", en = "Brainshaker", sc = {"振動"} },
        { ja = "ジャッジメント", en = "Judgment", sc = {"衝撃"} },
        { ja = "ヘキサストライク", en = "Hexa Strike", sc = {"核熱"} },
        { ja = "ブラックヘイロー", en = "Black Halo", sc = {"分解", "収縮"} },
        { ja = "ランドグリース", en = "Randgrith", sc = {"光", "分解"} },
        { ja = "レルムレイザー", en = "Realmrazer", sc = {"核熱", "衝撃"} },
        { ja = "エクズデーション", en = "Exudation", sc = {"闇", "分解"} },
        { ja = "フラッシュノヴァ", en = "Flash Nova", sc = {"硬化", "振動"} },
        { ja = "スカルブレイカー", en = "Skullbreaker", sc = {"硬化", "振動"} },
        { ja = "トゥルーストライク", en = "True Strike", sc = {"炸裂", "衝撃"} },
    },
    ["両手棍"] = {
        { ja = "オシャラ", en = "Oshala", sc = {"硬化", "振動", "核熱"} },
        { ja = "ヘヴィスイング", en = "Heavy Swing", sc = {"衝撃"} },
        { ja = "ロッククラッシャー", en = "Rock Crusher", sc = {"衝撃"} },
        { ja = "アースクラッシャー", en = "Earth Crusher", sc = {"衝撃", "炸裂"} },
        { ja = "スターバースト", en = "Starburst", sc = {"収縮", "振動"} },
        { ja = "サンバースト", en = "Sunburst", sc = {"収縮", "振動"} },
        { ja = "レトリビューション", en = "Retribution", sc = {"重力", "振動"} },
        { ja = "ヴィゾフニル", en = "Vidohunir", sc = {"分解", "湾曲"} },
        { ja = "ガーランドオブブリス", en = "Garland of Bliss", sc = {"核熱", "振動"} },
        { ja = "オムニシエンス", en = "Omniscience", sc = {"重力", "貫通"} },
        { ja = "ミルキル", en = "Myrkr", sc = {"属性なし"} },
        { ja = "カタクリスム", en = "Cataclysm", sc = {"収縮", "振動"} },
        { ja = "シャッターソウル", en = "Shattersoul", sc = {"重力", "硬化"} },
        { ja = "シェルクラッシャー", en = "Shell Crusher", sc = {"炸裂"} },
        { ja = "フルスイング", en = "Full Swing", sc = {"溶解", "衝撃"} },
        { ja = "タルタロスゲート", en = "Gate of Tartarus", sc = {"闇", "湾曲"} },
    },
    ["弓術"] = {
        { ja = "シャルヴ", en = "Sarv", sc = {"貫通", "切断", "重力"} },
        { ja = "フレイミングアロー", en = "Flaming Arrow", sc = {"溶解", "貫通"} },
        { ja = "ピアシングアロー", en = "Piercing Arrow", sc = {"振動", "貫通"} },
        { ja = "ダリングアロー", en = "Dulling Arrow", sc = {"溶解", "貫通"} },
        { ja = "ブラストアロー", en = "Blast Arrow", sc = {"硬化", "貫通"} },
        { ja = "アーチングアロー", en = "Arching Arrow", sc = {"核熱"} },
        { ja = "エンピリアルアロー", en = "Empyreal Arrow", sc = {"核熱", "貫通"} },
        { ja = "南無八幡", en = "Namas Arrow", sc = {"光", "湾曲"} },
        { ja = "リフルジェントアロー", en = "Refulgent Arrow", sc = {"振動", "貫通"} },
        { ja = "ジシュヌの光輝", en = "Jishnu's Radiance", sc = {"光", "核熱"} },
        { ja = "エイペクスアロー", en = "Apex Arrow", sc = {"分解", "貫通"} },
        { ja = "サイドワインダー", en = "Sidewinder", sc = {"振動", "貫通", "炸裂"} },
    },
    ["射撃"] = {
        { ja = "ジ・エンド", en = "Terminus", sc = {"硬化", "振動", "核熱"} },
        { ja = "ホットショット", en = "Hot Shot", sc = {"溶解", "貫通"} },
        { ja = "スプリットショット", en = "Split Shot", sc = {"振動", "貫通"} },
        { ja = "スナイパーショット", en = "Sniper Shot", sc = {"溶解", "貫通"} },
        { ja = "スラッグショット", en = "Slug Shot", sc = {"振動", "貫通", "炸裂"} },
        { ja = "デトネーター", en = "Detonator", sc = {"核熱", "貫通"} },
        { ja = "カラナック", en = "Coronach", sc = {"闇", "分解"} },
        { ja = "トゥルーフライト", en = "Trueflight", sc = {"分解", "切断"} },
        { ja = "レデンサリュート", en = "Leaden Salute", sc = {"重力", "貫通"} },
        { ja = "ワイルドファイア", en = "Wildfire", sc = {"闇", "重力"} },
        { ja = "ラストスタンド", en = "Last Stand", sc = {"核熱", "振動"} },
        { ja = "ブラストショット", en = "Blast Shot", sc = {"硬化", "貫通"} },
        { ja = "ヘヴィショット", en = "Heavy Shot", sc = {"核熱"} },
        { ja = "ナビングショット", en = "Numbing Shot", sc = {"硬化", "炸裂", "衝撃"} },
    }
}

-- PUP オートマトンWS属性辞書
sc_dict.PUP_WS_DATABASE = {
    ["ストリングシュレッダー"] = {"湾曲", "切断"},
    ["ボーンクラッシャー"]     = {"分解"},
    ["カニバルブレード"]       = {"収縮", "振動"},
    ["キメラリパー"]           = {"硬化", "炸裂"},
    ["ストリングクリッパー"]   = {"切断", "衝撃"},
    ["マジックモーター"]       = {"核熱"},
    ["スラップスティック"]     = {"振動", "衝撃"},
    ["ノックアウト"]           = {"切断", "炸裂"},
    ["アーマーシャッタラー"]   = {"核熱", "衝撃"},
    ["アーマーピアッサー"]     = {"重力"},
    ["デイズ"]                 = {"貫通", "衝撃"},
    ["アルクバリスタ"]         = {"溶解", "貫通"}
}

-- SMN 召喚獣「契約の履行」属性辞書
sc_dict.SMN_BP_DATABASE = {
    ["ボルトストライク"]     = {"分解", "切断"}, ["カオスストライク"]   = {"分解", "貫通"},
    ["ショックストライク"]   = {"衝撃"},         ["フレイムクラッシュ"] = {"核熱", "振動"},
    ["バーニングストライク"] = {"衝撃"},         ["パンチ"]             = {"溶解"},
    ["プレデタークロー"]     = {"分解", "切断"}, ["クロー"]             = {"炸裂"},
    ["ラッシュ"]             = {"湾曲", "切断"}, ["ダブルスラップ"]     = {"切断"},
    ["アクスキック"]         = {"硬化"},         ["スピニングダイブ"]   = {"湾曲", "炸裂"},
    ["テールウィップ"]       = {"炸裂"},         ["バラクーダダイブ"]   = {"振動"},
    ["マウンテンバスター"]   = {"重力", "硬化"}, ["クラッグスロー"]     = {"重力", "切断"},
    ["メガリススロー"]       = {"硬化"},         ["ロックバスター"]     = {"振動"},
    ["ロックスロー"]         = {"切断"},         ["エクリプスバイト"]   = {"重力", "切断"},
    ["クレセントファング"]   = {"貫通"},         ["ムーンリットチャージ"] = {"収縮"},
    ["ブラインドサイド"]     = {"重力", "貫通"}, ["カミサドー"]         = {"収縮"},
    ["ヒステリックアサルト"] = {"分解", "貫通"}, ["ラウンドハウス"]     = {"炸裂"},
    ["ウェルト"]             = {"切断"},         ["リーガルガッシュ"]   = {"湾曲", "炸裂"},
    ["リーガルスクラッチ"]   = {"切断"},         ["ポイズンネイル"]     = {"貫通"},
    ["ダブルパンチ"]         = {"収縮"}
}

-- 【万能WS検索関数】全武器種・ペット技・リソース定義から WS 情報を一元検索
function sc_dict.find_ws_info(ws_name, weapon_hint)
    if not ws_name or ws_name == "" then return nil end

    -- 1. 指定された武器種を最優先検索
    if weapon_hint and sc_dict.WEAPON_WS[weapon_hint] then
        for _, info in ipairs(sc_dict.WEAPON_WS[weapon_hint]) do
            if info.ja == ws_name or info.en == ws_name then
                return info
            end
        end
    end

    -- 2. 全武器種カテゴリーから横断検索
    for category, ws_list in pairs(sc_dict.WEAPON_WS) do
        for _, info in ipairs(ws_list) do
            if info.ja == ws_name or info.en == ws_name then
                return info
            end
        end
    end

    -- 3. PUP / SMN データベースから検索
    if sc_dict.PUP_WS_DATABASE[ws_name] then
        return { ja = ws_name, en = ws_name, sc = sc_dict.PUP_WS_DATABASE[ws_name] }
    end
    if sc_dict.SMN_BP_DATABASE[ws_name] then
        return { ja = ws_name, en = ws_name, sc = sc_dict.SMN_BP_DATABASE[ws_name] }
    end

    -- 4. 見つからない場合のデフォルト仮定義
    return { ja = ws_name, en = ws_name, sc = {"核熱", "重力", "分解", "湾曲"} }
end

-- 連携判定関数: 直前の属性 (prev_sc) に WS (ws_info) を打った場合に発生する連携を算出
-- prev_sc は属性名1つ、または優先順の配列 {A1, A2, A3}。
-- 判定順は wiki 準拠: A1+B1, A1+B2, A1+B3 → 不成立なら A2+B1 ... (最初に成立したものを採用)
-- 2連携目以降は前段で発生した連携だけを A1 として渡すこと (前WSの他属性は無視される)
function sc_dict.evaluate_ws_for_sc(ws_info, prev_sc)
    if not ws_info or not ws_info.sc or not prev_sc then return nil end

    local prev_list = type(prev_sc) == "table" and prev_sc or { prev_sc }
    for _, prev_prop in ipairs(prev_list) do
        local map = sc_dict.SC_COMBO_MAP[prev_prop]
        if map then
            for _, ws_prop in ipairs(ws_info.sc) do
                local result = map[ws_prop]
                if result then
                    return {
                        result = result,
                        prev_used = prev_prop,
                        prop_used = ws_prop,
                        level = sc_dict.SC_ELEMENTS[result] and sc_dict.SC_ELEMENTS[result].level or 1
                    }
                end
            end
        end
    end
    return nil
end

function sc_dict.get_ws_properties(ws_name)
    local info = sc_dict.find_ws_info(ws_name, nil)
    return info and info.sc or nil
end

function sc_dict.get_pet_properties(pet_ability_name)
    return sc_dict.PUP_WS_DATABASE[pet_ability_name] or sc_dict.SMN_BP_DATABASE[pet_ability_name]
end

return sc_dict

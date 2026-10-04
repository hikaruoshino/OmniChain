-- =============================================================================
-- sc_dict.lua : 全14武器種 ウェポンスキル ＆ 技連携属性 マトリクス辞書モジュール (v6.0.1)
-- =============================================================================

local sc_dict = {}
local res = pcall(require, 'resources') and require('resources') or nil

-- レベル別連携相関ルールの完全定義
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

-- 連携判定マトリクステーブル (直前の属性 + 新属性 -> 発生連携結果)
sc_dict.SC_COMBO_MAP = {
    ["溶解"] = { ["衝撃"] = "核熱", ["切断"] = "切断" },
    ["硬化"] = { ["振動"] = "湾曲" },
    ["炸裂"] = { ["切断"] = "切断", ["衝撃"] = "分解" },
    ["切断"] = { ["溶解"] = "溶解", ["収縮"] = "重力" },
    ["衝撃"] = { ["溶解"] = "溶解", ["貫通"] = "貫通" },
    ["振動"] = { ["貫通"] = "貫通", ["硬化"] = "硬化" },
    ["貫通"] = { ["硬化"] = "硬化", ["炸裂"] = "炸裂" },
    ["収縮"] = { ["振動"] = "振動" },

    ["核熱"] = { ["分解"] = "光", ["重力"] = "核熱" },
    ["重力"] = { ["湾曲"] = "闇", ["核熱"] = "重力" },
    ["分解"] = { ["核熱"] = "光", ["湾曲"] = "分解" },
    ["湾曲"] = { ["重力"] = "闇", ["分解"] = "湾曲" },

    ["光"]   = { ["光"] = "極光" },
    ["闇"]   = { ["闇"] = "黒闇" },
}

-- 英語属性から日本語属性への変換マップ
sc_dict.EN_TO_JA_SC = {
    ['Light'] = '光', ['Dark'] = '闇',
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

-- 全14武器種 ウェポンスキル ＆ 属性定義
sc_dict.WEAPON_WS = {
    ["格闘"] = {
        { ja = "ビクトリースマイト", en = "Victory Smite", sc = {"光", "分解"} },
        { ja = "四神円舞", en = "Shijin Spiral", sc = {"核熱", "振動"} },
        { ja = "夢想阿修羅拳", en = "Asuran Fists", sc = {"重力", "溶解"} },
        { ja = "闘魂旋風脚", en = "Tornado Kick", sc = {"硬化", "衝撃", "炸裂"} },
        { ja = "ファイナルヘヴン", en = "Final Heaven", sc = {"光", "核熱"} },
        { ja = "アスケーテンツォルン", en = "Ascetic's Fury", sc = {"核熱", "貫通"} },
        { ja = "連環六合圏", en = "Stringing Pummel", sc = {"重力", "溶解"} },
        { ja = "双竜脚", en = "Dragon Kick", sc = {"分解"} },
        { ja = "空鳴拳", en = "Howling Fist", sc = {"貫通", "衝撃"} },
        { ja = "マルカラ", en = "Maru Kala", sc = {"炸裂", "収縮", "湾曲"} },
        { ja = "コンボ", en = "Combo", sc = {"衝撃"} },
        { ja = "タックル", en = "Shoulder Tackle", sc = {"振動", "衝撃"} },
        { ja = "短勁", en = "One Inch Punch", sc = {"収縮"} },
        { ja = "バックハンドブロー", en = "Backhand Blow", sc = {"炸裂"} },
        { ja = "乱撃", en = "Raging Fists", sc = {"衝撃"} },
        { ja = "スピンアタック", en = "Spinning Attack", sc = {"溶解", "衝撃"} },
    },
    ["短剣"] = {
        { ja = "ルドラストーム", en = "Rudra's Storm", sc = {"闇", "湾曲"} },
        { ja = "エヴィサレーション", en = "Evisceration", sc = {"重力", "貫通"} },
        { ja = "イオリアンエッジ", en = "Aeolian Edge", sc = {"炸裂", "切断"} },
        { ja = "マンダリクスタッブ", en = "Mandalic Stab", sc = {"湾曲", "切断"} },
        { ja = "ピリッククレオス", en = "Pyrrhic Kleos", sc = {"湾曲", "切断"} },
        { ja = "マーシーストローク", en = "Mercy Stroke", sc = {"重力", "貫通"} },
        { ja = "モーダントライム", en = "Mordant Rime", sc = {"光", "湾曲"} },
        { ja = "シャークバイト", en = "Shark Bite", sc = {"光", "切断"} },
        { ja = "ダンシングエッジ", en = "Dancing Edge", sc = {"切断", "振動"} },
        { ja = "ワスプスティング", en = "Wasp Sting", sc = {"切断"} },
        { ja = "バイパーバイト", en = "Viper Bite", sc = {"切断"} },
        { ja = "シャドーステッチ", en = "Shadowstitch", sc = {"貫通"} },
        { ja = "ガストスラッシュ", en = "Gust Slash", sc = {"炸裂"} },
        { ja = "サイクロン", en = "Cyclone", sc = {"炸裂", "衝撃"} },
        { ja = "エナジースティール", en = "Energy Steal", sc = {"属性なし"} },
        { ja = "エナジードレイン", en = "Energy Drain", sc = {"属性なし"} },
    },
    ["片手剣"] = {
        { ja = "サベッジブレード", en = "Savage Blade", sc = {"分解", "切断"} },
        { ja = "シャンデュシニュ", en = "Chant du Cygne", sc = {"光", "分解"} },
        { ja = "ロズレーファタール", en = "Rosethorn", sc = {"光", "湾曲"} },
        { ja = "ロイエ", en = "Atonement", sc = {"核熱", "衝撃"} },
        { ja = "レクイエスカット", en = "Requiescat", sc = {"重力", "貫通"} },
        { ja = "ボーパルブレード", en = "Vorpal Blade", sc = {"切断"} },
        { ja = "スウィフトブレード", en = "Swift Blade", sc = {"重力"} },
        { ja = "ナイツオブラウンド", en = "Knights of Round", sc = {"核熱", "切断"} },
        { ja = "サンギンブレード", en = "Sanguine Blade", sc = {"属性なし"} },
        { ja = "ファストブレード", en = "Fast Blade", sc = {"切断"} },
        { ja = "バーニングブレード", en = "Burning Blade", sc = {"溶解"} },
        { ja = "レッドブレード", en = "Red Lotus Blade", sc = {"溶解", "切断"} },
        { ja = "フラットブレード", en = "Flat Blade", sc = {"衝撃"} },
        { ja = "サークルブレード", en = "Circle Blade", sc = {"切断"} },
        { ja = "スピリッツウィズイン", en = "Spirits Within", sc = {"属性なし"} },
    },
    ["両手剣"] = {
        { ja = "デミディエーション", en = "Resolution", sc = {"光", "分解"} },
        { ja = "トアクリーバー", en = "Torcleaver", sc = {"光", "湾曲"} },
        { ja = "レゾルーション", en = "Resolution", sc = {"分解", "切断"} },
        { ja = "スカージ", en = "Scourge", sc = {"核熱", "切断"} },
        { ja = "スピンスラッシュ", en = "Spinning Slash", sc = {"光", "湾曲"} },
        { ja = "グラウンドストライク", en = "Ground Strike", sc = {"湾曲", "分解"} },
        { ja = "ハードスラッシュ", en = "Hard Slash", sc = {"炸裂"} },
        { ja = "パワースラッシュ", en = "Power Slash", sc = {"切断"} },
        { ja = "フロストバイト", en = "Frostbite", sc = {"硬化"} },
        { ja = "フリーズバイト", en = "Freezebite", sc = {"硬化", "切断"} },
        { ja = "ショックウェーブ", en = "Shockwave", sc = {"衝撃", "貫通"} },
        { ja = "スピノサウルス", en = "Spinosaurus", sc = {"貫通"} },
    },
    ["片手斧"] = {
        { ja = "デシメーション", en = "Decimation", sc = {"核熱", "溶解"} },
        { ja = "ルイネーター", en = "Ruinator", sc = {"湾曲", "重力"} },
        { ja = "オンスロート", en = "Onslaught", sc = {"重力", "貫通"} },
        { ja = "クラウドスプリッタ", en = "Cloudsplitter", sc = {"光", "衝撃"} },
        { ja = "ランページ", en = "Rampage", sc = {"重力"} },
        { ja = "カラミティ", en = "Calamity", sc = {"切断"} },
        { ja = "ミストラルアクス", en = "Mistral Axe", sc = {"核熱"} },
        { ja = "アバランシュ", en = "Avalanche", sc = {"硬化"} },
        { ja = "ライノアタック", en = "Rhino Attack", sc = {"衝撃"} },
    },
    ["両手斧"] = {
        { ja = "アップヒーバル", en = "Upheaval", sc = {"闇", "湾曲"} },
        { ja = "ウッコフューリー", en = "Ukko's Fury", sc = {"光", "分解"} },
        { ja = "キングズジャスティス", en = "King's Justice", sc = {"光", "湾曲"} },
        { ja = "フェルクリーヴ", en = "Fell Cleave", sc = {"炸裂", "切断"} },
        { ja = "メタトロントーメント", en = "Metatron Torment", sc = {"核熱", "貫通"} },
        { ja = "スチールサイクロン", en = "Steel Cyclone", sc = {"湾曲", "切断"} },
        { ja = "レイジングラッシュ", en = "Raging Rush", sc = {"貫通", "衝撃"} },
        { ja = "シールドブレイク", en = "Shield Break", sc = {"衝撃"} },
        { ja = "アイアンペスタ", en = "Iron Tempest", sc = {"切断"} },
        { ja = "パワーブレイク", en = "Power Break", sc = {"切断"} },
        { ja = "フルブレイク", en = "Full Break", sc = {"歪曲", "切断"} },
    },
    ["両手鎌"] = {
        { ja = "クロスリーパー", en = "Cross Reaper", sc = {"湾曲", "重力"} },
        { ja = "エントロピー", en = "Entropy", sc = {"重力", "貫通"} },
        { ja = "カタストロフィ", en = "Catastrophe", sc = {"重力", "収縮"} },
        { ja = "クワイタス", en = "Quietus", sc = {"湾曲", "切断"} },
        { ja = "インサージェンシー", en = "Insurgency", sc = {"核熱", "貫通"} },
        { ja = "ギロティン", en = "Guillotine", sc = {"収縮", "貫通"} },
        { ja = "スパイラルヘル", en = "Spiral Hell", sc = {"湾曲", "重力"} },
        { ja = "ナイトメア", en = "Nightmare", sc = {"収縮"} },
        { ja = "スライス", en = "Slice", sc = {"切断"} },
        { ja = "ダークハーベスト", en = "Dark Harvest", sc = {"収縮"} },
        { ja = "シャドーアイ", en = "Shadow of Death", sc = {"収縮", "溶解"} },
    },
    ["両手槍"] = {
        { ja = "インパルスドライヴ", en = "Impulse Drive", sc = {"重力", "貫通"} },
        { ja = "カムラン", en = "Camlann's Torment", sc = {"光", "分解"} },
        { ja = "スターダイバー", en = "Stardiver", sc = {"重力", "貫通"} },
        { ja = "雲蒸竜変", en = "Drakesbane", sc = {"光", "分解"} },
        { ja = "ゲイルスコグル", en = "Geirskogul", sc = {"湾曲"} },
        { ja = "大車輪", en = "Wheeling Thrust", sc = {"核熱"} },
        { ja = "ペンタスラスト", en = "Penta Thrust", sc = {"貫通", "収縮"} },
        { ja = "ダブルスラスト", en = "Double Thrust", sc = {"貫通"} },
        { ja = "サンダースラスト", en = "Thunder Thrust", sc = {"衝撃"} },
        { ja = "ライデンスラスト", en = "Raiden Thrust", sc = {"衝撃", "貫通"} },
        { ja = "ソニックスラスト", en = "Sonic Thrust", sc = {"切断", "貫通"} },
    },
    ["片手刀"] = {
        { ja = "刃・瞬", en = "Blade: Shun", sc = {"分解", "切断"} },
        { ja = "刃・秘", en = "Blade: Hi", sc = {"闇", "重力"} },
        { ja = "刃・迅", en = "Blade: Jin", sc = {"貫通", "炸裂"} },
        { ja = "刃・天", en = "Blade: Ten", sc = {"重力", "切断"} },
        { ja = "刃・空", en = "Blade: Ku", sc = {"重力", "貫通"} },
        { ja = "生者必滅", en = "Blade: Metsu", sc = {"光", "湾曲"} },
        { ja = "刃・臨", en = "Blade: Rin", sc = {"貫通"} },
        { ja = "刃・忍", en = "Blade: Nitsu", sc = {"硬化"} },
        { ja = "刃・地", en = "Blade: Chi", sc = {"振動"} },
    },
    ["両手刀"] = {
        { ja = "祖之太刀・不動", en = "Tachi: Fudo", sc = {"光", "湾曲"} },
        { ja = "十二之太刀・照破", en = "Tachi: Shoha", sc = {"分解", "切断"} },
        { ja = "九之太刀・花車", en = "Tachi: Kasha", sc = {"核熱", "振動"} },
        { ja = "八之太刀・月光", en = "Tachi: Gekko", sc = {"重力", "湾曲"} },
        { ja = "七之太刀・雪風", en = "Tachi: Yukikaze", sc = {"硬化"} },
        { ja = "五之太刀・陣風", en = "Tachi: Jinpu", sc = {"貫通"} },
        { ja = "零之太刀・回天", en = "Tachi: Kaiten", sc = {"光", "湾曲"} },
        { ja = "十之太刀・乱鴉", en = "Tachi: Rana", sc = {"重力", "貫通"} },
        { ja = "太刀・燕飛", en = "Tachi: Enpi", sc = {"貫通"} },
        { ja = "太刀・光輝", en = "Tachi: Koki", sc = {"溶解"} },
    },
    ["片手棍"] = {
        { ja = "ブラックヘイロー", en = "Black Halo", sc = {"重力", "貫通"} },
        { ja = "ヘキサストライク", en = "Hexa Strike", sc = {"核熱"} },
        { ja = "レルムレイザー", en = "Realmrazer", sc = {"核熱"} },
        { ja = "エクズデーション", en = "Exudation", sc = {"分解", "切断"} },
        { ja = "フラッシュノヴァ", en = "Flash Nova", sc = {"属性なし"} },
        { ja = "ランドグリース", en = "Randgrith", sc = {"光", "湾曲"} },
        { ja = "シャインブレイン", en = "Shining Strike", sc = {"衝撃"} },
        { ja = "ヘヴィブレイン", en = "Heavy Strike", sc = {"衝撃"} },
        { ja = "ブレインクラッシュ", en = "Brainshaker", sc = {"衝撃"} },
        { ja = "セラフィストライク", en = "Seraph Strike", sc = {"貫通"} },
        { ja = "ジャッジメント", en = "Judgment", sc = {"核熱"} },
    },
    ["両手棍"] = {
        { ja = "シャッターソウル", en = "Shattersoul", sc = {"分解", "重力"} },
        { ja = "ミルキル", en = "Myrkr", sc = {"属性なし"} },
        { ja = "カタクリスム", en = "Cataclysm", sc = {"属性なし"} },
        { ja = "レトリビューション", en = "Retribution", sc = {"重力", "貫通"} },
        { ja = "オムニシエンス", en = "Omniscience", sc = {"重力", "貫通"} },
        { ja = "ヴィゾフニル", en = "Vidohunir", sc = {"湾曲"} },
        { ja = "ガーランドオブブリス", en = "Garland of Bliss", sc = {"核熱"} },
        { ja = "ヘヴィスイング", en = "Heavy Swing", sc = {"衝撃"} },
        { ja = "ロッククラッシュ", en = "Rock Crusher", sc = {"切断"} },
        { ja = "アースクラッシャー", en = "Earth Crusher", sc = {"切断", "衝撃"} },
        { ja = "スターバースト", en = "Starburst", sc = {"貫通"} },
        { ja = "サンバースト", en = "Sunburst", sc = {"貫通", "衝撃"} },
    },
    ["弓術"] = {
        { ja = "ジシュヌの光輝", en = "Jishnu's Radiance", sc = {"光", "分解"} },
        { ja = "エイペクスアロー", en = "Apex Arrow", sc = {"湾曲", "切断"} },
        { ja = "南無八幡", en = "Namu Arrow", sc = {"核熱"} },
        { ja = "エンピリアルアロー", en = "Empyreal Arrow", sc = {"核熱"} },
        { ja = "フラミングアロー", en = "Flaming Arrow", sc = {"溶解"} },
        { ja = "ピピアロー", en = "Piercing Arrow", sc = {"貫通"} },
        { ja = "ブラストアロー", en = "Dulling Arrow", sc = {"貫通"} },
        { ja = "アーチアロー", en = "Arching Arrow", sc = {"貫通"} },
        { ja = "リフレクアロー", en = "Sidewinder", sc = {"貫通"} },
    },
    ["射撃"] = {
        { ja = "ラストスタンド", en = "Last Stand", sc = {"核熱", "切断"} },
        { ja = "レデンサリュート", en = "Leaden Salute", sc = {"重力", "貫通"} },
        { ja = "ワイルドファイア", en = "Wildfire", sc = {"重力"} },
        { ja = "コロナルフライ", en = "Coronal Fly", sc = {"貫通"} },
        { ja = "ホットショット", en = "Hot Shot", sc = {"溶解"} },
        { ja = "スプリットショット", en = "Split Shot", sc = {"貫通"} },
        { ja = "スナイパーショット", en = "Sniper Shot", sc = {"貫通"} },
        { ja = "スラッグショット", en = "Slug Shot", sc = {"貫通"} },
        { ja = "デトネーター", en = "Detonator", sc = {"核熱"} },
    }
}

-- 【万能WS検索関数】全武器種・リソース定義から WS 情報を一元検索
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

    -- 3. Windower リソース (res.weapon_skills) からの動的フォールバック検索
    if res and res.weapon_skills then
        for _, ws_res in pairs(res.weapon_skills) do
            if ws_res.japanese == ws_name or ws_res.name == ws_name or ws_res.en == ws_name then
                local props = {}
                if ws_res.skillchain_a and sc_dict.EN_TO_JA_SC[ws_res.skillchain_a] then
                    table.insert(props, sc_dict.EN_TO_JA_SC[ws_res.skillchain_a])
                end
                if ws_res.skillchain_b and sc_dict.EN_TO_JA_SC[ws_res.skillchain_b] then
                    table.insert(props, sc_dict.EN_TO_JA_SC[ws_res.skillchain_b])
                end
                if ws_res.skillchain_c and sc_dict.EN_TO_JA_SC[ws_res.skillchain_c] then
                    table.insert(props, sc_dict.EN_TO_JA_SC[ws_res.skillchain_c])
                end
                if #props == 0 then table.insert(props, "属性なし") end
                return { ja = ws_res.japanese or ws_res.name, en = ws_res.name, sc = props }
            end
        end
    end

    -- 4. 見つからない場合のデフォルト仮定義
    return { ja = ws_name, en = ws_name, sc = {"核熱", "重力", "分解", "湾曲"} }
end

-- 連携判定関数: 直前の属性 (prev_sc) に WS (ws_info) を打った場合のベスト発生連携を算出
function sc_dict.evaluate_ws_for_sc(ws_info, prev_sc)
    if not ws_info or not ws_info.sc or not prev_sc then return nil end
    
    local map = sc_dict.SC_COMBO_MAP[prev_sc]
    if not map then return nil end
    
    for _, ws_prop in ipairs(ws_info.sc) do
        if map[ws_prop] then
            return {
                result = map[ws_prop],
                prop_used = ws_prop,
                level = sc_dict.SC_ELEMENTS[map[ws_prop]] and sc_dict.SC_ELEMENTS[map[ws_prop]].level or 1
            }
        end
    end
    return nil
end

return sc_dict

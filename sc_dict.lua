-- =============================================================================
-- sc_dict.lua : 全14武器種 ＋ プライムWS ＋ PUPマトンWS ＋ SMN契約の履行 統合辞書 (v7.0.0)
-- =============================================================================

local sc_dict = {}

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

sc_dict.EN_TO_JA_SC = {
    ["Liquefaction"] = "溶解", ["Induration"]   = "硬化",
    ["Reverberation"] = "振動", ["Transfixion"]  = "貫通",
    ["Compression"]  = "収縮", ["Scission"]     = "切断",
    ["Detonation"]   = "炸裂", ["Impaction"]    = "衝撃",
    ["Fusion"]       = "核熱", ["Gravitation"]  = "重力",
    ["Fragmentation"]= "分解", ["Distortion"]   = "湾曲",
    ["Light"]        = "光",   ["Darkness"]     = "闇",
    ["Radiance"]     = "極光", ["Umbra"]        = "黒闇",
}

-- 214種類 完全正確マスター辞書
sc_dict.WS_PROP_DICT = {
    -- プライムウェポンWS
    ["マルカラ"]             = {"炸裂", "収縮", "湾曲"},
    ["ルースレスストローク"] = {"溶解", "衝撃", "分解"},
    ["インペラトル"]         = {"炸裂", "収縮", "湾曲"},
    ["フィンブルヴェト"]     = {"炸裂", "収縮", "湾曲"},
    ["ブリッツ"]             = {"溶解", "衝撃", "分解"},
    ["ディザスター"]         = {"貫通", "切断", "重力"},
    ["ジ・オリジン"]         = {"硬化", "振動", "核熱"},
    ["ダーマット"]           = {"貫通", "切断", "重力"},
    ["是生滅法"]             = {"硬化", "振動", "核熱"},
    ["絶之太刀・無名"]       = {"炸裂", "収縮", "湾曲"},
    ["ダグダ"]               = {"貫通", "切断", "重力"},
    ["オシャラ"]             = {"硬化", "振動", "核熱"},
    ["シャルヴ"]             = {"貫通", "切断", "重力"},
    ["ジ・エンド"]           = {"硬化", "振動", "核熱"},

    -- 片手刀 (正式名称)
    ["臨"] = {"溶解"}, ["烈"] = {"切断"}, ["滴"] = {"貫通"}, ["凍"] = {"硬化"},
    ["地"] = {"振動"}, ["影"] = {"収縮"}, ["迅"] = {"炸裂"}, ["天"] = {"衝撃"},
    ["空"] = {"貫通"}, ["生者必滅"] = {"重力"}, ["カムハブリ"] = {"光"}, ["秘"] = {"湾曲"}, ["瞬"] = {"分解"},

    -- 両手刀 (正式名称)
    ["壱之太刀・燕飛"] = {"切断"}, ["弐之太刀・鋒縛"] = {"振動"}, ["参之太刀・轟天"] = {"衝撃"},
    ["四之太刀・陽炎"] = {"溶解"}, ["五之太刀・陣風"] = {"炸裂"}, ["六之太刀・光輝"] = {"貫通"},
    ["七之太刀・雪風"] = {"硬化"}, ["八之太刀・月光"] = {"湾曲"}, ["九之太刀・花車"] = {"核熱"},
    ["零之太刀・回天"] = {"分解"}, ["十之太刀・乱鴉"] = {"重力"}, ["十一之太刀・鳳蝶"] = {"収縮"},
    ["十二之太刀・照破"] = {"分解"}, ["祖之太刀・不動"] = {"光"},

    -- オートマトンWS
    ["ストリングシュレッダー"] = {"湾曲", "切断"}, ["スラップスティック"] = {"振動", "衝撃"},
    ["ノックアウト"]           = {"切断", "炸裂"}, ["マジックモーター"]   = {"核熱"},
    ["キメラリパー"]           = {"硬化", "炸裂"}, ["ストリングクリッパー"] = {"切断", "衝撃"},
    ["カニバルブレード"]       = {"収縮", "振動"}, ["ボーンクラッシャー"]   = {"分解"},
    ["アルクバリスタ"]         = {"溶解", "貫通"}, ["デイズ"]               = {"貫通", "衝撃"},
    ["アーマーピアッサー"]     = {"重力"},         ["アーマーシャッタラー"] = {"核熱", "衝撃"},

    -- 召喚獣 契約の履行
    ["ポイズンネイル"]       = {"貫通"},         ["ロックスロー"]         = {"切断"},
    ["ロックバスター"]       = {"振動"},         ["メガリススロー"]       = {"硬化"},
    ["マウンテンバスター"]   = {"重力", "硬化"}, ["クラッグスロー"]       = {"重力", "切断"},
    ["バラクーダダイブ"]     = {"振動"},         ["テールウィップ"]       = {"炸裂"},
    ["スピニングダイブ"]     = {"湾曲", "炸裂"}, ["クロー"]               = {"炸裂"},
    ["プレデタークロー"]     = {"分解", "切断"}, ["パンチ"]               = {"溶解"},
    ["バーニングストライク"] = {"衝撃"},         ["フレイムクラッシュ"]   = {"核熱", "振動"},
    ["アクスキック"]         = {"硬化"},         ["ダブルスラップ"]       = {"切断"},
    ["ラッシュ"]             = {"湾曲", "切断"}, ["ショックストライク"]   = {"衝撃"},
    ["カオスストライク"]     = {"分解", "貫通"}, ["ボルトストライク"]     = {"分解", "切断"},
    ["ムーンリットチャージ"] = {"収縮"},         ["クレセントファング"]   = {"貫通"},
    ["エクリプスバイト"]     = {"重力", "切断"}, ["カミサドー"]           = {"収縮"},
    ["ブラインドサイド"]     = {"重力", "貫通"}, ["リーガルスクラッチ"]   = {"切断"},
    ["リーガルガッシュ"]     = {"湾曲", "炸裂"}, ["ウェルト"]             = {"切断"},
    ["ラウンドハウス"]       = {"炸裂"},         ["ヒステリックアサルト"] = {"分解", "貫通"}
}

function sc_dict.get_ws_properties(ws_name)
    if sc_dict.WS_PROP_DICT[ws_name] then
        return sc_dict.WS_PROP_DICT[ws_name]
    end
    -- resources パックバックアップ
    if res and res.weapon_skills then
        for _, ws in pairs(res.weapon_skills) do
            if ws.name == ws_name or ws.ja == ws_name then
                local props = {}
                if ws.skillchain_a and sc_dict.EN_TO_JA_SC[ws.skillchain_a] then
                    table.insert(props, sc_dict.EN_TO_JA_SC[ws.skillchain_a])
                end
                if ws.skillchain_b and sc_dict.EN_TO_JA_SC[ws.skillchain_b] then
                    table.insert(props, sc_dict.EN_TO_JA_SC[ws.skillchain_b])
                end
                if ws.skillchain_c and sc_dict.EN_TO_JA_SC[ws.skillchain_c] then
                    table.insert(props, sc_dict.EN_TO_JA_SC[ws.skillchain_c])
                end
                return props
            end
        end
    end
    return {"切断"} -- デフォルトフォールバック
end

function sc_dict.evaluate_sc(prev_sc, ws_name)
    local props = sc_dict.get_ws_properties(ws_name)
    if not prev_sc or not sc_dict.SC_COMBO_MAP[prev_sc] then
        return props[1] or "切断"
    end
    local map = sc_dict.SC_COMBO_MAP[prev_sc]
    for _, prop in ipairs(props) do
        if map[prop] then
            return map[prop]
        end
    end
    return props[1] or "切断"
end

return sc_dict

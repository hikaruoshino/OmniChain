-- =============================================================================
-- OmniChain.lua : 全22ジョブ ＆ 全14武器種対応 自動技連携アドオン (v7.4.2 - 同じ敵を狙う人が多いときの最大威力)
-- =============================================================================

_addon.name     = "OmniChain"
_addon.author   = "hikaruoshino"
_addon.version  = "7.4.2"
_addon.commands = {"omni", "omnichain"}

require("luau")
local config  = require("config")
local texts   = require("texts")
local res     = require("resources")
local packets = require("packets")
local sc_dict = require("sc_dict")

-- 100%安全な数値キャスト関数 (文字 vs 数値の比較エラー絶対防止)
local function safe_num(v, default_val)
    if type(v) == "number" then return v end
    if type(v) == "string" then
        local n = tonumber(v)
        if n then return n end
    end
    return default_val or 0
end

-- 安全な比較演算子ヘルパー関数
local function safe_gte(a, b) return safe_num(a, 0) >= safe_num(b, 0) end
local function safe_gt(a, b)  return safe_num(a, 0) >  safe_num(b, 0) end
local function safe_lte(a, b) return safe_num(a, 0) <= safe_num(b, 0) end
local function safe_lt(a, b)  return safe_num(a, 0) <  safe_num(b, 0) end

-- チャット出力用 Shift-JIS 変換ヘルパー関数
local function chat_msg(msg, color)
    color = color or 207
    if windower and windower.to_shift_jis then
        local ok, converted = pcall(windower.to_shift_jis, tostring(msg))
        if ok and converted then
            windower.add_to_chat(color, converted)
            return
        end
    end
    windower.add_to_chat(color, tostring(msg))
end

-- デフォルト設定 (data/settings.xml)
local defaults = {}
defaults.enabled = true
defaults.show_hud = false -- 初期起動時はHUD非表示
defaults.debug_logging = true -- 個人用デバッグログ記録有効
defaults.min_tp = 1000
defaults.party_sync = true
defaults.auto_mode = "flexible" -- "flexible", "strict", "lead_only"
defaults.wait_delay = 1.2
defaults.start_mode = "auto"  -- "auto": 1回目も自動 / "manual": 1回目は自分 (誰かの始点に続けて自動連携)
defaults.follow_wait = 6.0    -- manual: 直前のWSが当たってから自動WSを撃つまでの秒数 (他人の横槍を待つ)
defaults.open_player = 3.3    -- 前の WS が自分・PT の人 (フェイス以外) のとき、受付が開くまでと見なす秒数 (試験用。フェイスは 3.3 秒のまま)
defaults.focus_people = 3     -- 同じ敵を狙っている人が、自分を含めてこの人数以上のとき、最大威力の WS (2 人なら普通に連携のほうが強い)
defaults.focus_tp = 1500       -- 最大威力の WS を撃つ TP
defaults.focus_max = true      -- 同じ敵を PT の人全員が狙っているときは、連携・トスをやめて一番威力の高い WS を撃つ (侍)
defaults.toss = true          -- PT の人の次の WS を予測し、近いときはその人が連携しやすい属性になる WS を選ぶ
defaults.ws_reach = 3.5       -- 近接 WS (射程 2) を撃ってよい距離。distanceplus に出る数字 (敵の大きさは引かない)
defaults.min_follow = 4.0     -- 直前のWS (誰のものでも) が当たってから、次の自動WSを撃つまでの最短秒数 (連携の受付が開くのを待つ)
-- フェイスの一人連携待ち (イロハ・ノユリ・ギルガメッシュ・アークGK。テンゼンは待たない)
defaults.trust_solo = true        -- 一人連携を狙うフェイスが条件のアビリティを使ったら、終わるまで自動WSを撃たない
defaults.solo_start_wait = 12.0   -- アビリティを使ってから最初のWSが出るまで待つ秒数 (出なければ待つのをやめる)
defaults.solo_gap = 11.0          -- フェイスのWSから次のWSまで待つ秒数 (これを過ぎたら一人連携は終わりとみなす。実測: イロハは約 10 秒間隔)
defaults.pos = {x = 500, y = 350}
defaults.text = {font = "Meiryo", size = 11, alpha = 255}
defaults.bg = {alpha = 180, red = 10, green = 10, blue = 15}
defaults.padding = 6

-- ジョブごとの武器種・WS優先リストの既定値 (omnichain_config.json があればその内容で上書きする)
-- settings.xml には保存しない: config ライブラリは XML の <1> などの番号を文字として読むため、
-- 既定値より長いリストが保存されると番号が数字と文字で混ざり、次の読み込み時の保存でエラーになる
local profiles = {
    ['WAR'] = { weapon = '両手斧', ws_priority = {'ディザスター', 'アップヒーバル', 'ウッコフューリー', 'キングズジャスティス', 'フェルクリーヴ', 'シュトルムヴィント', 'アーマーブレイク', 'キーンエッジ', 'ウェポンブレイク'} },
    ['PLD'] = { weapon = '片手剣', ws_priority = {'インペラトル', 'サベッジブレード', 'シャンデュシニュ', 'ボーパルブレード', 'ロイエ'} },
    ['SAM'] = { weapon = '両手刀', ws_priority = {'絶之太刀・無名', '祖之太刀・不動', '十二之太刀・照破', '九之太刀・花車'} },
    ['THF'] = { weapon = '短剣', ws_priority = {'ルースレスストローク', 'ルドラストーム', 'エヴィサレーション', 'イオリアンエッジ'} },
    ['DRK'] = { weapon = '両手鎌', ws_priority = {'ジ・オリジン', 'クロスリーパー', 'エントロピー', 'カタストロフィ', 'シャドーオブデス', 'スピニングサイス', 'ボーパルサイス'} },
    ['RNG'] = { weapon = '弓術', ws_priority = {'シャルヴ', 'ジシュヌの光輝', 'エイペクスアロー', '南無八幡', 'サイドワインダー'} },
    ['NIN'] = { weapon = '片手刀', ws_priority = {'是生滅法', '瞬', '秘', '迅', '湧'} },
    ['DRG'] = { weapon = '両手槍', ws_priority = {'ダーマット', 'インパルスドライヴ', 'カムラン', 'スターダイバー', 'スキュアー'} },
    ['MNK'] = { weapon = '格闘', ws_priority = {'マルカラ', 'ビクトリースマイト', '四神円舞', '夢想阿修羅拳'} },
    ['RDM'] = { weapon = '片手剣', ws_priority = {'インペラトル', 'サベッジブレード', 'シャンデュシニュ', 'ロズレーファタール', 'サンギンブレード'} },
    ['BLU'] = { weapon = '片手剣', ws_priority = {'インペラトル', 'サベッジブレード', 'シャンデュシニュ', 'レクイエスカット'} },
    ['COR'] = { weapon = '射撃', ws_priority = {'ジ・エンド', 'レデンサリュート', 'ラストスタンド', 'ワイルドファイア', 'ブラストショット', 'ヘヴィショット', 'ナビングショット'} },
    ['DNC'] = { weapon = '短剣', ws_priority = {'ルースレスストローク', 'ピリッククレオス', 'ルドラストーム', 'エヴィサレーション'} },
    ['RUN'] = { weapon = '両手剣', ws_priority = {'フィンブルヴェト', 'デミディエーション', 'トアクリーバー', 'レゾルーション', 'クレセントムーン', 'シックルムーン', 'ヘラクレススラッシュ'} },
    ['BST'] = { weapon = '片手斧', ws_priority = {'ブリッツ', 'ルイネーター', 'デシメーション', 'クラウドスプリッタ', 'レイジングアクス', 'スマッシュ', 'ラファールアクス', 'スピニングアクス', 'ボーラアクス'} },
    ['BRD'] = { weapon = '短剣', ws_priority = {'ルースレスストローク', 'ルドラストーム', 'モーダントライム', 'イオリアンエッジ'} },
    ['PUP'] = { weapon = '格闘', ws_priority = {'マルカラ', 'ビクトリースマイト', 'ストリングシュレッダー', 'ボーンクラッシャー', 'アーマーシャッタラー'} },
    ['SCH'] = { weapon = '両手棍', ws_priority = {'オシャラ', 'ガーランドオブブリス', 'ミルキル', 'カタクリスム', 'シェルクラッシャー', 'フルスイング', 'タルタロスゲート'} },
    ['GEO'] = { weapon = '片手棍', ws_priority = {'ダグダ', 'ブラックヘイロー', 'レルムレイザー', 'フラッシュノヴァ', 'スカルブレイカー', 'トゥルーストライク'} },
    ['WHM'] = { weapon = '片手棍', ws_priority = {'ダグダ', 'ヘキサストライク', 'ブラックヘイロー', 'レルムレイザー', 'スカルブレイカー', 'トゥルーストライク'} },
    ['BLM'] = { weapon = '両手棍', ws_priority = {'オシャラ', 'ヴィゾフニル', 'ミルキル', 'カタクリスム', 'シェルクラッシャー', 'フルスイング', 'タルタロスゲート'} },
    ['SMN'] = { weapon = '両手棍', ws_priority = {'ボルトストライク', 'フレイムクラッシュ', 'プレデタークロー', 'ガーランドオブブリス', 'シェルクラッシャー', 'フルスイング', 'タルタロスゲート'} }
}

local settings = config.load(defaults)

-- カラーコード装飾 (DirectWrite UTF-8)
local function color_text(str, r, g, b)
    return string.format("\\cs(%d,%d,%d)%s\\cr",safe_num(r, 255), safe_num(g, 255), safe_num(b, 255), tostring(str or ""))
end

-- -----------------------------------------------------------------------------
-- ログ記録 (omnichain_debug.log)
--   ・ログはメモリに溜めて数秒ごとにまとめて書く (毎回の open/close を避ける)
--   ・1MB を超えたら omnichain_debug.old.log に退避する
--   ・ERROR / WARN はその場でチャットに出す (同じ内容は10秒間まとめる)
--   ・直近の出来事はメモリにも残し、//omni log tail で見られる
-- -----------------------------------------------------------------------------
local log_file_path = windower.addon_path .. "omnichain_debug.log"
local old_log_path  = windower.addon_path .. "omnichain_debug.old.log"
local LOG_MAX_BYTES = 1024 * 1024
local LOG_FLUSH_SEC = 2.0
local RECENT_MAX    = 200

local monitor = {
    buffer = {},          -- ファイルへ未書き込みの行
    last_flush = 0,
    recent = {},          -- 直近の出来事 {time, level, cat, msg}
    counts = {ERROR = 0, WARN = 0, INFO = 0},
    throttle = {},        -- チャット表示の間引き: key -> {time, suppressed}
}

local LEVEL_CHAT_COLORS = {ERROR = 167, WARN = 159}

local function flush_log(force)
    local buf = monitor.buffer
    monitor.last_flush = os.clock()
    if #buf == 0 then return end
    if not settings.debug_logging then
        monitor.buffer = {}
        return
    end
    local f = io.open(log_file_path, "a")
    if not f then return end
    f:write(table.concat(buf, "\n"), "\n")
    local size = f:seek("end") or 0
    f:close()
    monitor.buffer = {}
    if size > LOG_MAX_BYTES then
        os.remove(old_log_path)
        os.rename(log_file_path, old_log_path)
    end
end

-- UTF-8 を文字単位で切り詰める (オーバーレイの1行を短くするため)
local function utf8_trim(str, max_chars)
    local count, out = 0, {}
    for ch in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > max_chars then
            out[#out + 1] = "…"
            break
        end
        out[#out + 1] = ch
    end
    return table.concat(out)
end

local function log_event(level, category, message)
    level = level or "INFO"
    category = tostring(category)
    message = tostring(message)
    monitor.counts[level] = (monitor.counts[level] or 0) + 1

    local is_alert = (level == "ERROR" or level == "WARN")
    if is_alert then
        -- 同じ内容が10秒以内に続いたら記録もチャットも省き、次に出すとき回数を添える
        local key = level .. category .. message
        local t = monitor.throttle[key]
        local clock = os.clock()
        if t and clock - t.time < 10 then
            t.suppressed = t.suppressed + 1
            return false
        end
        if t and t.suppressed > 0 then
            message = message .. string.format(" (直前10秒に他 %d 回)", t.suppressed)
        end
        monitor.throttle[key] = {time = clock, suppressed = 0}
    end

    monitor.buffer[#monitor.buffer + 1] = string.format("[%s] [%s] [%s] %s", os.date("%Y-%m-%d %H:%M:%S"), level, category, message)

    local recent = monitor.recent
    recent[#recent + 1] = {time = os.date("%H:%M:%S"), level = level, cat = category, msg = message}
    if #recent > RECENT_MAX then table.remove(recent, 1) end

    if is_alert then
        -- 失敗原因を失わないよう、エラー系はすぐ書き出す
        flush_log(true)
        chat_msg(string.format("[OmniChain:%s] %s: %s", level, category, utf8_trim(message, 120)), LEVEL_CHAT_COLORS[level])
    elseif #monitor.buffer >= 50 then
        flush_log(true)
    end
    return true
end

-- 既存呼び出し互換 (INFO)
local function log_debug(category, message)
    log_event("INFO", category, message)
end

-- イベント処理を xpcall で包み、エラー時はスタックトレースごと記録する
local traceback = (debug and debug.traceback) or tostring
local function guarded(name, fn)
    return function(...)
        local args, n = {...}, select("#", ...)
        local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, traceback)
        if not ok then
            local first_line = tostring(err):match("^[^\n]*") or tostring(err)
            -- トレースはファイルにだけ残す (チャットを埋めないため)
            if log_event("ERROR", name, first_line) then
                monitor.buffer[#monitor.buffer + 1] = tostring(err)
                flush_log(true)
            end
        end
    end
end

-- アクションメッセージID → 失敗理由 (res/action_messages.lua には英語しか無いため主要なものを和訳)
local FAIL_MESSAGES = {
    [4]   = "対象が射程外",
    [5]   = "対象が見えない",
    [12]  = "他人がクレーム済み",
    [71]  = "その行動は取れない",
    [78]  = "対象が遠すぎる",
    [89]  = "WSを使えない",
    [90]  = "WSを使えない",
    [190] = "そのWSは使えない (武器不一致/未習得)",
    [191] = "WSを使えない状態",
    [192] = "TPが足りない",
    [193] = "その対象には使えない",
    [216] = "遠隔武器を装備していない",
    [217] = "対象が見えない",
    [218] = "移動して構えが解けた",
    [219] = "対象が見えない",
    [316] = "このエリアでは使えない",
    [328] = "対象が遠すぎる",
    [446] = "攻撃できない対象",
}


-- WS優先リストを文字列のみの配列に正規化 (不正な型は空配列)
-- settings.xml の <1>…<n> は既定値を超える分が文字列キー "5" 等で残るため、数値化して並べ直す
local function sanitize_ws_list(list)
    local result = {}
    if type(list) ~= "table" then return result end
    local indexed = {}
    for k, name in pairs(list) do
        local idx = tonumber(k)
        if idx and type(name) == "string" and name ~= "" then
            table.insert(indexed, {idx = idx, name = name})
        end
    end
    table.sort(indexed, function(a, b) return a.idx < b.idx end)
    for _, item in ipairs(indexed) do
        table.insert(result, item.name)
    end
    return result
end

-- Web Config Editor エクスポートファイル (omnichain_config.json) の自動読み込み処理
local function load_external_json_config()
    local json_paths = {
        windower.addon_path .. "omnichain_config.json",
        windower.addon_path .. "data/omnichain_config.json",
    }

    for _, path in ipairs(json_paths) do
        local f = io.open(path, "r")
        if f then
            local content = f:read("*all")
            f:close()
            if content and content ~= "" then
                local jok, json = pcall(require, "json")
                if jok and json and json.parse then
                    -- Windower の libs/json.lua は decode ではなく parse (失敗時は nil, エラー文)
                    local parse_ok, res_obj, parse_err = pcall(json.parse, content)
                    if not parse_ok or type(res_obj) ~= "table" then
                        log_event("WARN", "CONFIG", string.format("JSON parse failed (%s): %s", path, tostring(parse_ok and parse_err or res_obj)))
                    else
                        if res_obj.min_tp ~= nil then
                            settings.min_tp = safe_num(res_obj.min_tp, 1000)
                        end
                        if res_obj.wait_delay ~= nil then
                            settings.wait_delay = safe_num(res_obj.wait_delay, 1.2)
                        end
                        if res_obj.profiles and type(res_obj.profiles) == "table" then
                            for job, data in pairs(res_obj.profiles) do
                                local ws_list = type(data) == "table" and sanitize_ws_list(data.ws_priority) or {}
                                if data.weapon and #ws_list > 0 then
                                    profiles[job] = {
                                        weapon = tostring(data.weapon),
                                        ws_priority = ws_list,
                                        opener_only = data.opener_only == true
                                    }
                                end
                            end
                        end
                        log_debug("CONFIG", "Loaded external JSON config successfully from: " .. path)
                        return true
                    end
                end
            end
        end
    end
    return false
end

local state = {
    active_job = "WAR",
    active_weapon = "両手斧",
    ws_priority = {"ディザスター", "アップヒーバル", "ウッコフューリー"},

    sc_active = false,
    sc_property = nil,   -- 表示用 (例: "分解/切断")
    sc_props = nil,      -- 判定用の属性配列 (初段WSは {A1, A2, A3}、連携発生後は {発生した連携})
    sc_expiration = 0,
    sc_starter = "",
    sc_target = nil,        -- 連携が付いている敵の ID (別の敵を殴っているときは連携窓として扱わない)
    sc_start_time = 0,      -- 始点・連携のWSが当たった時刻 (manual の待ち時間の起点)
    sc_step = 0,            -- 今の連携窓までに連携が続いた回数 (始点 = 0)。続くほど受付が短くなる
    sc_aeonic = false,      -- 今の連携窓の始点が、自分のイオニックWS (アフターマスの光/闇つき) か
    last_chain_name = nil,  -- パケットとチャットで同じ連携を二重に処理しないための記録
    last_chain_time = 0,
    last_packet_sc_time = -100,  -- パケットで連携状態を更新した時刻 (遅れて届くチャットの上書きを防ぐ)

    last_ws_time = 0,
    pending_ws = nil,       -- 自動実行したWSの結果待ち {name, time, tp}
    player_id = nil,

    solos = {},             -- フェイスの一人連携待ち: [フェイスの ID] = {name = 表示名, ability = きっかけ, until_time = 期限, count = WS数}
                            -- フェイスを何人か呼んでいると同時に複数になる。1 人でも残っていれば自動WSを止める
}

-- 自動実行したWSの応答が無いまま、この秒数を過ぎたら警告する (WS名の誤り・未習得・入力エラー等)
local PENDING_WS_TIMEOUT = 4.0

-- sc_dict に載っているか (find_ws_info は未登録でも既定値を返すため別に調べる)
local function ws_in_dict(ws_name)
    for _, ws_list in pairs(sc_dict.WEAPON_WS) do
        for _, info in ipairs(ws_list) do
            if info.ja == ws_name or info.en == ws_name then return true end
        end
    end
    return sc_dict.PUP_WS_DATABASE[ws_name] ~= nil or sc_dict.SMN_BP_DATABASE[ws_name] ~= nil
end

-- 日本語/英語WS名 → res の WS ID
local ws_id_cache = {}
local function ws_id_by_name(ws_name)
    if ws_id_cache[ws_name] ~= nil then return ws_id_cache[ws_name] or nil end
    local found = false
    if res and res.weapon_skills then
        for id, ws in pairs(res.weapon_skills) do
            if ws.ja == ws_name or ws.en == ws_name then found = id break end
        end
    end
    ws_id_cache[ws_name] = found
    return found or nil
end

-- WS が届く距離か。届かない距離では撃たない (撃っても「対象が遠い」で空振りする)。
-- 近接 WS (射程 2) は distanceplus に出る距離が settings.ws_reach (既定 3.5) 以下のとき (作者の経験則)。
-- それ以外の射程は distanceplus と同じ式: 距離 < 敵の model_size + 射程 × 補正 + 自分の model_size (射程の番号は res の range)
local WS_RANGE_MULT = {
    [2] = 1.55, [3] = 1.490909, [4] = 1.44, [5] = 1.377778, [6] = 1.30, [7] = 1.15,
    [8] = 1.25, [9] = 1.377778, [10] = 1.45, [11] = 1.454545454545455, [12] = 1.666666666666667,
}
local WS_RANGE_MARGIN = 0.2   -- 境目で入力が間に合わず空振りしないよう、届く距離より少し内側を使う
-- 近接 WS (射程 2) は、固定の ws_reach (既定 3.5) 以下のとき。敵の model_size が 2 を超える大きな敵は、超えた分だけ広げる
-- 戻り値: 届くなら true, 届かないなら false と (距離, 届く距離)。調べられないときは true
local function ws_in_range(ws_name)
    local id = ws_id_by_name(ws_name)
    local ws = id and res and res.weapon_skills and res.weapon_skills[id]
    local mult = ws and WS_RANGE_MULT[ws.range]
    if not mult then return true end
    local t = windower.ffxi.get_mob_by_target('t')
    if ws.range == 2 then
        if not t or not t.distance then return true end
        local melee_reach = safe_num(settings.ws_reach, 3.5)
        local d = math.sqrt(safe_num(t.distance, 0))
        -- 大きな敵は、体の分だけ遠くから届く。敵の model_size が 2 を超えた分だけ、撃ってよい距離を広げる
        -- (小さい敵・普通の敵は今までの固定値のまま。2026-10-24 Awoken Gorgimera: 距離 4.5 で手動の WS は通ったのに、3.5 の固定値で撃たず止まった)
        if t.model_size then
            local extra = safe_num(t.model_size, 0) - 2.0
            if extra > 0 then melee_reach = melee_reach + extra end
        end
        return d <= melee_reach, d, melee_reach
    end
    local me = windower.ffxi.get_mob_by_target('me') or windower.ffxi.get_player()
    if not t or not t.distance or not t.model_size then return true end
    local my_size = safe_num(me and me.model_size, 0)
    local dist = math.sqrt(safe_num(t.distance, 0))
    local reach = t.model_size + ws.range * mult + my_size - WS_RANGE_MARGIN
    return dist <= reach, dist, reach
end

-- 装備中の武器の英語名 {main=, range=}。HUD が毎フレーム呼ぶため1秒だけ使い回す
local weapon_cache = {time = -1, names = {}}
local function equipped_weapon_names()
    local now = os.clock()
    if now - weapon_cache.time < 1.0 then return weapon_cache.names end
    weapon_cache.time = now
    local names = {}
    local eq = windower.ffxi.get_items('equipment')
    for _, slot in ipairs({'main', 'range'}) do
        local index = eq and eq[slot]
        if index and index ~= 0 then
            local item = windower.ffxi.get_items(eq[slot .. '_bag'], index)
            local info = item and res and res.items and res.items[item.id]
            names[slot] = info and info.en
            names[slot .. '_ja'] = info and info.ja
        end
    end
    weapon_cache.names = names
    return names
end

-- 自分がイオニック武器でそのWSを撃つときに加わる Lv3 属性 (光/闇)。該当しなければ nil
-- 自分のWSは TP1000 以上で撃つため、撃った時点で必ずアフターマスが付く (発動したWS自身にも属性が付く)
local function aeonic_prop(ws_en)
    local a = ws_en and sc_dict.AEONIC_WS[ws_en]
    if not a then return nil end
    return equipped_weapon_names()[a.slot or 'main'] == a.weapon and a.prop or nil
end

-- 今アフターマスが付いているか (アフターマス:Lv1〜3 = 270〜272、アフターマス = 273)
local function has_aftermath()
    local player = windower.ffxi.get_player()
    for _, buff in pairs(player and player.buffs or {}) do
        if buff >= 270 and buff <= 273 then return true end
    end
    return false
end

-- 今の武器・ジョブで使えるWSのID集合 (windower.ffxi.get_abilities)
-- HUD が毎フレーム呼ぶため1秒だけ使い回す。一覧が取れない/空のときは nil (= 判断しない)
local usable_cache = {time = -1, set = nil}
local function usable_ws_set()
    local now = os.clock()
    if now - usable_cache.time < 1.0 then return usable_cache.set end
    usable_cache.time = now
    usable_cache.set = nil
    local ok, abil = pcall(windower.ffxi.get_abilities)
    if not ok or type(abil) ~= "table" or type(abil.weapon_skills) ~= "table" then return nil end
    local set = {}
    for k, v in pairs(abil.weapon_skills) do
        if type(v) == "number" then set[v] = true elseif v == true then set[k] = true end
    end
    if next(set) == nil then return nil end
    usable_cache.set = set
    return set
end

-- WS が辞書に無い / res に無い / 今は使えない、を警告する (戻り値: 問題が無ければ true)
local function is_pet_skill(ws_name)
    return sc_dict.PUP_WS_DATABASE[ws_name] ~= nil or sc_dict.SMN_BP_DATABASE[ws_name] ~= nil
end

local function check_ws_usable(ws_name, category)
    if is_pet_skill(ws_name) then
        log_event("WARN", category, string.format("%s はペット技のため /ws では実行できません", ws_name))
        return false
    end
    local good = true
    if not ws_in_dict(ws_name) then
        log_event("WARN", category, string.format("sc_dict に無いWS: %s (連携判定は既定値で行われます)", ws_name))
        good = false
    end
    local id = ws_id_by_name(ws_name)
    if not id then
        log_event("WARN", category, string.format("res に無いWS名: %s (表記ゆれの可能性)", ws_name))
        return false
    end
    local set = usable_ws_set()
    if set and not set[id] then
        log_event("WARN", category, string.format("現在使えないWS: %s (武器不一致・未習得・スキル不足)", ws_name))
        good = false
    end
    return good
end

-- 優先リスト全体を点検し、問題のあるWSを1行にまとめて報告する
local function check_priority_list(silent_ok)
    local not_dict, not_res, not_usable, pet = {}, {}, {}, {}
    local set = usable_ws_set()
    for _, ws_name in ipairs(state.ws_priority or {}) do
        if is_pet_skill(ws_name) then
            table.insert(pet, ws_name)
        else
            if not ws_in_dict(ws_name) then table.insert(not_dict, ws_name) end
            local id = ws_id_by_name(ws_name)
            if not id then
                table.insert(not_res, ws_name)
            elseif set and not set[id] then
                table.insert(not_usable, ws_name)
            end
        end
    end
    local problems = 0
    if #pet > 0 then problems = problems + 1 log_event("WARN", "CHECK", "ペット技は /ws で実行できません: " .. table.concat(pet, ", ")) end
    if #not_dict > 0 then problems = problems + 1 log_event("WARN", "CHECK", "sc_dict に無いWS: " .. table.concat(not_dict, ", ")) end
    if #not_res > 0 then problems = problems + 1 log_event("WARN", "CHECK", "res に無いWS名: " .. table.concat(not_res, ", ")) end
    if #not_usable > 0 then
        problems = problems + 1
        log_event("WARN", "CHECK", string.format("%s で現在使えないWS: %s", state.active_job, table.concat(not_usable, ", ")))
    end
    if problems == 0 and not silent_ok then
        log_event("INFO", "CHECK", string.format("%s の優先リスト %d件はすべて使用可能", state.active_job, #(state.ws_priority or {})))
    end
    return problems == 0
end

local hud = texts.new("", settings)

-- 大きさ変更の目印「◢」: HUD の右下の角に重ねて表示する別のテキスト (背景なし・移動不可)
local GRIP_COLOR     = {150, 150, 150}  -- 通常
local GRIP_COLOR_HOT = {255, 220, 100}  -- 角にカーソルが乗っている / 大きさ変更中
local grip = texts.new("◢", {
    pos = {x = 0, y = 0},
    text = {font = "Meiryo", size = 10, alpha = 230, red = GRIP_COLOR[1], green = GRIP_COLOR[2], blue = GRIP_COLOR[3]},
    bg = {visible = false},
    flags = {draggable = false},
    padding = 0,
})
local grip_hot = false

-- 目印を HUD の右下の角に合わせる (文字サイズは HUD に比例)
local function update_grip()
    if not hud:visible() then
        grip:hide()
        return
    end
    local size = math.max(8, math.floor(safe_num(hud:size(), 11) * 0.9 + 0.5))
    if grip:size() ~= size then grip:size(size) end
    local c = grip_hot and GRIP_COLOR_HOT or GRIP_COLOR
    grip:color(c[1], c[2], c[3])
    local px, py = hud:pos()
    local w, h = hud:extents()
    local gw, gh = grip:extents()
    if px and py and w and h and gw and gh then
        grip:pos(px + w - gw, py + h - gh)
    end
    grip:show()
end

-- -----------------------------------------------------------------------------
-- HUD の拡大縮小 (マウス) : MBReadyTimer と同じ操作
--   ・HUD の上でホイール            : 文字サイズを 1 ずつ拡大/縮小
--   ・HUD の右下の角をクリック＆ドラッグ : 大きさを変更 (角以外のドラッグは従来どおり移動)
-- -----------------------------------------------------------------------------
local MOUSE_MOVE, MOUSE_LEFT_DOWN, MOUSE_LEFT_UP, MOUSE_WHEEL = 0, 1, 2, 10
local SIZE_MIN, SIZE_MAX = 6, 40
local RESIZE_HANDLE_PX = 18      -- 右下の角とみなす範囲 (px)

local resize = nil               -- ドラッグで大きさを変えている最中の情報
local move_allowed = settings.flags == nil or settings.flags.draggable ~= false  -- 元の「ドラッグで移動」設定

local function current_size()
    return safe_num(hud:size(), safe_num(settings.text and settings.text.size, 11))
end

local function set_size(size)
    size = math.max(SIZE_MIN, math.min(SIZE_MAX, math.floor(size + 0.5)))
    if size ~= current_size() then
        hud:size(size)
    end
    return size
end

-- 角の判定で一時的に止めた「ドラッグで移動」を元に戻してから保存する
local function save_hud_settings()
    if hud:draggable() ~= move_allowed then hud:draggable(move_allowed) end
    config.save(settings)
end

local function in_resize_handle(x, y)
    if not hud:visible() then return false end
    local px, py = hud:pos()
    local w, h = hud:extents()
    if not (px and py and w and h) then return false end
    return x >= px + w - RESIZE_HANDLE_PX and x <= px + w and y >= py + h - RESIZE_HANDLE_PX and y <= py + h
end

local function update_job_profile()
    load_external_json_config()

    local player = windower.ffxi.get_player()
    if player then state.player_id = player.id end
    if player and player.main_job then
        state.active_job = tostring(player.main_job)
        if profiles[state.active_job] then
            state.active_weapon = tostring(profiles[state.active_job].weapon or "片手剣")
            state.ws_priority = sanitize_ws_list(profiles[state.active_job].ws_priority)
            state.opener_only = profiles[state.active_job].opener_only == true
        end
        log_debug("PROFILE", string.format("Job Profile Updated: %s (Weapon: %s)", state.active_job, state.active_weapon))
    end
end

-- /ws で今すぐ撃てるか: ペット技・res に無い名前・未習得/武器違いのWSは除く
local function is_executable_ws(ws_name, usable)
    if is_pet_skill(ws_name) then return false end
    local id = ws_id_by_name(ws_name)
    if not id then return not (res and res.weapon_skills) end
    return usable == nil or usable[id] == true
end

-- 連携窓の秒数。manual は他人の横槍を待ってから撃つため、受付の上限 (BG-Wiki: 3〜10秒) まで見る
-- 連携の受付時間 (前の技が当たってから閉じるまで) の見込み。連携が続くたびに 1 秒ずつ短くなる。
-- 実測 (2026-10-10〜11、技のパケットから次の自動WSを入力するまでの秒数。着弾はその約 0.7 秒後):
--   始点から 9〜12 秒後でも連携した / 連携 2 回目の後 6.0 秒 = 連携 / 3 回目の後 6.0 秒 = 連携したりしなかったり /
--   4 回目・5 回目の後 6.0 秒 = 連携せず
--   3 回目の後 5.8 秒 (余裕 1.2 秒) = 2 回連携・1 回連携せず (2026-10-11 夜) → 余裕を 2.0 秒に広げた
local SC_WINDOW_BASE_SEC = 10.0
local SC_WINDOW_MIN_SEC = 4.0
local SC_LAND_MARGIN_SEC = 2.0   -- 入力してから着弾するまでの余裕 (受付が閉じるこの秒数前までに入力する)
local SC_OPEN_SEC = 3.3          -- 受付が開くまでの秒数 (これより早く撃つと連携しない)
-- 連携待機に当てたとき、Lv2 の属性から出来る Lv3 の連携 (wiki.ffo.jp/html/24407。分解だけは分解のまま)
local CHAINBOUND_LV3 = {["核熱"] = "光", ["重力"] = "闇", ["湾曲"] = "闇"}
local function sc_window_sec(step)
    return math.max(SC_WINDOW_MIN_SEC, SC_WINDOW_BASE_SEC - safe_num(step, 0))
end

-- 自動WSを撃てるまでの残り秒数。
--   ・連携の受付は、前の技が当たってから約 3 秒後に開く。それより早く撃つと連携せず、前の人の連携も切ってしまう
--     (実測 2026-10-10: イロハの月輪の 2.9 秒後に撃った花車は連携しなかった。3.0〜3.1 秒後は連携した)。
--   ・連携窓があるあいだは min_follow 秒待つ。ただし連携が続いて受付が短くなっているときは、
--     受付が閉じる前に着弾するよう待ち時間を詰める (最短 SC_OPEN_SEC)。
--   ・manual はさらに follow_wait 秒 (受付が閉じる 2 秒前まで) 待つ。
--   ・渾然一体 (連携待機) の直後も同じく待つ。待機が付いてから 2 秒以内に当てたWSは連携せず、待機も消えた
--     (実測 2026-10-11: 0〜2 秒後は 4 回とも連携せず、3 秒後は 2 回とも連携)。
-- 始点から今までの WS がすべて自分のもの (他の人の連携ではない) で、TP が満タン (3000) なら、
-- min_follow を待たずに受付が開いた時点 (SC_OPEN_SEC) で撃つ。他の人の割り込みを待つ必要がなく、TP を捨てないため
local FULL_TP = 3000
local MIN_FOLLOW_FLOOR = 4.0   -- min_follow の下限 (作者の指定)
local function open_sec()
    local k = state.sc_last_kind
    if k == "self" or k == "player" then
        return math.min(SC_OPEN_SEC, math.max(0, safe_num(settings.open_player, SC_OPEN_SEC)))
    end
    return SC_OPEN_SEC
end
local function follow_wait_left(now, tp)
    local left = 0
    local cb = state.chainbound
    if cb and safe_lt(now, safe_num(cb.until_time, 0)) then
        -- 連携待機は味方の WS を待っている (アークGK は TP が無いときにも使う) ので、受付が開いたらすぐ使う。
        -- それまでの連携の状態は待機で上書きされているので、連携窓の待ち時間は見ない
        return math.max(0, safe_num(cb.start_time, 0) + SC_OPEN_SEC - now)
    end
    local window_on_other = false
    if state.sc_active and state.sc_target then
        -- 連携が付いている敵と今の敵が違う (別の敵に移った等) なら、その連携は待たない
        local t = windower.ffxi.get_mob_by_target('t')
        window_on_other = t and t.id ~= state.sc_target or false
    end
    if state.sc_active and not window_on_other and safe_lt(now, safe_num(state.sc_expiration, 0)) then
        local window = sc_window_sec(state.sc_step)
        local wait = math.max(open_sec(), math.min(math.max(MIN_FOLLOW_FLOOR, safe_num(settings.min_follow, MIN_FOLLOW_FLOOR)), window - SC_LAND_MARGIN_SEC))
        if settings.start_mode == "manual" then
            wait = math.max(wait, math.min(safe_num(settings.follow_wait, 6.0), math.max(3.0, window - 2.0)))
        end
        if tp and state.sc_self_only and safe_gte(tp, FULL_TP) then wait = open_sec() end
        left = math.max(left, safe_num(state.sc_start_time, 0) + wait - now)
    end
    return math.max(0, left)
end

-- フェイスの一人連携が終わるまでの残り秒数 (待っていなければ 0)。期限が過ぎていたらここで片付ける
-- 戻り値: 残り秒数 (いちばん長く待つフェイスの分), そのフェイスの表示名
local function solo_wait_left(now)
    if next(state.solos) == nil then return 0 end
    if settings.trust_solo == false then
        state.solos = {}
        return 0
    end
    local longest, name = 0, nil
    for actor_id, solo in pairs(state.solos) do
        local left = safe_num(solo.until_time, 0) - now
        if left <= 0 then
            log_debug("TRUST_SOLO", string.format("待ち終了: %s (%s)", solo.name,
                solo.count > 0 and string.format("WS %d 回のあと次が来なかった", solo.count) or "WS が出なかった"))
            state.solos[actor_id] = nil
        elseif left > longest then
            longest, name = left, solo.name
        end
    end
    return longest, name
end

local function find_base_ws_from_priority()
    if not state.ws_priority or #state.ws_priority == 0 then return nil end

    local now = safe_num(os.clock(), 0)
    local sc_exp = safe_num(state.sc_expiration, 0)
    local is_sc_window = state.sc_active and safe_lt(now, sc_exp) and state.sc_property
    -- 連携が付いている敵と今の敵が違う (倒して別の敵に移った等) なら、連携は続かないので始点から
    if is_sc_window and state.sc_target then
        local t = windower.ffxi.get_mob_by_target('t')
        if t and t.id ~= state.sc_target then is_sc_window = false end
    end

    -- 撃てるWSの中で一番上のもの (連携が無いときの始点・継続に使う)
    local usable = usable_ws_set()
    local first_idx, first_ws
    for idx, ws_name in ipairs(state.ws_priority) do
        if is_executable_ws(ws_name, usable) then first_idx, first_ws = idx, ws_name break end
    end
    if not first_ws then return nil end

    -- 連携待機 (渾然一体) が自分の敵に付いている: 次の WS は直前の属性に関係なく連携になる。
    -- 結果は WS の属性で決まる (wiki.ffo.jp/html/24407): 光/闇を持つ WS = その光/闇 (そこで終わり) /
    -- 核熱 = 光、重力・湾曲 = 闇 (もう一度続けられる) / 分解 = 分解 / Lv1 = その属性。
    -- 続けられる光/闇 > 終わりの光/闇 > Lv2 > Lv1 の順で、同じなら優先リストの上から選ぶ
    local cb = state.chainbound
    if cb and safe_lt(now, safe_num(cb.until_time, 0)) then
        local t = windower.ffxi.get_mob_by_target('t')
        if t and t.id == cb.target then
            local aftermath = has_aftermath()
            local best
            for idx, ws_name in ipairs(state.ws_priority) do
                local info = is_executable_ws(ws_name, usable) and sc_dict.find_ws_info(ws_name, state.active_weapon)
                if info and info.sc and info.sc[1] then
                    local result, score = nil, 0
                    local lv3 = aftermath and aeonic_prop(info.en)
                    for _, prop in ipairs(info.sc) do
                        if prop == "光" or prop == "闇" then lv3 = lv3 or prop end
                    end
                    if lv3 then
                        result, score = lv3, 3
                    elseif CHAINBOUND_LV3[info.sc[1]] then
                        result, score = CHAINBOUND_LV3[info.sc[1]], 4
                    else
                        result = info.sc[1]
                        score = (sc_dict.SC_ELEMENTS[result] and sc_dict.SC_ELEMENTS[result].level or 1) >= 2 and 2 or 1
                    end
                    if not best or score > best.score then
                        best = {ws = ws_name, result = result, score = score, idx = idx}
                    end
                end
            end
            if best then
                return {
                    ws = best.ws,
                    result_sc = best.result,
                    priority = best.idx,
                    reason = string.format("優先度%d [連携待機 ➔ %s (%s)]", best.idx, best.result, best.ws)
                }
            end
        end
    end

    if is_sc_window then
        -- opener_only: 先頭のWSは始点専用。連携中は2番目以降を先に探し、どれもつながらないときだけ先頭に戻る
        -- イオニックWSの光/闇はアフターマス中だけ付く。今アフターマスが無ければ数えない。
        -- アフターマス頼みの連携は、自分のイオニックWSから続ける場合 (照破→照破=極光) だけ優先順どおりに選ぶ。
        -- フェイスや他の人の光/闇、連携で出来た光/闇を締めるときは、元から光/闇を持つWS (不動など) を先に選ぶ
        local aftermath = has_aftermath()
        local fallback = nil
        for pass = 1, (state.opener_only and 2 or 1) do
            for priority_idx, ws_name in ipairs(state.ws_priority) do
                local skip = state.opener_only and pass == 1 and priority_idx == first_idx
                local ws_info = not skip and is_executable_ws(ws_name, usable) and sc_dict.find_ws_info(ws_name, state.active_weapon)
                local lv3 = ws_info and aftermath and aeonic_prop(ws_info.en)
                local native = ws_info
                if lv3 then
                    ws_info = { ja = ws_info.ja, en = ws_info.en, sc = { lv3, unpack(ws_info.sc) } }
                end
                if ws_info then
                    local eval = sc_dict.evaluate_ws_for_sc(ws_info, state.sc_props or state.sc_property)
                    if eval then
                        local choice = {
                            ws = ws_name,
                            result_sc = eval.result,
                            priority = priority_idx,
                            reason = string.format("優先度%d [%s ➔ %s (%s)]", priority_idx, state.sc_property, eval.result, ws_name)
                        }
                        -- アフターマスの属性を外しても同じ連携になるなら、頼っていない
                        local plain = lv3 and sc_dict.evaluate_ws_for_sc(native, state.sc_props or state.sc_property)
                        local needs_aftermath = lv3 and not (plain and plain.result == eval.result)
                        if not needs_aftermath or state.sc_aeonic then
                            return choice
                        end
                        choice.reason = choice.reason .. " ※アフターマス頼み"
                        fallback = fallback or choice
                    end
                end
            end
        end
        if fallback then return fallback end

        if settings.auto_mode == "flexible" then
            return {
                ws = first_ws,
                result_sc = "なし",
                priority = first_idx,
                reason = string.format("優先度%d [開幕/継続: %s]", first_idx, first_ws)
            }
        end
        return nil
    elseif settings.start_mode == "manual" then
        return nil  -- 1回目は自分で撃つ (誰かの始点が来るまで待つ)
    else
        return {
            ws = first_ws,
            result_sc = "始点",
            priority = first_idx,
            reason = string.format("優先度%d [連携始点: %s]", first_idx, first_ws)
        }
    end
end

-- ---------------------------------------------------------------------------
-- PT の人へのトス: 決まった WS を撃つ傾向のある PT の人 (フェイスは除く) の次の WS を予測し、
-- 近いときは、その WS が続けられる属性になる WS を選ぶ (近いときだけトスを優先)。
-- 予測は「直近 8 回の WS の最頻 (6 割以上) と、撃つ間隔の中央値」から。
-- ---------------------------------------------------------------------------
local PT_HIST_KEEP = 8
local PT_HIST_AGE = 120.0       -- この秒数撃っていない人は予測に使わない
-- トスは成功率が目的ではない (作者の方針: 相手には撃ちたいタイミングがある。トスを上げるのが大事で、撃つかは相手次第。
-- 敵にできるだけダメージを与えるためのトス)。
local TOSS_NEAR_MIN = 2.5       -- 次の WS まで、この秒数以上〜
local TOSS_NEAR_MAX = 8.0       -- この秒数以内なら「近い」
local pt_hist = {}              -- [actor_id] = {name=, times={}, names={}}

local function record_pt_ws(actor_id, actor_name, ws_name)
    local h = pt_hist[actor_id]
    if not h then
        h = {name = actor_name, times = {}, names = {}}
        pt_hist[actor_id] = h
    end
    h.times[#h.times + 1] = safe_num(os.clock(), 0)
    h.names[#h.names + 1] = ws_name
    if #h.times > PT_HIST_KEEP then
        table.remove(h.times, 1)
        table.remove(h.names, 1)
    end
end

local function ws_props_by_name(ws_name)
    local id = ws_id_by_name(ws_name)
    local ws = id and res and res.weapon_skills and res.weapon_skills[id]
    if not ws then return nil end
    local props = {}
    for _, key in ipairs({"skillchain_a", "skillchain_b", "skillchain_c"}) do
        local en = ws[key]
        if en and en ~= "" then props[#props + 1] = sc_dict.EN_TO_JA_SC[en] or en end
    end
    return #props > 0 and props or nil
end

-- 近いうちに撃ちそうな PT の人の WS の一覧 {actor=, ws=, props=, eta=}
local function predicted_pt_ws(now)
    local list = {}
    for actor_id, h in pairs(pt_hist) do
        local n = #h.times
        if n == 0 or now - h.times[n] > PT_HIST_AGE then
            pt_hist[actor_id] = nil
        elseif n >= 3 then
            local cnt, best, best_n = {}, nil, 0
            for _, name in ipairs(h.names) do
                cnt[name] = (cnt[name] or 0) + 1
                if cnt[name] > best_n then best, best_n = name, cnt[name] end
            end
            if best_n / n >= 0.6 then
                local gaps = {}
                for i = 2, n do gaps[#gaps + 1] = h.times[i] - h.times[i - 1] end
                table.sort(gaps)
                local gap = math.min(25, math.max(4, gaps[math.ceil(#gaps / 2)]))
                local nxt, guard = h.times[n] + gap, 0
                while nxt < now - 1 and guard < 4 do nxt = nxt + gap; guard = guard + 1 end
                local eta = nxt - now
                local props = ws_props_by_name(best)
                if props and eta >= TOSS_NEAR_MIN and eta <= TOSS_NEAR_MAX then
                    list[#list + 1] = {actor = h.name, ws = best, props = props, eta = eta}
                end
            end
        end
    end
    return list
end

-- 自分の WS で出来る属性 (配列) に、予測した WS のどれかが続けられるか
local function toss_target(result_props, preds)
    for _, pr in ipairs(preds) do
        if sc_dict.evaluate_ws_for_sc({sc = pr.props}, result_props) then return pr end
    end
    return nil
end

-- base (今までの選び方の結果) がトスになっていなければ、トスになる WS を選び直す。無ければ nil (= base のまま)
local function toss_override(base)
    if settings.toss == false or not base then return nil end
    local now = safe_num(os.clock(), 0)
    local preds = predicted_pt_ws(now)
    if #preds == 0 then return nil end

    local win = state.sc_active and safe_lt(now, safe_num(state.sc_expiration, 0)) and state.sc_property
    if win and state.sc_target then
        local t = windower.ffxi.get_mob_by_target('t')
        if t and t.id ~= state.sc_target then win = false end
    end
    local prev = win and (state.sc_props or state.sc_property) or nil

    local usable = usable_ws_set()
    local first_idx
    for idx, name in ipairs(state.ws_priority) do
        if is_executable_ws(name, usable) then first_idx = idx break end
    end

    -- base 自身がトスになっているならそのまま
    local base_info = sc_dict.find_ws_info(base.ws, state.active_weapon)
    local base_props = (win and base.result_sc and base.result_sc ~= "なし" and base.result_sc ~= "始点")
        and {base.result_sc} or (base_info and base_info.sc)
    if base_props and toss_target(base_props, preds) then return nil end

    for idx, name in ipairs(state.ws_priority) do
        if name ~= base.ws and is_executable_ws(name, usable) and not (win and state.opener_only and idx == first_idx) then
            local info = sc_dict.find_ws_info(name, state.active_weapon)
            if info and info.sc then
                local after, result
                if win then
                    local ev = sc_dict.evaluate_ws_for_sc(info, prev)
                    if ev then
                        local first_prev = type(prev) == "table" and prev[1] or prev
                        if not sc_dict.is_terminal_chain(first_prev, ev.result) then
                            after, result = {ev.result}, ev.result
                        end
                    end
                else
                    after, result = info.sc, "始点"
                end
                local pr = after and toss_target(after, preds)
                if pr then
                    return {
                        ws = name,
                        result_sc = result,
                        priority = idx,
                        reason = string.format("優先度%d [トス: %s の %s (あと約 %.0f 秒) に続けやすい %s]", idx, pr.actor, pr.ws, pr.eta, tostring(result))
                    }
                end
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- 全員が同じ敵を狙っているとき (作者の方針): トスも連携も難しいので、一番威力の高い WS を撃つ。
--   選び方 (作者の指定): プライムウェポンならそのプライムWS (wiki.ffo.jp/html/39090.html)、
--   エンピリアンウェポンならそのエンピリアンWS、それ以外は「クポフリートの秘術」で覚えるエンピリアンWS
--   (wiki.ffo.jp/html/30062.html の武器種別の表)。侍の童子切安綱 = 照破 だけは作者の個別指定。
--   どれも使えないとき (WS が使えない・武器種が不明) は優先リストの先頭。待ち時間なしで、TP が min_tp あれば撃つ。
-- 「同じ敵を狙っている人が多い」= パーティーとアライアンス (p1〜p5・a10〜a15・a20〜a25) の人 (フェイスは除く) のうち、
--   自分と同じ敵を狙っている人が、自分を含めて settings.focus_people (既定 3) 人以上。別の敵を狙っている人がいても数える。
--   狙いは mob.target_index で見る
-- ---------------------------------------------------------------------------
local FOCUS_WS_BY_WEAPON = {          -- 作者の個別指定 (武器の英語名)
    ["Dojikiri Yasutsuna"] = "十二之太刀・照破",
}
local FOCUS_PRIME_BY_ITEM = {         -- プライムウェポン (日本語名) → プライムWS
    ["ヴァルガプルニカワ"] = "マルカラ",        ["ンプガンドリング"] = "ルースレスストローク",
    ["カリブルヌス"] = "インペラトル",          ["ヘルヘイム"] = "フィンブルヴェト",
    ["スパリリソス"] = "ブリッツ",              ["ラフリア"] = "ディザスター",
    ["フォエナリア"] = "ジ・オリジン",          ["ゲイブィード"] = "ダーマット",
    ["慟哭"] = "是生滅法",                      ["草薙剣"] = "絶之太刀・無名",
    ["ローグモル"] = "ダグダ",                  ["オパショーロ"] = "オシャラ",
    ["ピナカ"] = "シャルヴ",                    ["アープ"] = "ジ・エンド",
}
local FOCUS_EMPYREAN_BY_TYPE = {      -- 武器種 → エンピリアンWS (クポフリートの秘術で覚える WS)
    ["格闘"] = "ビクトリースマイト", ["短剣"] = "ルドラストーム",   ["片手剣"] = "シャンデュシニュ",
    ["両手剣"] = "トアクリーバー",   ["片手斧"] = "クラウドスプリッタ", ["両手斧"] = "ウッコフューリー",
    ["両手鎌"] = "クワイタス",       ["両手槍"] = "カムラン",       ["片手刀"] = "秘",
    ["両手刀"] = "祖之太刀・不動",   ["片手棍"] = "ダガン",         ["両手棍"] = "ミルキル",
    ["弓術"] = "ジシュヌの光輝",     ["射撃"] = "ワイルドファイア",
}
local focus_cache = {time = -1, value = false}
local FOCUS_PARTY_KEYS = {"p1", "p2", "p3", "p4", "p5", "a10", "a11", "a12", "a13", "a14", "a15",
    "a20", "a21", "a22", "a23", "a24", "a25"}

local function all_same_target()
    local now = safe_num(os.clock(), 0)
    if now - focus_cache.time < 0.5 then return focus_cache.value end
    focus_cache.time = now
    local value, desc = false, "対象なし"
    local t = windower.ffxi.get_mob_by_target('t')
    local party = windower.ffxi.get_party()
    local me = windower.ffxi.get_player()
    if t and t.index and t.spawn_type == 16 and party and me then
        local same, other, unknown = 0, 0, 0
        for _, key in ipairs(FOCUS_PARTY_KEYS) do
            local m = party[key]
            local mob = m and m.mob
            if mob and not mob.is_npc and mob.id ~= me.id then
                local ti = mob.target_index
                if ti == nil then
                    unknown = unknown + 1
                elseif ti > 0 then
                    local tm = windower.ffxi.get_mob_by_index(ti)
                    if tm and tm.spawn_type == 16 then
                        if ti == t.index then same = same + 1 else other = other + 1 end
                    end
                end
            end
        end
        value = same + 1 >= math.max(2, safe_num(settings.focus_people, 3))
        desc = string.format("同じ敵 %d 人 (自分を入れて %d 人) / 別の敵 %d 人 / 狙いが分からない %d 人", same, same + 1, other, unknown)
    end
    if value ~= focus_cache.value then
        log_debug("FOCUS", string.format("同じ敵を狙う人が多い: %s (%s)", value and "はい" or "いいえ", desc))
    end
    focus_cache.value = value
    return value
end

local function focus_choice()
    if settings.focus_max == false then return nil end
    if not all_same_target() then return nil end
    local usable = usable_ws_set()
    local names = equipped_weapon_names()
    -- 弓術・射撃の WS は飛び道具の枠の武器で決まる
    local slot = (state.active_weapon == "弓術" or state.active_weapon == "射撃") and "range" or "main"
    local main = names[slot]
    local candidates = {
        FOCUS_WS_BY_WEAPON[main or ""],
        FOCUS_PRIME_BY_ITEM[names[slot .. "_ja"] or ""],
        FOCUS_EMPYREAN_BY_TYPE[state.active_weapon or ""],
    }
    local ws
    for i = 1, 3 do
        if candidates[i] and is_executable_ws(candidates[i], usable) then ws = candidates[i] break end
    end
    if not ws then
        for _, name in ipairs(state.ws_priority or {}) do
            if is_executable_ws(name, usable) then ws = name break end
        end
    end
    if not ws then return nil end
    return {
        ws = ws,
        result_sc = "なし",
        priority = 0,
        no_wait = true,
        min_tp = math.max(safe_num(settings.min_tp, 1000), safe_num(settings.focus_tp, 1500)),   -- この TP になってから撃つ
        reason = string.format("同じ敵を狙う人が多い: 最大威力 (%s)", tostring(main or "武器不明"))
    }
end

local function find_best_ws_from_priority()
    local focus = focus_choice()
    if focus then return focus end
    local base = find_base_ws_from_priority()
    local tossed = toss_override(base)
    return tossed or base
end

-- 自動連携判定＆WS自動実行ロジック (HUD表示ON/OFFに関わらず実行)
local function process_auto_skillchain()
    local player = windower.ffxi.get_player()
    if not player or safe_num(player.status, 0) ~= 1 then return end

    local now = safe_num(os.clock(), 0)
    local tp = safe_num(player.vitals and player.vitals.tp, 0)
    local min_tp = safe_num(settings.min_tp, 1000)
    local wait_delay = safe_num(settings.wait_delay, 1.2)
    local last_ws = safe_num(state.last_ws_time, 0)

    if settings.enabled and safe_gte(tp, min_tp) and safe_gt(now - last_ws, wait_delay) then
        local choice = find_best_ws_from_priority()
        -- フェイスが一人連携をしている間は割り込まない (終わってから撃つ)
        if choice and (choice.no_wait or follow_wait_left(now, tp) <= 0) and solo_wait_left(now) <= 0
            and not (choice.min_tp and not safe_gte(tp, choice.min_tp)) then
            -- 「対象が見えない」でゲームに断られた直後は 2 秒待つ (敵の「対象にできる」という値は、大きな敵で当てにならないことがあるので、事前の判定には使わない)
            if now < safe_num(state.unseen_until, 0) then return end
            local in_range, dist, reach = ws_in_range(choice.ws)
            if not in_range then
                -- 届くまで撃たない。ログは 3 秒おき
                if now - safe_num(state.range_log_time, 0) >= 3.0 then
                    state.range_log_time = now
                    log_debug("RANGE", string.format("%s は遠いので撃たない (距離 %.1f / 届く距離 %.1f)", choice.ws, dist, reach))
                end
                return
            end
            state.last_ws_time = now
            state.pending_ws = {name = choice.ws, time = now, tp = tp}
            check_ws_usable(choice.ws, "EXECUTE")
            log_debug("EXECUTE", string.format("Executing WS: %s (%s) [TP: %d / AM: %s / 連携%d回目の後 / 前の技から %.1f 秒]", choice.ws, choice.reason, tp,
                has_aftermath() and "あり" or "なし", safe_num(state.sc_step, 0), now - safe_num(state.sc_start_time, now)))
            chat_msg(string.format("[OmniChain] WS自動実行: %s (%s)", choice.ws, choice.reason), 158)
            -- ゲーム入力は Shift-JIS のため、日本語WS名を変換して送る (AutoSkillchain と同様)
            local cmd = string.format('input /ws "%s" <t>', choice.ws)
            if windower.to_shift_jis then
                local conv_ok, converted = pcall(windower.to_shift_jis, cmd)
                if conv_ok and converted then cmd = converted end
            end
            windower.send_command(cmd)
        end
    end
end

-- prerender イベント (メインルーチン)
local function check_pending_ws(now)
    local p = state.pending_ws
    if p and now - safe_num(p.time, now) > PENDING_WS_TIMEOUT then
        state.pending_ws = nil
        log_event("WARN", "WS_TIMEOUT", string.format("%s を入力したが %.0f秒以内に発動しなかった (WS名・距離・行動不能などを確認)", p.name, PENDING_WS_TIMEOUT))
    end
end

windower.register_event("prerender", guarded("PRERENDER", function()
    local frame_start = os.clock()

    -- WS応答待ちのタイムアウト / ログの定期書き出し
    check_pending_ws(frame_start)
    if frame_start - monitor.last_flush > LOG_FLUSH_SEC then flush_log() end

    local ok, err = xpcall(function()
        -- バックグラウンド自動連携判定
        process_auto_skillchain()

        -- HUDオーバーレイ描画
        if not settings.show_hud then
            hud:hide()
            grip:hide()
            return
        end

        local now = safe_num(os.clock(), 0)
        local sc_exp = safe_num(state.sc_expiration, 0)
        local min_tp = safe_num(settings.min_tp, 1000)

        local lines = {}
        local status_str = settings.enabled and color_text("[ON]", 100, 255, 100) or color_text("[OFF]", 255, 100, 100)
        table.insert(lines, string.format("=== [ OmniChain v%s ] %s ===", _addon.version, status_str))
        table.insert(lines, string.format("Job / 武器: %s / %s", color_text(state.active_job, 255, 220, 100), color_text(state.active_weapon, 0, 210, 255)))

        local prio_str_list = {}
        for idx, name in ipairs(state.ws_priority) do
            if safe_lte(idx, 3) then
                table.insert(prio_str_list, string.format("P%d:%s", idx, name))
            end
        end
        table.insert(lines, string.format("WS優先度: %s", color_text(table.concat(prio_str_list, " > "), 200, 255, 200)))

        if state.sc_active and safe_lt(now, sc_exp) then
            local rem_time = math.max(0.0, sc_exp - now)
            table.insert(lines, string.format("アクティブ連携: %s (残り %.1fs / %s)", color_text(state.sc_property, 255, 200, 50), rem_time, state.sc_starter))
        else
            state.sc_active = false
            table.insert(lines, string.format("連携窓: %s", color_text("待機中 (Idle)", 180, 180, 180)))
        end

        local player = windower.ffxi.get_player()
        if player and safe_num(player.status, 0) == 1 then
            local tp = safe_num(player.vitals and player.vitals.tp, 0)
            table.insert(lines, string.format("TP: %s / 最小%d", color_text(tostring(tp), safe_gte(tp, min_tp) and 50 or 255, 255, 100), min_tp))

            local solo_left, solo_name = solo_wait_left(now)
            if solo_left > 0 then
                table.insert(lines, string.format("一人連携待ち: %s (あと %.1fs)", color_text(tostring(solo_name), 255, 160, 220), solo_left))
            end

            local choice = find_best_ws_from_priority()
            if choice then
                local wait_left = math.max(choice.no_wait and 0 or follow_wait_left(now, tp), solo_left)
                local wait_str = wait_left > 0 and string.format(" (あと %.1fs)", wait_left) or ""
                table.insert(lines, string.format("次発動予定: %s%s", color_text(choice.ws, 100, 255, 150), wait_str))
                table.insert(lines, string.format("評価判定: %s", color_text(choice.reason, 200, 200, 255)))
            elseif settings.start_mode == "manual" then
                table.insert(lines, string.format("次発動予定: %s", color_text("始点待ち (1回目は手動)", 255, 200, 120)))
            end
        else
            table.insert(lines, string.format("状態: %s", color_text("納刀中 (Idle)", 180, 180, 180)))
        end

        -- texts オブジェクトへの代入 (hud.text = ...) は ${text} 変数の設定になるため、メソッドで本文を設定する
        hud:text(table.concat(lines, string.char(10)))
        hud:show()
        update_grip()
    end, traceback)

    if not ok then
        -- 毎フレーム同じエラーが出るため、チャットは log_event 側で10秒ごとにまとめる
        -- 記録された (間引かれなかった) ときだけトレースもファイルに残す
        if log_event("ERROR", "PRERENDER", tostring(err):match("^[^\n]*") or tostring(err)) then
            monitor.buffer[#monitor.buffer + 1] = tostring(err)
            flush_log(true)
        end
    end
end))

-- HUD のマウス操作 (true を返すとクリックをゲームに渡さない。guarded は戻り値を捨てるので使わない)
local function on_mouse(mtype, x, y, delta, blocked)
    if blocked or not settings.show_hud then return end

    if mtype == MOUSE_MOVE then
        if resize then
            -- ドラッグした分だけ、幅・高さの伸び率の大きい方に合わせて文字サイズを変える
            local rx = (resize.w + (x - resize.x)) / math.max(resize.w, 1)
            local ry = (resize.h + (y - resize.y)) / math.max(resize.h, 1)
            set_size(resize.size * math.max(rx, ry))
            update_grip()
            return true
        end
        -- 角の上では libs/texts の「ドラッグで移動」を止め、クリックをこちらで受け取る
        local on_handle = in_resize_handle(x, y)
        if move_allowed then
            local want = not on_handle
            if hud:draggable() ~= want then hud:draggable(want) end
        end
        -- 角に乗ったら目印を光らせる
        if on_handle ~= grip_hot then
            grip_hot = on_handle
            update_grip()
        end

    elseif mtype == MOUSE_LEFT_DOWN then
        if in_resize_handle(x, y) then
            local w, h = hud:extents()
            resize = {x = x, y = y, w = w, h = h, size = current_size()}
            return true
        end

    elseif mtype == MOUSE_LEFT_UP then
        if resize then
            resize = nil
            save_hud_settings()
            return true
        end

    elseif mtype == MOUSE_WHEEL then
        if hud:hover(x, y) then
            local step = safe_num(delta, 0) > 0 and 1 or -1
            set_size(current_size() + step)
            save_hud_settings()
            update_grip()
            return true
        end
    end
end

windower.register_event("mouse", function(...)
    local args, n = {...}, select("#", ...)
    local ok, result = xpcall(function() return on_mouse(unpack(args, 1, n)) end, traceback)
    if ok then return result end
    resize = nil
    log_event("ERROR", "MOUSE", tostring(result):match("^[^\n]*") or tostring(result))
end)

-- アクションのカテゴリ別に技リソースを引く (3: WS / 11: TP技(オートマトン等) / 13: ペット技(契約の履行等))
local CATEGORY_RESOURCES = {
    [3]  = "weapon_skills",
    [11] = "monster_abilities",
    [13] = "job_abilities",
}

-- パーティー/アライアンスメンバー、またはそのペットかどうか (敵の技で連携窓を開かないため)
local function is_party_actor(mob)
    if not mob then return false end
    if mob.in_party or mob.in_alliance then return true end
    local party = windower.ffxi.get_party()
    if not party then return false end
    for _, member in pairs(party) do
        if type(member) == "table" and member.mob and member.mob.pet_index and member.mob.pet_index == mob.index then
            return true
        end
    end
    return false
end

-- 追加効果メッセージID → 発生した連携 (res/action_messages.lua: 288-301 ダメージ / 385-398 回復 / 767-770 極光・黒闇)
local SKILLCHAIN_MESSAGES = {}
do
    local order = {"光", "闇", "重力", "分解", "湾曲", "核熱", "収縮", "溶解", "硬化", "振動", "貫通", "切断", "炸裂", "衝撃"}
    for i, name in ipairs(order) do
        SKILLCHAIN_MESSAGES[287 + i] = name
        SKILLCHAIN_MESSAGES[384 + i] = name
    end
    SKILLCHAIN_MESSAGES[767] = "極光"; SKILLCHAIN_MESSAGES[769] = "極光"
    SKILLCHAIN_MESSAGES[768] = "黒闇"; SKILLCHAIN_MESSAGES[770] = "黒闇"
end

local function clear_sc_state()
    state.sc_active = false
    state.sc_property = nil
    state.sc_props = nil
    state.sc_expiration = 0
    state.sc_starter = ""
    state.sc_target = nil
    state.sc_step = 0
    state.sc_aeonic = false
    state.solo_just_ended = false
    state.sc_self_only = false
end

-- チャットの「技連携・○○」はパケットより数秒 (実測4〜7秒) 遅れて届くことがある。
-- パケットで連携状態を更新してからこの秒数はチャットを無視し、パケットを取りこぼしたときの予備にだけ使う
local TEXT_SC_IGNORE_SEC = 10.0

-- 連携が発生した: 次段の判定は発生した連携だけを A1 とする (wiki: 3連携以降は前WSの他属性を無視)
-- close_reason: この連携には続けられないと分かっているとき、その理由 (連携は終わりとし、次は始点から)
local function apply_chain_result(sc_name, starter, source, target_id, close_reason)
    local now = safe_num(os.clock(), 0)
    if source == "TEXT_SC" and safe_lt(now, safe_num(state.last_packet_sc_time, -100) + TEXT_SC_IGNORE_SEC) then
        log_debug(source, string.format("Ignored (packet is newer): %s", sc_name))
        return
    end
    -- パケットとチャットの両方で同じ連携を受け取るため、直後の重複は無視する
    if state.last_chain_name == sc_name and safe_lt(now, safe_num(state.last_chain_time, 0) + 1.5) then return end

    -- 初段WSの光/闇 (イオニック) に光/闇WSを重ねた連携も 光→光 / 闇→闇 として終わる (ゲーム内で確認)
    local prev = state.sc_active and state.sc_props and state.sc_props[1] or nil
    state.last_chain_name = sc_name
    state.last_chain_time = now
    if source == "PACKET_SC" then state.last_packet_sc_time = now end

    -- フェイスの一人連携の最後の技で出来た連携には、自分のWSを重ねても連携しない
    -- (実測 2026-10-10: イロハの月輪の光に、3.2 秒後・5 秒後の不動がどちらも連携しなかった)。
    -- そこで連携は終わりとし、次は始点から組み直す
    if state.solo_just_ended then close_reason = close_reason or "フェイスの一人連携の最後の技" end
    if close_reason then
        clear_sc_state()
        log_debug(source, string.format("Chain closed: %s (%s。続けずに始点から)", sc_name, close_reason))
        return
    end

    if sc_dict.is_terminal_chain(prev, sc_name) then
        -- 光→光 / 闇→闇 の後、極光/黒闇の後はどの WS でも連携しない
        clear_sc_state()
        state.solos = {}   -- フェイスの一人連携もここで終わり
        log_debug(source, string.format("Chain closed: %s (prev: %s)", sc_name, tostring(prev)))
        return
    end

    state.sc_active = true
    state.sc_props = { sc_name }
    state.sc_property = sc_name
    state.sc_step = safe_num(state.sc_step, 0) + 1
    state.sc_aeonic = false
    state.sc_expiration = now + sc_window_sec(state.sc_step)
    state.sc_start_time = now
    if starter then state.sc_starter = starter end
    if target_id then state.sc_target = target_id end
    log_debug(source, string.format("Chain: %s (prev: %s)", sc_name, tostring(prev)))
end

-- アクションカテゴリ名
local CATEGORY_NAMES = {[3] = "WS", [7] = "WS構え", [11] = "TP技", [13] = "ペット技"}
local WS_READY_INTERRUPT = 28787
-- 命中しなかったことを示す行動メッセージ (188/189: WS ミス・効果なし / 323/324: 技 効果なし・ミス)
local NO_HIT_MESSAGES = {[31] = true, [188] = true, [189] = true, [323] = true, [324] = true}   -- 31: 分身 (空蝉) で消された
-- アビリティの結果を示す行動メッセージ (100: 使っただけ / 102: HP回復 / 110・317: ダメージ / 158・324: ミス / 323: 効果なし)
-- 通常攻撃の結果のメッセージ (1: 命中 / 15: ミス / 67: クリティカル / 352〜354・576・577: 遠隔攻撃)。
-- フェイスの通常攻撃には、特殊技と同じカテゴリ 11 で届くものがある (アシェラの #3455〜3460)。WS ではないので連携に数えない
local AUTO_ATTACK_MESSAGES = {[1] = true, [15] = true, [67] = true, [352] = true, [353] = true, [354] = true, [576] = true, [577] = true}
local JA_RESULT_MESSAGES = {[100] = true, [102] = true, [110] = true, [158] = true, [317] = true, [323] = true, [324] = true}
-- 渾然一体で敵が連携待機になったことを示す行動メッセージと、待機が続くとみなす秒数
local CHAINBOUND_MESSAGE = 529
local CHAINBOUND_SEC = 10.0
-- 一人連携が技の数 (max_ws) で終わった直後は、同じフェイスの合図を無視する秒数 (アークGK は 2 発目の後に葉隠を使うことがある)
local SOLO_DONE_IGNORE_SEC = 6.0

local function ability_name(cat, id)
    local key = CATEGORY_RESOURCES[cat == 7 and 3 or cat]
    local t = key and res and res[key]
    local a = t and t[id]
    return a and (a.ja or a.en) or ("#" .. tostring(id))
end

-- -----------------------------------------------------------------------------
-- フェイスの一人連携待ち
--   一人連携を狙うフェイス (sc_dict.TRUST_SOLO) が条件のアビリティ (黙想・葉隠・石火之機) を使ったら、
--   一人連携が終わるまで自動WSを撃たない。
--   終わりの判定: 最後の技が分かっていればその技 / 光→光・闇→闇で連携が閉じた /
--                 フェイスのWSが solo_gap 秒来なかった / アビリティの後 solo_start_wait 秒WSが出なかった
-- -----------------------------------------------------------------------------
local JOB_ABILITY_CATEGORY = 6

-- 0x028 カテゴリ 6: フェイスがアビリティを使った
local function handle_trust_ability(p)
    if settings.trust_solo == false then return end
    local actor_id = p["Actor"]
    if state.player_id ~= nil and actor_id == state.player_id then return end
    local mob = windower.ffxi.get_mob_by_id(actor_id)
    if not mob or not (mob.in_party or mob.in_alliance) then return end
    local def = sc_dict.find_trust_solo(mob.name)
    if not def then return end

    local ability = res and res.job_abilities and res.job_abilities[safe_num(p["Param"], 0)]
    local ability_ja = ability and ability.ja
    for _, trigger in ipairs(def.abilities) do
        if trigger == ability_ja then
            local now = safe_num(os.clock(), 0)
            local done = state.solo_done and state.solo_done[actor_id]
            if done and now - done < SOLO_DONE_IGNORE_SEC then
                log_debug("TRUST_SOLO", string.format("合図を無視: %s が %s を使用 (一人連携が終わった直後)", def.ja or tostring(mob.name), ability_ja))
                return
            end
            local wait_until = now + safe_num(settings.solo_start_wait, 12.0)
            local solo = state.solos[actor_id]
            if solo then
                -- 一人連携の途中で別の合図を使った (黙想 → WS → 葉隠 など): 数えた回数はそのままで待ちを延ばす
                solo.until_time = math.max(safe_num(solo.until_time, 0), wait_until)
                log_debug("TRUST_SOLO", string.format("待ち延長: %s が %s を使用 (WS %d 回の後)", solo.name, ability_ja, solo.count))
                return
            end
            solo = {
                name = def.ja or tostring(mob.name), ability = ability_ja,
                until_time = wait_until, count = 0, last_ws = def.last_ws, max_ws = def.max_ws,
            }
            state.solos[actor_id] = solo
            log_debug("TRUST_SOLO", string.format("待ち開始: %s が %s を使用 (一人連携が終わるまで自動WSを止める)", solo.name, ability_ja))
            return
        end
    end
end

-- 一人連携中のフェイスがWSを撃った: 次のWSを solo_gap 秒待つ。最後の技なら待つのをやめる
local function track_trust_solo_ws(actor_id, ws_name)
    local solo = state.solos[actor_id]
    if not solo then return end
    solo.count = solo.count + 1
    for _, last in ipairs(solo.last_ws or {}) do
        if last == ws_name then
            log_debug("TRUST_SOLO", string.format("待ち終了: %s の一人連携が最後の技 %s まで進んだ (WS %d 回)", solo.name, ws_name, solo.count))
            state.solos[actor_id] = nil
            state.solo_just_ended = true   -- この技で出来た連携には続けない (apply_chain_result が連携を閉じる)
            return
        end
    end
    if solo.max_ws and solo.count >= solo.max_ws then
        log_debug("TRUST_SOLO", string.format("待ち終了: %s の一人連携が %d 発目 %s で終わった", solo.name, solo.count, ws_name))
        state.solos[actor_id] = nil
        state.solo_done = state.solo_done or {}
        state.solo_done[actor_id] = safe_num(os.clock(), 0)
        return
    end
    solo.until_time = safe_num(os.clock(), 0) + safe_num(settings.solo_gap, 11.0)
    log_debug("TRUST_SOLO", string.format("%s の一人連携 %d 発目: %s", solo.name, solo.count, ws_name))
end

-- 自分の WS 結果を自動実行の記録と突き合わせる
local function track_own_action(p, cat)
    local pending = state.pending_ws
    if cat == 3 then
        local ws_id = safe_num(p["Param"], 0)
        local msg = safe_num(p["Target 1 Action 1 Message"], 0)
        local dmg = safe_num(p["Target 1 Action 1 Param"], 0)
        local name = ability_name(3, ws_id)
        local result = (msg == 188 and "ミス") or (msg == 189 and "効果なし") or string.format("%dダメージ", dmg)
        local level = (msg == 188 or msg == 189) and "WARN" or "INFO"
        local src = pending and "自動" or "手動"
        log_event(level, "WS_RESULT", string.format("[%s] %s → %s", src, name, result))
        if pending and pending.name ~= name and ws_id_by_name(pending.name) ~= ws_id then
            log_event("WARN", "WS_RESULT", string.format("自動入力 %s と違うWS %s が発動した", pending.name, name))
        end
        state.pending_ws = nil
    elseif cat == 7 and safe_num(p["Param"], 0) == WS_READY_INTERRUPT then
        log_event("WARN", "WS_FAIL", string.format("%s の構えが中断された", pending and pending.name or "WS"))
        state.pending_ws = nil
    end
end

local function handle_action_packet(data)
    local p = packets.parse("incoming", data)
    if not p then
        log_event("WARN", "PACKET", "0x028 の解析に失敗")
        return
    end
    local cat = safe_num(p["Category"], 0)
    -- 渾然一体 (msg 529「連携待機の状態になった」): 次の WS が必ず連携になる
    if safe_num(p["Target 1 Action 1 Message"], 0) == CHAINBOUND_MESSAGE then
        local who = windower.ffxi.get_mob_by_id(p["Actor"])
        local cb_now = safe_num(os.clock(), 0)
        state.chainbound = {target = p["Target 1 ID"], start_time = cb_now, until_time = cb_now + CHAINBOUND_SEC}
        log_debug("PACKET_SC", string.format("連携待機: %s が渾然一体を使用 (約 3 秒後からの最初の WS が連携になる)", tostring(who and who.name or p["Actor"])))
        return
    end
    if cat == JOB_ABILITY_CATEGORY then
        handle_trust_ability(p)
        return
    end
    if not CATEGORY_NAMES[cat] then return end

    -- ジャンプなど一部のアビリティは WS と同じカテゴリ 3 で届く (番号はアビリティのもの)。
    -- WS の番号として読むと別の技 (ジャンプ 66 → ラファールアクス) になり、偽の始点を作るので、WS として扱わない
    if cat == 3 and JA_RESULT_MESSAGES[safe_num(p["Target 1 Action 1 Message"], 0)] then
        return
    end

    local is_self = state.player_id ~= nil and p["Actor"] == state.player_id
    if is_self then track_own_action(p, cat) end

    local actor_mob = windower.ffxi.get_mob_by_id(p["Actor"])
    local outsider = not is_party_actor(actor_mob)
    if outsider then
        -- パーティ外の人でも、自分が狙っている敵に撃った技は連携に関わる (七支公など、パーティ外と一緒に戦う敵)
        local t = (cat == 3 or cat == 11) and actor_mob and windower.ffxi.get_mob_by_target("t")
        if not (t and t.id == p["Target 1 ID"] and t.id ~= p["Actor"]) then return end
    elseif not is_self and (cat == 3 or cat == 11) then
        -- パーティの人でも、自分が狙っている敵と別の敵への技は連携に関わらない
        -- (リンバスなど、敵を多量にリンクさせて個別に倒す場所では、仲間は別の敵と戦っている)
        local t = windower.ffxi.get_mob_by_target("t")
        if t and t.id ~= p["Target 1 ID"] then
            state.other_mob_ignored = safe_num(state.other_mob_ignored, 0) + 1
            return
        end
    end
    local actor_name = (outsider and "(PT外) " or "") .. tostring(actor_mob.name or "")
    local param = safe_num(p["Param"], 0)

    -- この技で連携が発生したか (追加効果メッセージで判定)
    local add_msg = p["Target 1 Action 1 Has Added Effect"] and safe_num(p["Target 1 Action 1 Added Effect Message"], 0) or 0
    local chain = SKILLCHAIN_MESSAGES[add_msg]

    local res_table = CATEGORY_RESOURCES[cat] and res and res[CATEGORY_RESOURCES[cat]]
    if not res_table then return end

    -- カテゴリ 11 で届く通常攻撃は WS ではない。連携・連携待機 (渾然一体)・一人連携のどれにも数えない
    -- (実測 2026-10-11: アシェラの通常攻撃を WS と読んで連携待機を消し、5 回中 3 回、待機に合わせた WS を撃てなかった)
    if cat == 11 and AUTO_ATTACK_MESSAGES[safe_num(p["Target 1 Action 1 Message"], 0)] then return end

    -- 一人連携中のフェイスのWSを数える (連携が閉じた場合は apply_chain_result が待ちを解く)
    -- 回復・強化の技 (238: HP回復 / 194: 強化 / 159: 状態異常回復) は一人連携の技として数えない
    local solo_msg = safe_num(p["Target 1 Action 1 Message"], 0)
    if not is_self and not (solo_msg == 238 or solo_msg == 194 or solo_msg == 159) then
        track_trust_solo_ws(p["Actor"], ability_name(cat, param))
    end

    local target_id = p["Target 1 ID"]
    local landed = not NO_HIT_MESSAGES[solo_msg]
    local ws_def = res_table[param]

    -- 連携待機 (渾然一体) は、次に当たった WS で使われて終わる。この WS は直前の属性に関係なく連携になる。
    -- 光/闇を持つ WS で出来た光/闇には、もう続けられない (wiki 24407: 渾然一体→不動(光)→不動(連携発生せず))
    local close_reason = nil
    local cb = state.chainbound
    if cb and cb.target == target_id and landed then
        state.chainbound = nil
        if safe_lt(safe_num(os.clock(), 0), safe_num(cb.until_time, 0)) and (chain == "光" or chain == "闇") and ws_def then
            local lv3 = is_self and cat == 3 and aeonic_prop(ws_def.en)
            for _, key in ipairs({"skillchain_a", "skillchain_b", "skillchain_c"}) do
                if ws_def[key] == "Light" or ws_def[key] == "Darkness" then lv3 = true end
            end
            if lv3 then close_reason = "連携待機に光/闇の WS" end
        end
        -- 待機の受付が開く前 (付いてから約 3 秒以内) に当たった WS は連携にならず、待機も消える。
        -- この WS は始点にもならない (実測 2026-10-11 19:48:17: 0 秒後に当たった照破に、次の照破が連携しなかった)
        if not chain and safe_lt(safe_num(os.clock(), 0), safe_num(cb.until_time, 0)) then
            clear_sc_state()
            state.last_packet_sc_time = safe_num(os.clock(), 0)
            log_debug("PACKET_SC", string.format("連携待機が空振り: %s %s (待機から %.1f 秒。始点に数えない)", actor_name,
                ability_name(cat, param), safe_num(os.clock(), 0) - safe_num(cb.start_time, 0)))
            return
        end
    end

    -- この技のあとは自分の WS が連携しないと分かっているもの (sc_dict.NO_FOLLOW): 連携は続けず、次は始点から
    if not is_self and landed and not (solo_msg == 238 or solo_msg == 194 or solo_msg == 159)
        and sc_dict.is_no_follow(actor_mob.name, ws_def and ws_def.ja) then
        clear_sc_state()
        state.last_packet_sc_time = safe_num(os.clock(), 0)
        log_debug("PACKET_SC", string.format("No follow: %s %s%s (この技には続けない。次は始点から)", actor_name, ability_name(cat, param),
            chain and (" = " .. chain) or ""))
        return
    end

    local kind = is_self and "self" or ((actor_mob and actor_mob.spawn_type == 14) and "trust" or "player")
    if kind == "player" and cat == 3 and landed then
        record_pt_ws(p["Actor"], actor_name, ability_name(cat, param))
    end

    if chain then
        local self_only = state.sc_self_only and is_self
        apply_chain_result(chain, actor_name, "PACKET_SC", target_id, close_reason)
        state.sc_self_only = self_only   -- 他の人の WS が一度でも入ったら、この連携は自分だけのものではない
        state.sc_last_kind = kind
        return
    end

    -- ミス・効果なしの技は連携の初段にならない (今の連携窓もそのまま)
    local hit_msg = safe_num(p["Target 1 Action 1 Message"], 0)
    if NO_HIT_MESSAGES[hit_msg] then
        log_debug("PACKET_SC", string.format("No opener: %s %s (msg %d)", actor_name, ability_name(cat, param), hit_msg))
        return
    end

    -- 連携しなかった技は新しい初段になる。連携属性を優先順 (a, b, c) ですべて保持する
    local ability = res_table[param]
    local props = {}
    if ability then
        for _, key in ipairs({"skillchain_a", "skillchain_b", "skillchain_c"}) do
            local en = ability[key]
            if en and en ~= "" then table.insert(props, sc_dict.EN_TO_JA_SC[en] or en) end
        end
        -- フェイスの技で res に連携属性が入っていないものを補う
        if #props == 0 and cat == 11 and not is_self then
            for _, prop in ipairs(sc_dict.TRUST_WS_EXTRA[ability.ja] or {}) do table.insert(props, prop) end
        end
    end
    -- 自分のイオニックWSにはアフターマスの光/闇が加わる (他人の武器は分からないので自分だけ)
    local lv3 = is_self and cat == 3 and ability and aeonic_prop(ability.en)
    if lv3 then table.insert(props, 1, lv3) end
    -- 連携属性が取れない技は窓を開かない (前回の属性も使い回さない)
    if #props > 0 then
        state.sc_active = true
        state.sc_target = target_id
        state.last_packet_sc_time = safe_num(os.clock(), 0)
        state.sc_props = props
        state.sc_property = table.concat(props, "/")
        state.sc_step = 0
        state.sc_aeonic = lv3 and true or false
        state.solo_just_ended = false
        state.sc_expiration = safe_num(os.clock(), 0) + sc_window_sec(0)
        state.sc_start_time = safe_num(os.clock(), 0)
        state.sc_starter = actor_name
        state.sc_self_only = is_self   -- 自分の始点なら、ここから自分だけの連携
        state.sc_last_kind = kind
        log_debug("PACKET_SC", string.format("Opener: %s from %s (Category: %d / Param: %d)", state.sc_property, actor_name, cat, param))
    end
end

-- 0x029 アクションメッセージ: 自分の行動の失敗理由 (射程外・TP不足など)
local function handle_message_packet(data)
    if not state.player_id then return end
    local p = packets.parse("incoming", data)
    if not p or (p["Actor"] ~= state.player_id and p["Target"] ~= state.player_id) then return end
    local msg = safe_num(p["Message"], 0)
    if FAIL_MESSAGES[msg] and state.pending_ws and p["Actor"] == state.player_id then
        log_event("WARN", "WS_FAIL", string.format("%s: %s (msg %d)", state.pending_ws.name, FAIL_MESSAGES[msg], msg))
        state.pending_ws = nil
        if FAIL_MESSAGES[msg] == "対象が見えない" then state.unseen_until = safe_num(os.clock(), 0) + 2.0 end
    end
end

-- incoming chunk パケットキャッチ
windower.register_event("incoming chunk", guarded("PACKET", function(id, data, modified, injected, blocked)
    id = safe_num(id, 0)
    if id == 0x028 then
        handle_action_packet(data)
    elseif id == 0x029 then
        handle_message_packet(data)
    end
end))

-- incoming text メッセージキャッチ
windower.register_event("incoming text", guarded("TEXT", function(original, modified, mode, modified_mode, blocked)
    if not original then return end
    -- チャットログは Shift-JIS で届くため、UTF-8 のソース文字列と比較する前に変換する
    local text = original
    if windower.from_shift_jis then
        local conv_ok, converted = pcall(windower.from_shift_jis, original)
        if conv_ok and converted then text = converted end
    end
    if not text:find("技連携・", 1, true) then return end

    -- %a は ASCII 英字のみで日本語に一致しないため、既知の連携名を直接照合する
    -- (「技連携・光」は「技連携・極光」に部分一致しないので照合順は問わない)
    for sc_name in pairs(sc_dict.SC_ELEMENTS) do
        if text:find("技連携・" .. sc_name, 1, true) then
            apply_chain_result(sc_name, nil, "TEXT_SC")
            break
        end
    end
end))

-- ジョブ変更直後は使えるWSの一覧が更新されていないことがあるため、少し待ってから点検する
local function schedule_priority_check()
    if coroutine and coroutine.schedule then
        coroutine.schedule(guarded("CHECK", function() check_priority_list(true) end), 5)
    end
end

windower.register_event("load", guarded("LOAD", function()
    update_job_profile()
    log_debug("SYSTEM", "OmniChain v" .. _addon.version .. " Loaded")
    schedule_priority_check()
end))
windower.register_event("login", guarded("LOGIN", function()
    update_job_profile()
    schedule_priority_check()
end))
windower.register_event("job change", guarded("JOB", function()
    update_job_profile()
    schedule_priority_check()
end))
-- エリア移動時は連携窓を破棄する (移動先で前エリアの属性を使わないため)
windower.register_event("zone change", guarded("ZONE", function()
    clear_sc_state()
    pt_hist = {}
    state.pending_ws = nil
    state.solos = {}
    flush_log()
end))
windower.register_event("logout", guarded("LOGOUT", function()
    clear_sc_state()
    pt_hist = {}
    state.pending_ws = nil
    state.solos = {}
    state.player_id = nil
    flush_log()
end))
windower.register_event("unload", function()
    if hud then
        if hud:draggable() ~= move_allowed then hud:draggable(move_allowed) end
        hud:hide()
    end
    if grip then grip:destroy() end
    log_debug("SYSTEM", "OmniChain Unloaded")
    flush_log(true)
end)

local function on_off_arg(arg, current)
    if arg == "on" then return true elseif arg == "off" then return false end
    return not current
end

windower.register_event("addon command", guarded("CMD", function(cmd, ...)
    local args = {...}
    cmd = cmd and cmd:lower()
    local sub = args[1] and args[1]:lower()

    if cmd == "enable" or cmd == "on" then
        settings.enabled = true
        config.save(settings)
        chat_msg("[OmniChain] 自動連携機能: ON")
        log_debug("CMD", "Auto SC Enabled")

    elseif cmd == "disable" or cmd == "off" then
        settings.enabled = false
        config.save(settings)
        chat_msg("[OmniChain] 自動連携機能: OFF")
        log_debug("CMD", "Auto SC Disabled")

    elseif cmd == "hud" or cmd == "gui" then
        settings.show_hud = on_off_arg(sub, settings.show_hud)
        config.save(settings)
        chat_msg(string.format("[OmniChain] HUD画面表示: %s", settings.show_hud and "ON" or "OFF"))
        log_debug("CMD", "HUD Toggled: " .. tostring(settings.show_hud))

    elseif cmd == "size" and tonumber(sub) then
        local size = set_size(tonumber(sub))
        save_hud_settings()
        chat_msg(string.format("[OmniChain] HUD の文字サイズを %d に変更しました。", size))

    elseif cmd == "log" then
        if sub == "clear" then
            monitor.buffer = {}
            local f = io.open(log_file_path, "w")
            if f then f:write("") f:close() end
            chat_msg("[OmniChain] デバッグログをクリアしました。")
        elseif sub == "on" or sub == "off" then
            settings.debug_logging = (sub == "on")
            config.save(settings)
            chat_msg(string.format("[OmniChain] デバッグログのファイル記録: %s", settings.debug_logging and "ON" or "OFF"))
        elseif sub == "tail" or sub == "err" then
            -- 直近の出来事をチャットに出す (err は ERROR/WARN のみ)
            local n = math.max(1, math.min(30, tonumber(args[2]) or 10))
            local picked = {}
            for i = #monitor.recent, 1, -1 do
                local e = monitor.recent[i]
                if sub == "tail" or e.level == "ERROR" or e.level == "WARN" then
                    table.insert(picked, 1, e)
                    if #picked >= n then break end
                end
            end
            chat_msg(string.format("=== OmniChain 直近 %d 件 (%s) ===", #picked, sub == "err" and "エラー/警告" or "全て"))
            for _, e in ipairs(picked) do
                chat_msg(string.format("%s [%s][%s] %s", e.time, e.level, e.cat, utf8_trim(e.msg, 120)), LEVEL_CHAT_COLORS[e.level] or 207)
            end
        else
            flush_log(true)
            chat_msg(string.format("[OmniChain] デバッグログ記録: %s (保存先: %s)", settings.debug_logging and "ON" or "OFF", log_file_path))
            chat_msg(string.format("[OmniChain] 起動後の件数 ERROR:%d WARN:%d INFO:%d",
                monitor.counts.ERROR or 0, monitor.counts.WARN or 0, monitor.counts.INFO or 0))
        end

    elseif cmd == "check" then
        if check_priority_list(false) then
            chat_msg(string.format("[OmniChain] %s の優先リスト %d件はすべて使用可能です。", state.active_job, #state.ws_priority))
        end

    elseif cmd == "start" then
        if sub == "manual" or sub == "auto" then
            settings.start_mode = sub
            config.save(settings)
        end
        chat_msg(settings.start_mode == "manual"
            and string.format("[OmniChain] 始点: 手動 (1回目は自分で撃つ。誰かの始点から %.1f 秒待って自動連携)", safe_num(settings.follow_wait, 6.0))
            or "[OmniChain] 始点: 自動 (1回目も自動で撃つ)")
        log_debug("CMD", "Start mode: " .. tostring(settings.start_mode))

    elseif cmd == "wait" then
        local sec = tonumber(sub)
        if sec and sec >= 0 and sec <= 9 then
            settings.follow_wait = sec
            config.save(settings)
        elseif sub then
            chat_msg("[OmniChain] 待ち秒数は 0〜9 で指定してください (連携の受付は最大10秒)。")
        end
        chat_msg(string.format("[OmniChain] 手動始点モードの待ち時間: %.1f 秒", safe_num(settings.follow_wait, 6.0)))

    elseif cmd == "minfollow" then
        -- 直前のWSから次の自動WSまでの最短秒数: //omni minfollow <秒>
        local sec = tonumber(sub)
        if sec and sec >= MIN_FOLLOW_FLOOR and sec <= 8 then
            settings.min_follow = sec
            config.save(settings)
        elseif sub then
            chat_msg("[OmniChain] 秒数は 4〜8 で指定してください (例: //omni minfollow 4)。")
        end
        chat_msg(string.format("[OmniChain] 直前のWSから次の自動WSまでの最短: %.1f 秒", math.max(MIN_FOLLOW_FLOOR, safe_num(settings.min_follow, MIN_FOLLOW_FLOOR))))
        log_debug("CMD", "Min follow: " .. tostring(settings.min_follow))

    elseif cmd == "focuspeople" then
        -- 最大威力の WS にする人数 (自分を含む): //omni focuspeople <人数>
        local v = tonumber(sub)
        if v and v >= 2 and v <= 18 then
            settings.focus_people = math.floor(v)
            config.save(settings)
        elseif sub then
            chat_msg("[OmniChain] 人数は 2〜18 で指定してください (例: //omni focuspeople 3)。")
        end
        chat_msg(string.format("[OmniChain] 同じ敵を狙っている人が自分を入れて %d 人以上のとき、最大威力の WS", safe_num(settings.focus_people, 3)))
        log_debug("CMD", "Focus people: " .. tostring(settings.focus_people))

    elseif cmd == "focustp" then
        -- 最大威力の WS を撃つ TP: //omni focustp <TP>
        local v = tonumber(sub)
        if v and v >= 1000 and v <= 3000 then
            settings.focus_tp = v
            config.save(settings)
        elseif sub then
            chat_msg("[OmniChain] TP は 1000〜3000 で指定してください (例: //omni focustp 1500)。")
        end
        chat_msg(string.format("[OmniChain] 最大威力の WS を撃つ TP: %d 以上", safe_num(settings.focus_tp, 1500)))
        log_debug("CMD", "Focus TP: " .. tostring(settings.focus_tp))

    elseif cmd == "focus" then
        -- 同じ敵を狙っている人が多いときは最大威力の WS: //omni focus [on|off]
        if sub == "on" or sub == "off" then
            settings.focus_max = (sub == "on")
            config.save(settings)
        end
        chat_msg(string.format("[OmniChain] 全員が同じ敵のとき最大威力の WS: %s (プライム武器ならそのWS、それ以外はエンピリアンWS。侍の童子切安綱は照破)",
            settings.focus_max ~= false and "ON" or "OFF"))
        log_debug("CMD", "Focus: " .. tostring(settings.focus_max))

    elseif cmd == "toss" then
        -- PT の人へのトス: //omni toss [on|off]
        if sub == "on" or sub == "off" then
            settings.toss = (sub == "on")
            config.save(settings)
        end
        chat_msg(string.format("[OmniChain] PT の人へのトス: %s (近いときだけ、相手の次の WS を予測して属性を合わせる)",
            settings.toss ~= false and "ON" or "OFF"))
        log_debug("CMD", "Toss: " .. tostring(settings.toss))

    elseif cmd == "reach" then
        -- 近接 WS を撃ってよい距離 (distanceplus に出る数字): //omni reach <距離>
        local d = tonumber(sub)
        if d and d >= 1 and d <= 8 then
            settings.ws_reach = d
            config.save(settings)
        elseif sub then
            chat_msg("[OmniChain] 距離は 1〜8 で指定してください (例: //omni reach 3.5)。")
        end
        chat_msg(string.format("[OmniChain] 近接 WS を撃つ距離: %.1f 以下 (distanceplus の数字)", safe_num(settings.ws_reach, 3.5)))
        log_debug("CMD", "WS reach: " .. tostring(settings.ws_reach))

    elseif cmd == "openpt" then
        -- 前の WS が自分・PT の人のときの、受付が開くまでの秒数 (試験用): //omni openpt <秒>
        local sec = tonumber(sub)
        if sec and sec >= 0.5 and sec <= 3.3 then
            settings.open_player = sec
            config.save(settings)
        elseif sub then
            chat_msg("[OmniChain] 秒数は 0.5〜3.3 で指定してください (3.3 = 今までどおり)。")
        end
        chat_msg(string.format("[OmniChain] 前の WS が人 (自分・PT) のときの受付: %.1f 秒 (フェイスは 3.3 秒)", safe_num(settings.open_player, SC_OPEN_SEC)))
        log_debug("CMD", "Open player: " .. tostring(settings.open_player))

    elseif cmd == "solo" then
        -- フェイスの一人連携待ち: //omni solo [on|off] / start <秒> / gap <秒>
        local sec = tonumber(args[2])
        if sub == "start" or sub == "gap" then
            if sec and sec >= 1 and sec <= 30 then
                if sub == "start" then settings.solo_start_wait = sec else settings.solo_gap = sec end
                config.save(settings)
            else
                chat_msg("[OmniChain] 秒数は 1〜30 で指定してください (例: //omni solo gap 6)。")
            end
        elseif sub == "on" or sub == "off" then
            settings.trust_solo = (sub == "on")
            if not settings.trust_solo then state.solos = {} end
            config.save(settings)
        end
        chat_msg(string.format("[OmniChain] フェイスの一人連携待ち: %s (アビリティの後 %.1f 秒 / WSの間隔 %.1f 秒)",
            settings.trust_solo ~= false and "ON" or "OFF", safe_num(settings.solo_start_wait, 12.0), safe_num(settings.solo_gap, 11.0)))
        log_debug("CMD", "Trust solo wait: " .. tostring(settings.trust_solo))

    elseif cmd == "reload" or cmd == "load" then
        update_job_profile()
        chat_msg(string.format("[OmniChain] 設定ファイルを再ロードしました。(Job: %s / 武器: %s)", state.active_job, state.active_weapon))

    elseif cmd == "status" then
        chat_msg("=== OmniChain 設定ステータス ===")
        chat_msg(string.format("機能ステータス: %s / 最小TP: %d / HUD表示: %s", settings.enabled and "ON" or "OFF", safe_num(settings.min_tp, 1000), settings.show_hud and "ON" or "OFF"))
        chat_msg(string.format("始点: %s", settings.start_mode == "manual"
            and string.format("手動 (待ち %.1f 秒)", safe_num(settings.follow_wait, 6.0)) or "自動"))
        chat_msg(string.format("フェイスの一人連携待ち: %s (アビリティの後 %.1f 秒 / WSの間隔 %.1f 秒)",
            settings.trust_solo ~= false and "ON" or "OFF", safe_num(settings.solo_start_wait, 12.0), safe_num(settings.solo_gap, 11.0)))
        chat_msg(string.format("現在ジョブ: %s / 武器種: %s", state.active_job, state.active_weapon))
        chat_msg(string.format("WS優先順位: %s", table.concat(state.ws_priority, " > ")))

    else
        chat_msg("=== OmniChain コマンドヘルプ ===")
        chat_msg("//omni enable / disable       : 自動連携 ON / OFF 切替")
        chat_msg("//omni start manual / auto    : 1回目のWSを自分で撃つ / 自動で撃つ")
        chat_msg("//omni wait <秒>              : 手動始点モードで自動WSを撃つまで待つ秒数 (初期値 6)")
        chat_msg("//omni solo [on|off]          : フェイスの一人連携が終わるまで待つ (start <秒> / gap <秒> で調整)")
        chat_msg("//omni hud [on|off]           : HUDオーバーレイ画面の表示切替")
        chat_msg("//omni size <数>              : HUD の文字サイズ (6〜40)。HUD上のホイール / 右下の角のドラッグでも変更可")
        chat_msg("//omni log [on|off|clear]     : ログファイル記録の切替・消去")
        chat_msg("//omni log tail [n] / err [n] : 直近の記録 / エラーと警告をチャット表示")
        chat_msg("//omni check                  : 優先リストのWSが使えるか点検")
        chat_msg("詳しくは addons/OmniChain/COMMANDS.txt を参照")
        chat_msg("//omni reload                 : JSON設定ファイルの再読み込み")
        chat_msg("//omni status                 : 現在の設定一覧表示")
    end
end))

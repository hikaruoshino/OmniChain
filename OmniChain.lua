-- =============================================================================
-- OmniChain.lua : 全22ジョブ ＆ 全14武器種対応 自動技連携アドオン (v7.2.0 - 手動始点モード搭載)
-- =============================================================================

_addon.name     = "OmniChain"
_addon.author   = "hikaruoshino"
_addon.version  = "7.2.0"
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
-- リアルタイム監視 (//omni mon)
defaults.monitor = {
    show = false,        -- 監視オーバーレイ表示
    packets = false,     -- パーティーの技パケットを詳細に記録 (0x028 / 0x029)
    chat_errors = true,  -- エラー・警告をその場でチャットに表示
    console = true,      -- Windower の console.log に出た他アドオンのエラーも監視
    lines = 10,          -- オーバーレイに出す件数
    pos = {x = 20, y = 260},
}
defaults.min_tp = 1000
defaults.party_sync = true
defaults.auto_mode = "flexible" -- "flexible", "strict", "lead_only"
defaults.wait_delay = 1.2
defaults.start_mode = "auto"  -- "auto": 1回目も自動 / "manual": 1回目は自分 (誰かの始点に続けて自動連携)
defaults.follow_wait = 6.0    -- manual: 直前のWSが当たってから自動WSを撃つまでの秒数 (他人の横槍を待つ)
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
if type(settings.monitor) ~= "table" then settings.monitor = {} end
local mon_cfg = settings.monitor

-- カラーコード装飾 (DirectWrite UTF-8)
local function color_text(str, r, g, b)
    return string.format("\\cs(%d,%d,%d)%s\\cr",safe_num(r, 255), safe_num(g, 255), safe_num(b, 255), tostring(str or ""))
end

-- -----------------------------------------------------------------------------
-- リアルタイム監視＆ログ記録 (omnichain_debug.log)
--   ・ログはメモリに溜めて数秒ごとにまとめて書く (毎回の open/close を避ける)
--   ・1MB を超えたら omnichain_debug.old.log に退避する
--   ・ERROR / WARN はその場でチャットに出す (同じ内容は10秒間まとめる)
--   ・直近の出来事はメモリにも残し、監視オーバーレイと //omni log tail で見られる
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
    counts = {ERROR = 0, WARN = 0, INFO = 0, PKT = 0},
    throttle = {},        -- チャット表示の間引き: key -> {time, suppressed}
    dirty = true,         -- オーバーレイの再描画が必要か
    hud = nil,
}

local LEVEL_COLORS = {
    ERROR = {255, 90, 90},
    WARN  = {255, 200, 80},
    INFO  = {200, 200, 200},
    PKT   = {120, 200, 255},
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
    monitor.dirty = true

    if is_alert then
        -- 失敗原因を失わないよう、エラー系はすぐ書き出す
        flush_log(true)
        if mon_cfg.chat_errors ~= false then
            chat_msg(string.format("[OmniChain:%s] %s: %s", level, category, utf8_trim(message, 120)), LEVEL_CHAT_COLORS[level])
        end
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

local function monitor_hud_create()
    if monitor.hud then return end
    local pos = type(mon_cfg.pos) == "table" and mon_cfg.pos or {}
    monitor.hud = texts.new("", {
        pos = {x = safe_num(pos.x, 20), y = safe_num(pos.y, 260)},
        text = {font = "Meiryo", size = 9, alpha = 255},
        bg = {alpha = 170, red = 0, green = 0, blue = 0},
        padding = 4,
        flags = {draggable = true},
    })
    monitor.dirty = true
end

local function monitor_hud_render()
    if not mon_cfg.show then
        if monitor.hud then monitor.hud:hide() end
        return
    end
    monitor_hud_create()
    if not monitor.dirty then return end
    monitor.dirty = false

    local c = monitor.counts
    local lines = {}
    lines[1] = string.format("== OmniChain Monitor ==  %s  %s  ERR:%s WARN:%s",
        mon_cfg.packets and color_text("PKT:ON", 120, 200, 255) or color_text("PKT:OFF", 140, 140, 140),
        settings.debug_logging and color_text("LOG:ON", 100, 255, 100) or color_text("LOG:OFF", 140, 140, 140),
        color_text(tostring(c.ERROR or 0), 255, 90, 90),
        color_text(tostring(c.WARN or 0), 255, 200, 80))

    local max_lines = math.max(1, math.min(30, safe_num(mon_cfg.lines, 10)))
    local recent = monitor.recent
    for i = math.max(1, #recent - max_lines + 1), #recent do
        local e = recent[i]
        local col = LEVEL_COLORS[e.level] or LEVEL_COLORS.INFO
        lines[#lines + 1] = color_text(string.format("%s [%s] %s", e.time, e.cat, utf8_trim(e.msg, 60)), col[1], col[2], col[3])
    end
    monitor.hud:text(table.concat(lines, string.char(10)))
    monitor.hud:show()
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

local function action_message_text(id)
    if FAIL_MESSAGES[id] then return FAIL_MESSAGES[id] end
    local m = res and res.action_messages and res.action_messages[id]
    return m and m.en or ("message " .. tostring(id))
end

-- -----------------------------------------------------------------------------
-- Windower 本体の console.log 監視 (他アドオンのエラーも拾う)
--   Lua からは更新日時が取れないため、ファイルサイズが増えたら追記分だけ読む
-- -----------------------------------------------------------------------------
local console_path = (windower.windower_path or (windower.addon_path:match("^(.*[/\\])addons[/\\]") or "")) .. "console.log"
local CONSOLE_CHECK_SEC = 5
local CONSOLE_READ_MAX = 64 * 1024
local console_watch = {offset = nil, last_check = -100}

local CONSOLE_ERROR_PATTERNS = {
    "Lua runtime error", "Lua syntax error", "Lua error", "has detected an error",
    "Cannot find", "[Ee]rror:", "stack traceback", "attempt to ",
}

-- エラー文 → 対処のヒント
local CONSOLE_HINTS = {
    {"Cannot find the include file %(([^)]+)%)", "インクルード先 %1 が無い: ファイルを置くか include のパスを直す"},
    {"attempt to compare", "型の違う値を比較している: tonumber 等で数値にそろえる"},
    {"attempt to index", "nil を参照している: 使う前に nil チェックを入れる"},
    {"attempt to call", "存在しない関数を呼んでいる: 関数名と読み込み順を確認"},
    {"attempt to perform arithmetic", "nil/文字列で計算している: 数値化と nil チェック"},
    {"attempt to concatenate", "nil を文字列連結している: tostring で包む"},
    {"unfinished string", "構文エラー: 引用符の閉じ忘れ"},
    {"unexpected symbol", "構文エラー: 記号の誤り"},
    {"expected", "構文エラー: end や括弧の不足"},
    {"is not loaded", "読み込んでいないアドオンにコマンドを送った (//lua l で読み込む)"},
}

local function console_hint(text)
    for _, h in ipairs(CONSOLE_HINTS) do
        local cap = text:match(h[1])
        if cap then return (h[2]:gsub("%%1", (tostring(cap):gsub("%%", "%%%%")))) end
    end
    return nil
end

local function is_console_error(text)
    for _, pat in ipairs(CONSOLE_ERROR_PATTERNS) do
        if text:find(pat) then return true end
    end
    return false
end

-- console.log は UTF-8 だが、念のため UTF-8 として不正なら Shift-JIS とみなして変換する
local function console_to_utf8(s)
    if not s:find("[\128-\255]") then return s end
    local stripped = s:gsub("[\194-\244][\128-\191]+", "")
    if not stripped:find("[\128-\255]") then return s end
    if windower.from_shift_jis then
        local ok, conv = pcall(windower.from_shift_jis, s)
        if ok and conv then return conv end
    end
    return s
end

-- 読み込んだ行から、同じ時刻に続くエラー行を1件にまとめる
local function parse_console_errors(chunk)
    local groups, cur = {}, nil
    for line in chunk:gmatch("[^\r\n]+") do
        local ts, body = line:match("^(%d+:%d+:%d+) > ?(.*)$")
        if not ts then ts, body = nil, line end
        body = console_to_utf8(body)
        local is_detail = body:find("^%s") or body:find("^%.%.%.") or body:find("%.lua:%d+:")
        if is_console_error(body) or (cur and is_detail and (ts == nil or ts == cur.time)) then
            if cur and (ts == nil or ts == cur.time) then
                table.insert(cur.parts, (body:gsub("^%s+", "")))
            else
                local addon = body:match("^([%w_%-]+)[: ]") or "?"
                -- "Lua error: ..." / "Error: ..." は Windower 本体のメッセージ
                if addon == "Lua" or addon == "Error" then addon = "Windower" end
                cur = {time = ts or "", addon = addon, parts = {body}}
                table.insert(groups, cur)
            end
        else
            cur = nil
        end
    end
    for _, g in ipairs(groups) do
        g.text = table.concat(g.parts, " / ")
        g.hint = console_hint(g.text)
    end
    return groups
end

local function read_console(from, to)
    local f = io.open(console_path, "rb")
    if not f then return nil end
    f:seek("set", from)
    local data = f:read(to - from) or ""
    f:close()
    return data
end

local function console_size()
    local f = io.open(console_path, "rb")
    if not f then return nil end
    local size = f:seek("end")
    f:close()
    return size
end

local function check_console_log(now)
    if mon_cfg.console == false then return end
    if now - console_watch.last_check < CONSOLE_CHECK_SEC then return end
    console_watch.last_check = now
    local size = console_size()
    if not size then return end
    if console_watch.offset == nil then
        -- 起動時点までの内容は報告しない (過去分は //omni console で見る)
        console_watch.offset = size
        return
    end
    if size < console_watch.offset then console_watch.offset = 0 end  -- Windower 再起動で作り直された
    if size == console_watch.offset then return end
    local from = math.max(console_watch.offset, size - CONSOLE_READ_MAX)
    local chunk = read_console(from, size)
    console_watch.offset = size
    if not chunk then return end
    for _, g in ipairs(parse_console_errors(chunk)) do
        -- チャットは途中で切れるため、対処のヒントを先に置く (原文の全体はログファイルに残る)
        log_event("WARN", "CONSOLE", string.format("[%s] %s%s", g.addon, g.hint and ("対処: " .. g.hint .. " | ") or "", g.text))
    end
end

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
    last_chain_name = nil,  -- パケットとチャットで同じ連携を二重に処理しないための記録
    last_chain_time = 0,
    last_packet_sc_time = -100,  -- パケットで連携状態を更新した時刻 (遅れて届くチャットの上書きを防ぐ)

    last_ws_time = 0,
    pending_ws = nil,       -- 自動実行したWSの結果待ち {name, time, tp}
    player_id = nil,
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
local function sc_window_sec()
    return settings.start_mode == "manual" and 10.0 or 8.0
end

-- manual: 自動WSを撃てるまでの残り秒数 (直前のWSが当たってから follow_wait 秒)。auto は常に 0
local function follow_wait_left(now)
    if settings.start_mode ~= "manual" then return 0 end
    return math.max(0, safe_num(state.sc_start_time, 0) + safe_num(settings.follow_wait, 6.0) - now)
end

local function find_best_ws_from_priority()
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

    if is_sc_window then
        -- opener_only: 先頭のWSは始点専用。連携中は2番目以降を先に探し、どれもつながらないときだけ先頭に戻る
        for pass = 1, (state.opener_only and 2 or 1) do
            for priority_idx, ws_name in ipairs(state.ws_priority) do
                local skip = state.opener_only and pass == 1 and priority_idx == first_idx
                local ws_info = not skip and is_executable_ws(ws_name, usable) and sc_dict.find_ws_info(ws_name, state.active_weapon)
                local lv3 = ws_info and aeonic_prop(ws_info.en)
                if lv3 then
                    ws_info = { ja = ws_info.ja, en = ws_info.en, sc = { lv3, unpack(ws_info.sc) } }
                end
                if ws_info then
                    local eval = sc_dict.evaluate_ws_for_sc(ws_info, state.sc_props or state.sc_property)
                    if eval then
                        return {
                            ws = ws_name,
                            result_sc = eval.result,
                            priority = priority_idx,
                            reason = string.format("優先度%d [%s ➔ %s (%s)]", priority_idx, state.sc_property, eval.result, ws_name)
                        }
                    end
                end
            end
        end

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
        if choice and follow_wait_left(now) <= 0 then
            state.last_ws_time = now
            state.pending_ws = {name = choice.ws, time = now, tp = tp}
            check_ws_usable(choice.ws, "EXECUTE")
            log_debug("EXECUTE", string.format("Executing WS: %s (%s) [TP: %d]", choice.ws, choice.reason, tp))
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
local SLOW_FRAME_SEC = 0.015
local function check_pending_ws(now)
    local p = state.pending_ws
    if p and now - safe_num(p.time, now) > PENDING_WS_TIMEOUT then
        state.pending_ws = nil
        log_event("WARN", "WS_TIMEOUT", string.format("%s を入力したが %.0f秒以内に発動しなかった (WS名・距離・行動不能などを確認)", p.name, PENDING_WS_TIMEOUT))
    end
end

windower.register_event("prerender", guarded("PRERENDER", function()
    local frame_start = os.clock()

    -- 監視: WS応答待ちのタイムアウト / ログの定期書き出し / 監視オーバーレイ
    check_pending_ws(frame_start)
    check_console_log(frame_start)
    if frame_start - monitor.last_flush > LOG_FLUSH_SEC then flush_log() end
    monitor_hud_render()

    -- 本体の処理が重いフレームを検出する (クライアントの引っかかり対策)
    local main_start = os.clock()
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

            local choice = find_best_ws_from_priority()
            if choice then
                local wait_left = follow_wait_left(now)
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

    local elapsed = os.clock() - main_start
    if elapsed > SLOW_FRAME_SEC then
        monitor.slow_frames = (monitor.slow_frames or 0) + 1
        monitor.slow_max = math.max(monitor.slow_max or 0, elapsed)
        -- 30秒に1回だけ、その間の件数と最大値をまとめて報告する
        if frame_start - (monitor.slow_reported or 0) > 30 then
            log_event("WARN", "PERF", string.format("prerender が重いフレーム %d 回 (最大 %.1fms)", monitor.slow_frames, monitor.slow_max * 1000))
            monitor.slow_reported = frame_start
            monitor.slow_frames, monitor.slow_max = 0, 0
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
end

-- チャットの「技連携・○○」はパケットより数秒 (実測4〜7秒) 遅れて届くことがある。
-- パケットで連携状態を更新してからこの秒数はチャットを無視し、パケットを取りこぼしたときの予備にだけ使う
local TEXT_SC_IGNORE_SEC = 10.0

-- 連携が発生した: 次段の判定は発生した連携だけを A1 とする (wiki: 3連携以降は前WSの他属性を無視)
local function apply_chain_result(sc_name, starter, source, target_id)
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

    if sc_dict.is_terminal_chain(prev, sc_name) then
        -- 光→光 / 闇→闇 の後、極光/黒闇の後はどの WS でも連携しない
        clear_sc_state()
        log_debug(source, string.format("Chain closed: %s (prev: %s)", sc_name, tostring(prev)))
        return
    end

    state.sc_active = true
    state.sc_props = { sc_name }
    state.sc_property = sc_name
    state.sc_expiration = now + sc_window_sec()
    state.sc_start_time = now
    if starter then state.sc_starter = starter end
    if target_id then state.sc_target = target_id end
    log_debug(source, string.format("Chain: %s (prev: %s)", sc_name, tostring(prev)))
end

-- アクションカテゴリ名 (監視ログ表示用)
local CATEGORY_NAMES = {[3] = "WS", [7] = "WS構え", [11] = "TP技", [13] = "ペット技"}
local WS_READY_INTERRUPT = 28787
-- 命中しなかったことを示す行動メッセージ (188/189: WS ミス・効果なし / 323/324: 技 効果なし・ミス)
local NO_HIT_MESSAGES = {[188] = true, [189] = true, [323] = true, [324] = true}

local function ability_name(cat, id)
    local key = CATEGORY_RESOURCES[cat == 7 and 3 or cat]
    local t = key and res and res[key]
    local a = t and t[id]
    return a and (a.ja or a.en) or ("#" .. tostring(id))
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
    if not CATEGORY_NAMES[cat] then return end

    local is_self = state.player_id ~= nil and p["Actor"] == state.player_id
    if is_self then track_own_action(p, cat) end

    local actor_mob = windower.ffxi.get_mob_by_id(p["Actor"])
    if not is_party_actor(actor_mob) then return end
    local actor_name = tostring(actor_mob.name or "")
    local param = safe_num(p["Param"], 0)

    -- この技で連携が発生したか (追加効果メッセージで判定)
    local add_msg = p["Target 1 Action 1 Has Added Effect"] and safe_num(p["Target 1 Action 1 Added Effect Message"], 0) or 0
    local chain = SKILLCHAIN_MESSAGES[add_msg]

    if mon_cfg.packets then
        local ab_id = cat == 7 and safe_num(p["Target 1 Action 1 Param"], 0) or param
        local extra
        if cat == 7 then
            extra = (param == WS_READY_INTERRUPT) and "中断" or "開始"
        else
            extra = string.format("msg:%d dmg:%d 追加:%s", safe_num(p["Target 1 Action 1 Message"], 0),
                safe_num(p["Target 1 Action 1 Param"], 0), chain and ("技連携・" .. chain) or tostring(add_msg))
        end
        log_event("PKT", "0x028", string.format("%s %s:%s 対象%d %s", actor_name, CATEGORY_NAMES[cat], ability_name(cat, ab_id),
            safe_num(p["Target Count"], 0), extra))
    end

    local res_table = CATEGORY_RESOURCES[cat] and res and res[CATEGORY_RESOURCES[cat]]
    if not res_table then return end

    local target_id = p["Target 1 ID"]
    if chain then
        apply_chain_result(chain, actor_name, "PACKET_SC", target_id)
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
    elseif mon_cfg.packets then
        log_event("WARN", "PACKET_SC", string.format("res に無い技ID: カテゴリ%d / %d", cat, param))
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
        state.sc_expiration = safe_num(os.clock(), 0) + sc_window_sec()
        state.sc_start_time = safe_num(os.clock(), 0)
        state.sc_starter = actor_name
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
    elseif mon_cfg.packets then
        log_event("PKT", "0x029", string.format("msg %d: %s", msg, action_message_text(msg)))
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
    state.pending_ws = nil
    flush_log()
end))
windower.register_event("logout", guarded("LOGOUT", function()
    clear_sc_state()
    state.pending_ws = nil
    state.player_id = nil
    flush_log()
end))
windower.register_event("unload", function()
    if hud then
        if hud:draggable() ~= move_allowed then hud:draggable(move_allowed) end
        hud:hide()
    end
    if grip then grip:destroy() end
    if monitor.hud then
        -- ドラッグで動かした監視オーバーレイの位置を保存する
        local x, y = monitor.hud:pos()
        if type(mon_cfg.pos) ~= "table" then mon_cfg.pos = {} end
        if x and y and (x ~= mon_cfg.pos.x or y ~= mon_cfg.pos.y) then
            mon_cfg.pos.x, mon_cfg.pos.y = x, y
            config.save(settings)
        end
        monitor.hud:destroy()
        monitor.hud = nil
    end
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

    elseif cmd == "mon" or cmd == "monitor" then
        local sub2 = args[2] and args[2]:lower()
        if sub == "packet" or sub == "pkt" then
            mon_cfg.packets = on_off_arg(sub2, mon_cfg.packets)
            chat_msg(string.format("[OmniChain] パケット詳細記録: %s", mon_cfg.packets and "ON" or "OFF"))
        elseif sub == "chat" then
            mon_cfg.chat_errors = on_off_arg(sub2, mon_cfg.chat_errors ~= false)
            chat_msg(string.format("[OmniChain] エラー/警告のチャット表示: %s", mon_cfg.chat_errors and "ON" or "OFF"))
        elseif sub == "lines" and tonumber(args[2]) then
            mon_cfg.lines = math.max(1, math.min(30, tonumber(args[2])))
            chat_msg(string.format("[OmniChain] 監視オーバーレイの行数: %d", mon_cfg.lines))
        elseif sub == "clear" then
            monitor.recent = {}
            monitor.counts = {ERROR = 0, WARN = 0, INFO = 0, PKT = 0}
            monitor.throttle = {}
            chat_msg("[OmniChain] 監視の履歴とカウンタをリセットしました。")
        else
            mon_cfg.show = on_off_arg(sub, mon_cfg.show)
            chat_msg(string.format("[OmniChain] 監視オーバーレイ: %s", mon_cfg.show and "ON" or "OFF"))
        end
        monitor.dirty = true
        config.save(settings)

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
            chat_msg(string.format("[OmniChain] 起動後の件数 ERROR:%d WARN:%d INFO:%d PKT:%d",
                monitor.counts.ERROR or 0, monitor.counts.WARN or 0, monitor.counts.INFO or 0, monitor.counts.PKT or 0))
        end

    elseif cmd == "console" then
        if sub == "on" or sub == "off" then
            mon_cfg.console = (sub == "on")
            config.save(settings)
            chat_msg(string.format("[OmniChain] console.log 監視: %s (%s)", mon_cfg.console and "ON" or "OFF", console_path))
        else
            -- console.log の末尾から最近のエラーを一覧する (起動前の分も含む)
            local n = math.max(1, math.min(20, tonumber(sub) or 5))
            local size = console_size()
            if not size then
                chat_msg("[OmniChain] console.log が開けません: " .. console_path, 167)
                return
            end
            local groups = parse_console_errors(read_console(math.max(0, size - 256 * 1024), size) or "")
            chat_msg(string.format("=== console.log のエラー 直近 %d 件 (全 %d 件) ===", math.min(n, #groups), #groups))
            for i = math.max(1, #groups - n + 1), #groups do
                local g = groups[i]
                chat_msg(string.format("%s [%s] %s", g.time, g.addon, utf8_trim(g.text, 120)), 159)
                if g.hint then chat_msg("    → 対処: " .. g.hint, 207) end
            end
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

    elseif cmd == "reload" or cmd == "load" then
        update_job_profile()
        chat_msg(string.format("[OmniChain] 設定ファイルを再ロードしました。(Job: %s / 武器: %s)", state.active_job, state.active_weapon))

    elseif cmd == "status" then
        chat_msg("=== OmniChain 設定ステータス ===")
        chat_msg(string.format("機能ステータス: %s / 最小TP: %d / HUD表示: %s", settings.enabled and "ON" or "OFF", safe_num(settings.min_tp, 1000), settings.show_hud and "ON" or "OFF"))
        chat_msg(string.format("始点: %s", settings.start_mode == "manual"
            and string.format("手動 (待ち %.1f 秒)", safe_num(settings.follow_wait, 6.0)) or "自動"))
        chat_msg(string.format("現在ジョブ: %s / 武器種: %s", state.active_job, state.active_weapon))
        chat_msg(string.format("WS優先順位: %s", table.concat(state.ws_priority, " > ")))
        chat_msg(string.format("監視: オーバーレイ %s / パケット詳細 %s / ログ記録 %s / console.log %s",
            mon_cfg.show and "ON" or "OFF", mon_cfg.packets and "ON" or "OFF", settings.debug_logging and "ON" or "OFF",
            mon_cfg.console ~= false and "ON" or "OFF"))

    else
        chat_msg("=== OmniChain コマンドヘルプ ===")
        chat_msg("//omni enable / disable       : 自動連携 ON / OFF 切替")
        chat_msg("//omni start manual / auto    : 1回目のWSを自分で撃つ / 自動で撃つ")
        chat_msg("//omni wait <秒>              : 手動始点モードで自動WSを撃つまで待つ秒数 (初期値 6)")
        chat_msg("//omni hud [on|off]           : HUDオーバーレイ画面の表示切替")
        chat_msg("//omni size <数>              : HUD の文字サイズ (6〜40)。HUD上のホイール / 右下の角のドラッグでも変更可")
        chat_msg("//omni mon [on|off]           : リアルタイム監視オーバーレイの表示切替")
        chat_msg("//omni mon packet [on|off]    : 技パケット(0x028/0x029)の詳細記録")
        chat_msg("//omni mon chat [on|off]      : エラー/警告のチャット即時表示")
        chat_msg("//omni mon lines <n> / clear  : 表示行数 / 履歴リセット")
        chat_msg("//omni log [on|off|clear]     : ログファイル記録の切替・消去")
        chat_msg("//omni log tail [n] / err [n] : 直近の記録 / エラーと警告をチャット表示")
        chat_msg("//omni console [n] / on|off   : console.log のエラー一覧 / 監視切替")
        chat_msg("//omni check                  : 優先リストのWSが使えるか点検")
        chat_msg("詳しくは addons/OmniChain/COMMANDS.txt を参照")
        chat_msg("//omni reload                 : JSON設定ファイルの再読み込み")
        chat_msg("//omni status                 : 現在の設定一覧表示")
    end
end))

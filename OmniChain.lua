-- =============================================================================
-- OmniChain.lua : 全22ジョブ ＆ 全14武器種対応 自動技連携アドオン (v7.1.0)
-- =============================================================================

_addon.name     = "OmniChain"
_addon.author   = "hikaruoshino"
_addon.version  = "7.1.0"
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
defaults.min_tp = 1000
defaults.party_sync = true
defaults.auto_mode = "flexible" -- "flexible", "strict", "lead_only"
defaults.wait_delay = 1.2
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
-- 通知: WS の失敗・優先リストの点検結果・設定ファイルの誤りをチャットに出す
--   同じ内容は10秒に1回だけ表示し、その間の回数を添える
-- -----------------------------------------------------------------------------
local NOTIFY_INTERVAL = 10
local notify_throttle = {}

local function notify(category, message, no_throttle)
    message = tostring(message)
    if not no_throttle then
        local key = category .. message
        local clock = os.clock()
        local t = notify_throttle[key]
        if t and clock - t.time < NOTIFY_INTERVAL then
            t.suppressed = t.suppressed + 1
            return
        end
        if t and t.suppressed > 0 then
            message = message .. string.format(" (直前10秒に他 %d 回)", t.suppressed)
        end
        notify_throttle[key] = {time = clock, suppressed = 0}
    end
    chat_msg(string.format("[OmniChain] %s: %s", category, message), 159)
end

-- イベント処理をエラー捕捉で包み、1回のエラーでアドオン全体が止まらないようにする
local function guarded(fn)
    return function(...)
        pcall(fn, ...)
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
                        notify("CONFIG", string.format("omnichain_config.json を読み込めません (%s): %s", path, tostring(parse_ok and parse_err or res_obj)))
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
                                        ws_priority = ws_list
                                    }
                                end
                            end
                        end
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
    last_chain_name = nil,  -- パケットとチャットで同じ連携を二重に処理しないための記録
    last_chain_time = 0,

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
        notify(category, string.format("%s はペット技のため /ws では実行できません", ws_name))
        return false
    end
    local good = true
    if not ws_in_dict(ws_name) then
        notify(category, string.format("sc_dict に無いWS: %s (連携判定は既定値で行われます)", ws_name))
        good = false
    end
    local id = ws_id_by_name(ws_name)
    if not id then
        notify(category, string.format("res に無いWS名: %s (表記ゆれの可能性)", ws_name))
        return false
    end
    local set = usable_ws_set()
    if set and not set[id] then
        notify(category, string.format("現在使えないWS: %s (武器不一致・未習得・スキル不足)", ws_name))
        good = false
    end
    return good
end

-- 優先リスト全体を点検し、問題のあるWSを1行にまとめて報告する
-- manual: //omni check から呼ばれたとき (10秒以内の再実行でも結果を省略せずに出す)
local function check_priority_list(manual)
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
    if #pet > 0 then problems = problems + 1 notify("CHECK", "ペット技は /ws で実行できません: " .. table.concat(pet, ", "), manual) end
    if #not_dict > 0 then problems = problems + 1 notify("CHECK", "sc_dict に無いWS: " .. table.concat(not_dict, ", "), manual) end
    if #not_res > 0 then problems = problems + 1 notify("CHECK", "res に無いWS名: " .. table.concat(not_res, ", "), manual) end
    if #not_usable > 0 then
        problems = problems + 1
        notify("CHECK", string.format("%s で現在使えないWS: %s", state.active_job, table.concat(not_usable, ", ")), manual)
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
        end
    end
end

-- /ws で今すぐ撃てるか: ペット技・res に無い名前・未習得/武器違いのWSは除く
local function is_executable_ws(ws_name, usable)
    if is_pet_skill(ws_name) then return false end
    local id = ws_id_by_name(ws_name)
    if not id then return not (res and res.weapon_skills) end
    return usable == nil or usable[id] == true
end

local function find_best_ws_from_priority()
    if not state.ws_priority or #state.ws_priority == 0 then return nil end

    local now = safe_num(os.clock(), 0)
    local sc_exp = safe_num(state.sc_expiration, 0)
    local is_sc_window = state.sc_active and safe_lt(now, sc_exp) and state.sc_property

    -- 撃てるWSの中で一番上のもの (連携が無いときの始点・継続に使う)
    local usable = usable_ws_set()
    local first_idx, first_ws
    for idx, ws_name in ipairs(state.ws_priority) do
        if is_executable_ws(ws_name, usable) then first_idx, first_ws = idx, ws_name break end
    end
    if not first_ws then return nil end

    if is_sc_window then
        for priority_idx, ws_name in ipairs(state.ws_priority) do
            local ws_info = is_executable_ws(ws_name, usable) and sc_dict.find_ws_info(ws_name, state.active_weapon)
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

        if settings.auto_mode == "flexible" then
            return {
                ws = first_ws,
                result_sc = "なし",
                priority = first_idx,
                reason = string.format("優先度%d [開幕/継続: %s]", first_idx, first_ws)
            }
        end
        return nil
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
        if choice then
            state.last_ws_time = now
            state.pending_ws = {name = choice.ws, time = now, tp = tp}
            check_ws_usable(choice.ws, "EXECUTE")
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
        notify("WS_TIMEOUT", string.format("%s を入力したが %.0f秒以内に発動しなかった (WS名・距離・行動不能などを確認)", p.name, PENDING_WS_TIMEOUT))
    end
end

windower.register_event("prerender", guarded(function()
    -- WS応答待ちのタイムアウト
    check_pending_ws(os.clock())

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
            table.insert(lines, string.format("次発動予定: %s", color_text(choice.ws, 100, 255, 150)))
            table.insert(lines, string.format("評価判定: %s", color_text(choice.reason, 200, 200, 255)))
        end
    else
        table.insert(lines, string.format("状態: %s", color_text("納刀中 (Idle)", 180, 180, 180)))
    end

    -- texts オブジェクトへの代入 (hud.text = ...) は ${text} 変数の設定になるため、メソッドで本文を設定する
    hud:text(table.concat(lines, string.char(10)))
    hud:show()
    update_grip()
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
    local ok, result = pcall(on_mouse, unpack(args, 1, n))
    if ok then return result end
    resize = nil
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
end

-- 連携が発生した: 次段の判定は発生した連携だけを A1 とする (wiki: 3連携以降は前WSの他属性を無視)
local function apply_chain_result(sc_name, starter, source)
    local now = safe_num(os.clock(), 0)
    -- パケットとチャットの両方で同じ連携を受け取るため、直後の重複は無視する
    if state.last_chain_name == sc_name and safe_lt(now, safe_num(state.last_chain_time, 0) + 1.5) then return end

    local prev = state.sc_active and state.sc_props and state.sc_props[1] or nil
    state.last_chain_name = sc_name
    state.last_chain_time = now

    if sc_dict.is_terminal_chain(prev, sc_name) then
        -- 光→光 / 闇→闇 の後、極光/黒闇の後はどの WS でも連携しない
        clear_sc_state()
        return
    end

    state.sc_active = true
    state.sc_props = { sc_name }
    state.sc_property = sc_name
    state.sc_expiration = now + 8.0
    if starter then state.sc_starter = starter end
end

-- 連携判定の対象にするアクションカテゴリ (3: WS / 7: WS構え / 11: TP技 / 13: ペット技)
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
        local name = ability_name(3, ws_id)
        if msg == 188 or msg == 189 then
            local src = pending and "自動" or "手動"
            notify("WS_RESULT", string.format("[%s] %s → %s", src, name, msg == 188 and "ミス" or "効果なし"))
        end
        if pending and pending.name ~= name and ws_id_by_name(pending.name) ~= ws_id then
            notify("WS_RESULT", string.format("自動入力 %s と違うWS %s が発動した", pending.name, name))
        end
        state.pending_ws = nil
    elseif cat == 7 and safe_num(p["Param"], 0) == WS_READY_INTERRUPT then
        notify("WS_FAIL", string.format("%s の構えが中断された", pending and pending.name or "WS"))
        state.pending_ws = nil
    end
end

local function handle_action_packet(data)
    local p = packets.parse("incoming", data)
    if not p then return end
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

    local res_table = CATEGORY_RESOURCES[cat] and res and res[CATEGORY_RESOURCES[cat]]
    if not res_table then return end

    if chain then
        apply_chain_result(chain, actor_name, "PACKET_SC")
        return
    end

    -- ミス・効果なしの技は連携の初段にならない (今の連携窓もそのまま)
    local hit_msg = safe_num(p["Target 1 Action 1 Message"], 0)
    if NO_HIT_MESSAGES[hit_msg] then
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
    end
    -- 連携属性が取れない技は窓を開かない (前回の属性も使い回さない)
    if #props > 0 then
        state.sc_active = true
        state.sc_props = props
        state.sc_property = table.concat(props, "/")
        state.sc_expiration = safe_num(os.clock(), 0) + 8.0
        state.sc_starter = actor_name
    end
end

-- 0x029 アクションメッセージ: 自分の行動の失敗理由 (射程外・TP不足など)
local function handle_message_packet(data)
    if not state.player_id then return end
    local p = packets.parse("incoming", data)
    if not p or (p["Actor"] ~= state.player_id and p["Target"] ~= state.player_id) then return end
    local msg = safe_num(p["Message"], 0)
    if FAIL_MESSAGES[msg] and state.pending_ws and p["Actor"] == state.player_id then
        notify("WS_FAIL", string.format("%s: %s (msg %d)", state.pending_ws.name, FAIL_MESSAGES[msg], msg))
        state.pending_ws = nil
    end
end

-- incoming chunk パケットキャッチ
windower.register_event("incoming chunk", guarded(function(id, data, modified, injected, blocked)
    id = safe_num(id, 0)
    if id == 0x028 then
        handle_action_packet(data)
    elseif id == 0x029 then
        handle_message_packet(data)
    end
end))

-- incoming text メッセージキャッチ
windower.register_event("incoming text", guarded(function(original, modified, mode, modified_mode, blocked)
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
        coroutine.schedule(guarded(function() check_priority_list(false) end), 5)
    end
end

windower.register_event("load", guarded(function()
    update_job_profile()
    schedule_priority_check()
end))
windower.register_event("login", guarded(function()
    update_job_profile()
    schedule_priority_check()
end))
windower.register_event("job change", guarded(function()
    update_job_profile()
    schedule_priority_check()
end))
-- エリア移動時は連携窓を破棄する (移動先で前エリアの属性を使わないため)
windower.register_event("zone change", guarded(function()
    clear_sc_state()
    state.pending_ws = nil
end))
windower.register_event("logout", guarded(function()
    clear_sc_state()
    state.pending_ws = nil
    state.player_id = nil
end))
windower.register_event("unload", function()
    if hud then
        if hud:draggable() ~= move_allowed then hud:draggable(move_allowed) end
        hud:hide()
    end
    if grip then grip:destroy() end
end)

local function on_off_arg(arg, current)
    if arg == "on" then return true elseif arg == "off" then return false end
    return not current
end

windower.register_event("addon command", guarded(function(cmd, ...)
    local args = {...}
    cmd = cmd and cmd:lower()
    local sub = args[1] and args[1]:lower()

    if cmd == "enable" or cmd == "on" then
        settings.enabled = true
        config.save(settings)
        chat_msg("[OmniChain] 自動連携機能: ON")

    elseif cmd == "disable" or cmd == "off" then
        settings.enabled = false
        config.save(settings)
        chat_msg("[OmniChain] 自動連携機能: OFF")

    elseif cmd == "hud" or cmd == "gui" then
        settings.show_hud = on_off_arg(sub, settings.show_hud)
        config.save(settings)
        chat_msg(string.format("[OmniChain] HUD画面表示: %s", settings.show_hud and "ON" or "OFF"))

    elseif cmd == "size" and tonumber(sub) then
        local size = set_size(tonumber(sub))
        save_hud_settings()
        chat_msg(string.format("[OmniChain] HUD の文字サイズを %d に変更しました。", size))

    elseif cmd == "check" then
        if check_priority_list(true) then
            chat_msg(string.format("[OmniChain] %s の優先リスト %d件はすべて使用可能です。", state.active_job, #state.ws_priority))
        end

    elseif cmd == "reload" or cmd == "load" then
        update_job_profile()
        chat_msg(string.format("[OmniChain] 設定ファイルを再ロードしました。(Job: %s / 武器: %s)", state.active_job, state.active_weapon))

    elseif cmd == "status" then
        chat_msg("=== OmniChain 設定ステータス ===")
        chat_msg(string.format("機能ステータス: %s / 最小TP: %d / HUD表示: %s", settings.enabled and "ON" or "OFF", safe_num(settings.min_tp, 1000), settings.show_hud and "ON" or "OFF"))
        chat_msg(string.format("現在ジョブ: %s / 武器種: %s", state.active_job, state.active_weapon))
        chat_msg(string.format("WS優先順位: %s", table.concat(state.ws_priority, " > ")))

    else
        chat_msg("=== OmniChain コマンドヘルプ ===")
        chat_msg("//omni enable / disable       : 自動連携 ON / OFF 切替")
        chat_msg("//omni hud [on|off]           : HUDオーバーレイ画面の表示切替")
        chat_msg("//omni size <数>              : HUD の文字サイズ (6〜40)。HUD上のホイール / 右下の角のドラッグでも変更可")
        chat_msg("//omni check                  : 優先リストのWSが使えるか点検")
        chat_msg("//omni reload                 : JSON設定ファイルの再読み込み")
        chat_msg("//omni status                 : 現在の設定一覧表示")
        chat_msg("詳しくは addons/OmniChain/COMMANDS.txt を参照")
    end
end))

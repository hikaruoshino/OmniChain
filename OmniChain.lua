-- =============================================================================
-- OmniChain.lua : 全22ジョブ ＆ 全14武器種対応 自動技連携アドオン (v7.0.3)
-- =============================================================================

_addon.name     = "OmniChain"
_addon.author   = "Gemini Notebook"
_addon.version  = "7.0.3"
_addon.commands = {"omni", "omnichain"}

require("luau")
local config  = require("config")
local texts   = require("texts")
local res     = require("resources")
local packets = require("packets")
local sc_dict = require("sc_dict")

-- 安全な数値変換ヘルパー関数 (比較エラー完全防御)
local function get_safe_number(val, default_val)
    if type(val) == "number" then return val end
    if type(val) == "string" then
        local n = tonumber(val)
        if n then return n end
    end
    return default_val or 0
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

defaults.profiles = {
    ['WAR'] = { weapon = '両手斧', ws_priority = {'ディザスター', 'アップヒーバル', 'ウッコフューリー', 'キングズジャスティス', 'フェルクリーヴ'} },
    ['PLD'] = { weapon = '片手剣', ws_priority = {'インペラトル', 'サベッジブレード', 'シャンデュシニュ', 'ボーパルブレード', 'ロイエ'} },
    ['SAM'] = { weapon = '両手刀', ws_priority = {'絶之太刀・無名', '祖之太刀・不動', '十二之太刀・照破', '九之太刀・花車'} },
    ['THF'] = { weapon = '短剣', ws_priority = {'ルースレスストローク', 'ルドラストーム', 'エヴィサレーション', 'イオリアンエッジ'} },
    ['DRK'] = { weapon = '両手鎌', ws_priority = {'ジ・オリジン', 'クロスリーパー', 'エントロピー', 'カタストロフィ'} },
    ['RNG'] = { weapon = '弓術', ws_priority = {'シャルヴ', 'ジシュヌの光輝', 'エイペクスアロー', '南無八幡'} },
    ['NIN'] = { weapon = '片手刀', ws_priority = {'是生滅法', '瞬', '秘', '迅'} },
    ['DRG'] = { weapon = '両手槍', ws_priority = {'ダーマット', 'インパルスドライヴ', 'カムラン', 'スターダイバー'} },
    ['MNK'] = { weapon = '格闘', ws_priority = {'マルカラ', 'ビクトリースマイト', '四神円舞', '夢想阿修羅拳'} },
    ['RDM'] = { weapon = '片手剣', ws_priority = {'インペラトル', 'サベッジブレード', 'シャンデュシニュ', 'ロズレーファタール', 'サンギンブレード'} },
    ['BLU'] = { weapon = '片手剣', ws_priority = {'インペラトル', 'サベッジブレード', 'シャンデュシニュ', 'レクイエスカット'} },
    ['COR'] = { weapon = '射撃', ws_priority = {'ジ・エンド', 'レデンサリュート', 'ラストスタンド', 'ワイルドファイア'} },
    ['DNC'] = { weapon = '短剣', ws_priority = {'ルースレスストローク', 'ピリッククレオス', 'ルドラストーム', 'エヴィサレーション'} },
    ['RUN'] = { weapon = '両手剣', ws_priority = {'フィンブルヴェト', 'デミディエーション', 'トアクリーバー', 'レゾルーション'} },
    ['BST'] = { weapon = '片手斧', ws_priority = {'ブリッツ', 'ルイネーター', 'デシメーション', 'クラウドスプリッタ'} },
    ['BRD'] = { weapon = '短剣', ws_priority = {'ルースレスストローク', 'ルドラストーム', 'モーダントライム', 'イオリアンエッジ'} },
    ['PUP'] = { weapon = '格闘', ws_priority = {'マルカラ', 'ビクトリースマイト', 'ストリングシュレッダー', 'ボーンクラッシャー', 'アーマーシャッタラー'} },
    ['SCH'] = { weapon = '両手棍', ws_priority = {'オシャラ', 'ガーランドオブブリス', 'ミルキル', 'カタクリスム'} },
    ['GEO'] = { weapon = '片手棍', ws_priority = {'ダグダ', 'ブラックヘイロー', 'レルムレイザー', 'フラッシュノヴァ'} },
    ['WHM'] = { weapon = '片手棍', ws_priority = {'ダグダ', 'ヘキサストライク', 'ブラックヘイロー', 'レルムレイザー'} },
    ['BLM'] = { weapon = '両手棍', ws_priority = {'オシャラ', 'ヴィゾフニル', 'ミルキル', 'カタクリスム'} },
    ['SMN'] = { weapon = '両手棍', ws_priority = {'ボルトストライク', 'フレイムクラッシュ', 'プレデタークロー', 'ガーランドオブブリス'} }
}

local settings = config.load(defaults)

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

-- カラーコード装飾 (HUD用 DirectWrite UTF-8)
local function color_text(str, r, g, b)
    return string.format("\cs(%d,%d,%d)%s\cr", get_safe_number(r, 255), get_safe_number(g, 255), get_safe_number(b, 255), tostring(str or ""))
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
                if jok and json and json.decode then
                    local parse_ok, res_obj = pcall(json.decode, content)
                    if parse_ok and type(res_obj) == "table" then
                        if res_obj.min_tp ~= nil then
                            settings.min_tp = get_safe_number(res_obj.min_tp, 1000)
                        end
                        if res_obj.profiles and type(res_obj.profiles) == "table" then
                            for job, data in pairs(res_obj.profiles) do
                                if type(data) == "table" and data.weapon and data.ws_priority then
                                    settings.profiles[job] = {
                                        weapon = tostring(data.weapon),
                                        ws_priority = data.ws_priority
                                    }
                                end
                            end
                        end
                        return true
                    end
                end
                return true
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
    sc_property = nil,
    sc_expiration = 0,
    sc_starter = "",
    
    last_ws_time = 0,
}

local hud = texts.new("", settings)

local function update_job_profile()
    load_external_json_config()
    
    local player = windower.ffxi.get_player()
    if player and player.main_job then
        state.active_job = tostring(player.main_job)
        if settings.profiles[state.active_job] then
            state.active_weapon = tostring(settings.profiles[state.active_job].weapon or "片手剣")
            state.ws_priority = settings.profiles[state.active_job].ws_priority or {}
        end
    end
end

local function find_best_ws_from_priority()
    if not state.ws_priority or #state.ws_priority == 0 then return nil end
    
    local now = get_safe_number(os.clock(), 0)
    local sc_exp = get_safe_number(state.sc_expiration, 0)
    local is_sc_window = state.sc_active and (now < sc_exp) and state.sc_property
    
    if is_sc_window then
        for priority_idx, ws_name in ipairs(state.ws_priority) do
            local ws_info = sc_dict.find_ws_info(ws_name, state.active_weapon)
            if ws_info then
                local eval = sc_dict.evaluate_ws_for_sc(ws_info, state.sc_property)
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
        
        if settings.auto_mode == "flexible" and state.ws_priority[1] then
            return {
                ws = state.ws_priority[1],
                result_sc = "なし",
                priority = 1,
                reason = string.format("優先度1 [開幕/継続: %s]", state.ws_priority[1])
            }
        end
        return nil
    else
        if state.ws_priority[1] then
            return {
                ws = state.ws_priority[1],
                result_sc = "始点",
                priority = 1,
                reason = string.format("優先度1 [連携始点: %s]", state.ws_priority[1])
            }
        end
        return nil
    end
end

windower.register_event("prerender", function()
    if not settings.show_hud then
        hud:hide()
        return
    end

    local now = get_safe_number(os.clock(), 0)
    local sc_exp = get_safe_number(state.sc_expiration, 0)
    local min_tp = get_safe_number(settings.min_tp, 1000)
    local wait_delay = get_safe_number(settings.wait_delay, 1.2)
    local last_ws = get_safe_number(state.last_ws_time, 0)

    local lines = {}
    
    local status_str = settings.enabled and color_text("[ON]", 100, 255, 100) or color_text("[OFF]", 255, 100, 100)
    table.insert(lines, string.format("=== [ OmniChain v7.0 ] %s ===", status_str))
    table.insert(lines, string.format("Job / 武器: %s / %s", color_text(state.active_job, 255, 220, 100), color_text(state.active_weapon, 0, 210, 255)))
    
    local prio_str_list = {}
    for idx, name in ipairs(state.ws_priority) do
        if idx <= 3 then
            table.insert(prio_str_list, string.format("P%d:%s", idx, name))
        end
    end
    table.insert(lines, string.format("WS優先度: %s", color_text(table.concat(prio_str_list, " > "), 200, 255, 200)))
    
    if state.sc_active and (now < sc_exp) then
        local rem_time = math.max(0.0, sc_exp - now)
        table.insert(lines, string.format("アクティブ連携: %s (残り %.1fs / %s)", color_text(state.sc_property, 255, 200, 50), rem_time, state.sc_starter))
    else
        state.sc_active = false
        table.insert(lines, string.format("連携窓: %s", color_text("待機中 (Idle)", 180, 180, 180)))
    end
    
    local player = windower.ffxi.get_player()
    if player and player.status == 1 then
        local tp = get_safe_number(player.vitals and player.vitals.tp, 0)
        table.insert(lines, string.format("TP: %s / 最小%d", color_text(tostring(tp), tp >= min_tp and 50 or 255, 255, 100), min_tp))
        
        local choice = find_best_ws_from_priority()
        if choice then
            table.insert(lines, string.format("次発動予定: %s", color_text(choice.ws, 100, 255, 150)))
            table.insert(lines, string.format("評価判定: %s", color_text(choice.reason, 200, 200, 255)))
            
            if settings.enabled and tp >= min_tp and (now - last_ws > wait_delay) then
                state.last_ws_time = now
                chat_msg(string.format("[OmniChain] WS自動実行: %s (%s)", choice.ws, choice.reason), 158)
                windower.send_command(string.format('input /ws "%s" <t>', choice.ws))
            end
        end
    else
        table.insert(lines, string.format("状態: %s", color_text("納刀中 (Idle)", 180, 180, 180)))
    end

    hud.text = table.concat(lines, string.char(10))
    hud:show()
end)

windower.register_event("incoming chunk", function(id, data, modified, injected, blocked)
    if id == 0x028 then
        local p = packets.parse("incoming", data)
        if p and (p["Category"] == 3 or p["Category"] == 11 or p["Category"] == 13) then
            local actor_mob = windower.ffxi.get_mob_by_id(p["Actor"])
            if actor_mob then
                state.sc_active = true
                state.sc_expiration = get_safe_number(os.clock(), 0) + 8.0
                state.sc_starter = tostring(actor_mob.name or "")
                
                local param = p["Param"]
                if res and res.weapon_skills and res.weapon_skills[param] then
                    local ws_res = res.weapon_skills[param]
                    if ws_res.skillchain_a and ws_res.skillchain_a ~= "" then
                        state.sc_property = sc_dict.EN_TO_JA_SC[ws_res.skillchain_a] or ws_res.skillchain_a
                    end
                end
            end
        end
    end
end)

windower.register_event("incoming text", function(original, modified, mode, modified_mode, blocked)
    if original and original:find("技連携・") then
        local sc_name = original:match("技連携・([%a%a%a%a%a%a]+)")
        if sc_name then
            state.sc_active = true
            state.sc_property = sc_name
            state.sc_expiration = get_safe_number(os.clock(), 0) + 7.5
        end
    end
end)

windower.register_event("load", function() update_job_profile() end)
windower.register_event("job change", function() update_job_profile() end)
windower.register_event("unload", function() if hud then hud:hide() end end)

windower.register_event("addon command", function(cmd, ...)
    local args = {...}
    cmd = cmd and cmd:lower()

    if cmd == "enable" or cmd == "on" then
        settings.enabled = true
        config.save(settings)
        chat_msg("[OmniChain] 自動連携機能: ON")

    elseif cmd == "disable" or cmd == "off" then
        settings.enabled = false
        config.save(settings)
        chat_msg("[OmniChain] 自動連携機能: OFF")

    elseif cmd == "hud" or cmd == "gui" then
        if args[1] == "on" then
            settings.show_hud = true
        elseif args[1] == "off" then
            settings.show_hud = false
        else
            settings.show_hud = not settings.show_hud
        end
        config.save(settings)
        chat_msg(string.format("[OmniChain] HUD画面表示: %s", settings.show_hud and "ON" or "OFF"))

    elseif cmd == "reload" or cmd == "load" then
        update_job_profile()
        chat_msg(string.format("[OmniChain] 設定ファイルを再ロードしました。(Job: %s / 武器: %s)", state.active_job, state.active_weapon))

    elseif cmd == "job" and args[1] then
        local job_code = args[1]:upper()
        if sc_dict.JOB_WEAPONS and sc_dict.JOB_WEAPONS[job_code] or settings.profiles[job_code] then
            state.active_job = job_code
            if settings.profiles[job_code] then
                state.active_weapon = settings.profiles[job_code].weapon or "片手剣"
                state.ws_priority = settings.profiles[job_code].ws_priority or {}
            end
            chat_msg(string.format("[OmniChain] アクティブジョブ変更: %s (武器: %s)", job_code, state.active_weapon))
        end

    elseif cmd == "weapon" and args[1] then
        local weapon_name = args[1]
        state.active_weapon = weapon_name
        if not settings.profiles[state.active_job] then
            settings.profiles[state.active_job] = {}
        end
        settings.profiles[state.active_job].weapon = weapon_name
        config.save(settings)
        chat_msg(string.format("[OmniChain] 選択武器種を変更: %s", weapon_name))

    elseif cmd == "priority" and #args > 0 then
        local new_list = {}
        for _, arg in ipairs(args) do
            table.insert(new_list, arg)
        end
        state.ws_priority = new_list
        if not settings.profiles[state.active_job] then
            settings.profiles[state.active_job] = {}
        end
        settings.profiles[state.active_job].ws_priority = new_list
        config.save(settings)
        chat_msg(string.format("[OmniChain] %s のWS優先順位を更新しました: %s", state.active_job, table.concat(new_list, " > ")))

    elseif cmd == "tp" and args[1] then
        local tp_val = tonumber(args[1])
        if tp_val and tp_val >= 1000 and tp_val <= 3000 then
            settings.min_tp = tp_val
            config.save(settings)
            chat_msg(string.format("[OmniChain] 最小発動TPを %d に設定しました。", tp_val))
        end

    elseif cmd == "status" then
        chat_msg("=== OmniChain 設定ステータス ===")
        chat_msg(string.format("機能ステータス: %s / 最小TP: %d / HUD表示: %s", settings.enabled and "ON" or "OFF", settings.min_tp, settings.show_hud and "ON" or "OFF"))
        chat_msg(string.format("現在ジョブ: %s / 武器種: %s", state.active_job, state.active_weapon))
        chat_msg(string.format("WS優先順位: %s", table.concat(state.ws_priority, " > ")))

    else
        chat_msg("=== OmniChain コマンドヘルプ ===")
        chat_msg("//omni enable / disable   : 自動連携 ON / OFF 切替")
        chat_msg("//omni hud [on|off]       : HUDオーバーレイ画面の表示切替")
        chat_msg("//omni reload             : JSON設定ファイルの再読み込み")
        chat_msg("//omni job <WAR|PLD...>   : 対象ジョブの切替")
        chat_msg("//omni weapon <両手斧...> : 武器種の切替")
        chat_msg("//omni priority <WS1>...  : WS優先順位の再設定")
        chat_msg("//omni tp <1000~3000>     : 最小発動TP設定")
        chat_msg("//omni status             : 現在の設定一覧表示")
    end
end)

--[[
    SubSource Subtitle Plugin for mpv

    Search and download subtitles from subsource.net directly inside mpv.
    Supports uosc menu integration and built-in interactive OSD menu fallback.

    Original concept and idea by Mark Pashmfouroush (@markpash).
]]


local mp = require("mp")
local utils = require("mp.utils")
local options = require("mp.options")
local msg = require("mp.msg")

local SCRIPT_NAME = "subsource"
local PLUGIN_VERSION = "0.1.0"
local BASE_URL = "https://api.subsource.net/api/v1"

-- Default configuration
local opts = {
    api_key = "",
    languages = "english",
    sort = "popular",           -- popular, newest, rating, oldest
    hearing_impaired = "include", -- include, exclude, only
    auto_load = false,          -- automatically download and select top subtitle match
    auto_search = false,        -- search SubSource automatically on file load
    episode_filter = true,      -- filter subtitles to match current episode
    save_to_disk = false,       -- save subtitle file in video directory
    sub_dir = "",               -- custom directory to save subtitles
    uosc = "auto",              -- "auto", "yes", "no"
    max_results = 50,
    timeout = 20,
    debug = false,
    base_url = BASE_URL,
}

options.read_options(opts, SCRIPT_NAME)

local function get_api_key()
    if opts.api_key and #opts.api_key > 0 then
        return opts.api_key
    end
    local env_key = os.getenv("SUBSOURCE_API_KEY")
    if env_key and #env_key > 0 then
        return env_key
    end
    return ""
end

local function dlog(...)
    if opts.debug then
        msg.info(...)
    end
end

-- ---------------------------------------------------------------------------
-- Languages dictionary & ISO 639-1 code alias map
-- ---------------------------------------------------------------------------

local LANGUAGES = {
    english = "English",
    farsi_persian = "Farsi/Persian",
    arabic = "Arabic",
    bengali = "Bengali",
    indonesian = "Indonesian",
    abkhazian = "Abkhazian",
    afrikaans = "Afrikaans",
    albanian = "Albanian",
    amharic = "Amharic",
    aragonese = "Aragonese",
    armenian = "Armenian",
    assamese = "Assamese",
    asturian = "Asturian",
    azerbaijani = "Azerbaijani",
    basque = "Basque",
    belarusian = "Belarusian",
    big_5_code = "Big 5 code",
    bosnian = "Bosnian",
    brazilian_portuguese = "Brazilian Portuguese",
    breton = "Breton",
    bulgarian = "Bulgarian",
    burmese = "Burmese",
    catalan = "Catalan",
    chinese = "Chinese",
    chinese_cantonese = "Chinese (Cantonese)",
    chinese_simplified = "Chinese (Simplified)",
    chinese_traditional = "Chinese (Traditional)",
    chinese_bg_code = "Chinese BG code",
    chinese_bilingual = "Chinese Bilingual",
    croatian = "Croatian",
    czech = "Czech",
    danish = "Danish",
    dari = "Dari",
    dutch = "Dutch",
    espranto = "Esperanto",
    estonian = "Estonian",
    extremaduran = "Extremaduran",
    filipino = "Filipino",
    finnish = "Finnish",
    french = "French",
    french_canada = "French (Canada)",
    french_france = "French (France)",
    gaelic = "Gaelic",
    gaelician = "Galician",
    georgian = "Georgian",
    german = "German",
    greek = "Greek",
    greenlandic = "Greenlandic",
    hebrew = "Hebrew",
    hindi = "Hindi",
    hungarian = "Hungarian",
    icelandic = "Icelandic",
    igbo = "Igbo",
    interlingua = "Interlingua",
    irish = "Irish",
    italian = "Italian",
    japanese = "Japanese",
    kannada = "Kannada",
    kazakh = "Kazakh",
    khmer = "Khmer",
    korean = "Korean",
    kurdish = "Kurdish",
    kyrgyz = "Kyrgyz",
    latvian = "Latvian",
    lithuanian = "Lithuanian",
    luxembourgish = "Luxembourgish",
    macedonian = "Macedonian",
    malay = "Malay",
    malayalam = "Malayalam",
    manipuri = "Manipuri",
    marathi = "Marathi",
    mongolian = "Mongolian",
    montenegrin = "Montenegrin",
    navajo = "Navajo",
    nepali = "Nepali",
    northen_sami = "Northern Sami",
    norwegian = "Norwegian",
    occitan = "Occitan",
    odia = "Odia",
    pashto = "Pashto",
    polish = "Polish",
    portuguese = "Portuguese",
    pushto = "Pushto",
    romanian = "Romanian",
    russian = "Russian",
    santli = "Santali",
    serbian = "Serbian",
    sindhi = "Sindhi",
    sinhala = "Sinhala",
    sinhalese = "Sinhalese",
    slovak = "Slovak",
    slovenian = "Slovenian",
    somali = "Somali",
    sorbian = "Sorbian",
    spanish = "Spanish",
    spanish_latin_america = "Spanish (Latin America)",
    spanish_spain = "Spanish (Spain)",
    swahili = "Swahili",
    swedish = "Swedish",
    sylheti = "Sylheti",
    syriac = "Syriac",
    tagalog = "Tagalog",
    tamil = "Tamil",
    tatar = "Tatar",
    telugu = "Telugu",
    tetum = "Tetum",
    thai = "Thai",
    toki_pona = "Toki Pona",
    turkish = "Turkish",
    turkmen = "Turkmen",
    ukrainian = "Ukrainian",
    urdu = "Urdu",
    uzbek = "Uzbek",
    vietnamese = "Vietnamese",
    welsh = "Welsh",
}

local ISO_TO_SLUG = {
    en = "english",
    fa = "farsi_persian",
    per = "farsi_persian",
    ar = "arabic",
    bn = "bengali",
    id = "indonesian",
    es = "spanish",
    fr = "french",
    de = "german",
    it = "italian",
    pt = "portuguese",
    ru = "russian",
    ja = "japanese",
    jp = "japanese",
    ko = "korean",
    kr = "korean",
    zh = "chinese",
    cn = "chinese",
    nl = "dutch",
    pl = "polish",
    tr = "turkish",
    sv = "swedish",
    se = "swedish",
    vi = "vietnamese",
    hi = "hindi",
    uk = "ukrainian",
    ua = "ukrainian",
    el = "greek",
    gr = "greek",
    he = "hebrew",
    th = "thai",
    cs = "czech",
    cz = "czech",
    da = "danish",
    dk = "danish",
    fi = "finnish",
    no = "norwegian",
    ro = "romanian",
    hu = "hungarian",
    bg = "bulgarian",
    hr = "croatian",
    sk = "slovak",
    sl = "slovenian",
    sr = "serbian",
}

local function normalize_language(lang)
    if not lang then return nil end
    local lower = lang:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
    if lower == "all" then return "all" end
    if ISO_TO_SLUG[lower] then return ISO_TO_SLUG[lower] end
    if LANGUAGES[lower] then return lower end
    return lower
end

local function language_display_name(slug)
    if not slug then return "" end
    local s = slug:lower()
    if s == "all" then return "All languages" end
    return LANGUAGES[s] or slug
end

local function get_configured_languages()
    local raw = opts.languages or "english"
    local list = {}
    for part in raw:gmatch("[^,]+") do
        local trimmed = part:match("^%s*(.-)%s*$")
        local norm = normalize_language(trimmed)
        if norm and #norm > 0 then
            table.insert(list, norm)
        end
    end
    if #list == 0 then
        table.insert(list, "english")
    end
    return list
end

-- ---------------------------------------------------------------------------
-- Filename parser & Episode matcher
-- ---------------------------------------------------------------------------

local VIDEO_EXTS = {
    mkv=true, mp4=true, m4v=true, avi=true, mov=true, wmv=true, flv=true,
    webm=true, ts=true, m2ts=true, mpg=true, mpeg=true, ogm=true, ogv=true,
    ["3gp"]=true, vob=true, divx=true, rmvb=true, iso=true
}

local SUB_EXTS = {
    srt=true, ass=true, ssa=true, vtt=true, sub=true, idx=true, smi=true,
    sup=true, ttml=true, dfxp=true, sbv=true, psb=true, usf=true
}

local STOP_TOKENS = {
    "480p", "576p", "720p", "1080p", "1080i", "2160p", "4k", "uhd", "8k",
    "bluray", "blu%-ray", "bdrip", "brrip", "bdremux", "remux", "webrip",
    "web%-dl", "webdl", "web", "hdtv", "pdtv", "dvdrip", "dvdscr", "dvd",
    "hdrip", "hdcam", "cam", "ts", "tc", "r5", "amzn", "nf", "atvp",
    "dsnp", "hmax", "max", "hulu", "pcok", "itunes", "x264", "x265",
    "h264", "h265", "h%.264", "h%.265", "hevc", "avc", "av1", "xvid",
    "divx", "aac", "ac3", "eac3", "dd5", "ddp", "ddp5", "dts",
    "dts%-hd", "truehd", "atmos", "flac", "hdr", "hdr10", "dv", "dovi",
    "sdr", "10bit", "8bit", "proper", "repack", "internal", "limited",
    "extended", "unrated", "directors", "remastered", "imax", "multi",
    "dual", "dubbed", "subbed"
}

local function clean_spaces(s)
    if not s then return "" end
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    s = s:gsub("[%s%._%-]+$", "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function normalize_title(s)
    if not s then return "" end
    s = s:lower()
    s = s:gsub("&", " and ")
    s = s:gsub("[''`]", "")
    s = s:gsub("[^%w%s]", " ")
    for _, art in ipairs({"the", "a", "an"}) do
        s = s:gsub("%f[%w]" .. art .. "%f[^%w]", " ")
    end
    return clean_spaces(s)
end

local function similarity(a, b)
    local na = normalize_title(a)
    local nb = normalize_title(b)
    if #na == 0 or #nb == 0 then return 0 end
    if na == nb then return 1 end

    local function get_bigrams(s)
        local map = {}
        for i = 1, #s - 1 do
            local bg = s:sub(i, i + 1)
            map[bg] = (map[bg] or 0) + 1
        end
        return map
    end

    local ba = get_bigrams(na)
    local bb = get_bigrams(nb)
    local overlap = 0
    for k, v in pairs(ba) do
        if bb[k] then
            overlap = overlap + math.min(v, bb[k])
        end
    end
    return (2 * overlap) / ((#na - 1) + (#nb - 1))
end

local function parse_filename(input)
    local result = {
        title = "",
        year = nil,
        season = nil,
        episode = nil,
        isSeries = false,
        raw = input or ""
    }
    if not input or type(input) ~= "string" then return result end

    local name = input:match("^%s*(.-)%s*$")
    local base, ext = name:match("^(.-)%.([%w%d]+)$")
    if ext and VIDEO_EXTS[ext:lower()] then
        name = base
    end

    name = name:gsub("%b[]", " "):gsub("%b{}", " ")
    local work = name:gsub("[%._]", " ")
    work = clean_spaces(work)

    local ep_index = nil
    local s_match, e_match = work:match("%f[%w][sS](%d%d?)[%s%.%-_]?[eE](%d%d?%d?)%f[^%w]")
    if s_match and e_match then
        result.season = tonumber(s_match)
        result.episode = tonumber(e_match)
        result.isSeries = true
        ep_index = work:find("%f[%w][sS]%d%d?[%s%.%-_]?[eE]%d%d?%d?%f[^%w]")
    end

    if not ep_index then
        local s2, e2 = work:match("%f[%w](%d%d?)x(%d%d%d?)%f[^%w]")
        if s2 and e2 then
            result.season = tonumber(s2)
            result.episode = tonumber(e2)
            result.isSeries = true
            ep_index = work:find("%f[%w]%d%d?x%d%d%d?%f[^%w]")
        end
    end

    if not ep_index then
        local s3, e3 = work:match("%f[%w][sS]eason[%s%.%-_]*(%d%d?)[%s%.%-_]*[eE]pisode[%s%.%-_]*(%d%d?%d?)%f[^%w]")
        if s3 and e3 then
            result.season = tonumber(s3)
            result.episode = tonumber(e3)
            result.isSeries = true
            ep_index = work:find("%f[%w][sS]eason[%s%.%-_]*%d%d?[%s%.%-_]*[eE]pisode[%s%.%-_]*%d%d?%d?%f[^%w]")
        end
    end

    local year_index = nil
    local current_year = os.date("*t").year + 1
    local cur_pos = 1
    while true do
        local s_idx, e_idx, y_str = work:find("(%d%d%d%d)", cur_pos)
        if not s_idx then break end
        local y_num = tonumber(y_str)
        if y_num and y_num >= 1900 and y_num <= current_year and s_idx > 1 then
            local prev_char = s_idx > 1 and work:sub(s_idx - 1, s_idx - 1) or ' '
            local next_char = e_idx < #work and work:sub(e_idx + 1, e_idx + 1) or ' '
            if not prev_char:match("%w") and not next_char:match("%w") then
                result.year = y_num
                year_index = s_idx
                break
            end
        end
        cur_pos = s_idx + 1
    end

    local stop_index = nil
    local work_lower = " " .. work:lower() .. " "
    for _, token in ipairs(STOP_TOKENS) do
        local pat = "%f[%w]" .. token .. "%f[^%w]"
        local s_idx = work_lower:find(pat)
        if s_idx and s_idx > 1 then
            local real_idx = s_idx - 1
            if not stop_index or real_idx < stop_index then
                stop_index = real_idx
            end
        end
    end

    local cut = #work + 1
    if ep_index and ep_index < cut then cut = ep_index end
    if year_index and year_index < cut then cut = year_index end
    if stop_index and stop_index < cut then cut = stop_index end

    local title = work:sub(1, cut - 1)
    title = title:gsub("%b()", function(b)
        local inside = b:sub(2, -2):gsub("%s+", "")
        if inside == "" or tonumber(inside) then return " " end
        return b
    end)
    title = title:gsub("[()]", " ")

    if not result.isSeries then
        local s_only = title:match("%f[%w][sS](%d%d?)%f[^%w]") or title:match("%f[%w][sS]eason[%s%.%-_]*(%d%d?)%f[^%w]")
        if s_only then
            result.season = tonumber(s_only)
            result.isSeries = true
            local p = title:find("%f[%w][sS]%d%d?%f[^%w]") or title:find("%f[%w][sS]eason[%s%.%-_]*%d%d?%f[^%w]")
            if p and p > 1 then
                title = title:sub(1, p - 1)
            end
        end
    end

    title = clean_spaces(title:gsub("%s+[%-–—]%s*$", ""))
    if result.isSeries and title:find(" %- ") then
        title = title:match("^(.-) %- ") or title
    end

    result.title = clean_spaces(title)
    if #result.title == 0 then
        result.title = clean_spaces(work)
    end

    return result
end

local function classify_episode(release_info, season, episode)
    if not episode then return "unknown" end
    local names = type(release_info) == "table" and release_info or {tostring(release_info or "")}
    local saw_season_only = false
    local saw_other = false

    for _, raw in ipairs(names) do
        local name = tostring(raw or "")
        local s_str, f_str, t_str = name:match("[sS](%d%d?)[%s%.%-_]?[eE](%d%d?%d?)%s*[%-–]%s*[eE]?(%d%d?%d?)%f[^%w]")
        if s_str and f_str and t_str then
            local s = tonumber(s_str)
            local from_ep = tonumber(f_str)
            local to_ep = tonumber(t_str)
            if (not season or s == season) and episode >= from_ep and episode <= to_ep then
                return "match"
            end
            saw_other = true
        else
            -- S01E01E02 or S01E01-E02
            local s1, e1, e2 = name:match("[sS](%d%d?)[%s%.%-_]?[eE](%d%d?%d?)[%s%.%-_]?[eE](%d%d?%d?)%f[^%w]")
            if not s1 then
                s1, e1, e2 = name:match("[sS](%d%d?)[%s%.%-_]?[eE](%d%d?%d?)%s*[%-–]%s*[eE]?(%d%d?%d?)%f[^%w]")
            end
            if not s1 then
                s1, e1 = name:match("[sS](%d%d?)[%s%.%-_]?[eE](%d%d?%d?)%f[^%w]")
                e2 = nil
            end

            if s1 and e1 then
                local s = tonumber(s1)
                local ep1 = tonumber(e1)
                local ep2 = tonumber(e2)
                local season_ok = (not season or s == season)
                if season_ok and (ep1 == episode or ep2 == episode) then
                    return "match"
                end
                saw_other = true
            else
                local s_x, e_x = name:match("%f[%w](%d%d?)x(%d%d%d?)%f[^%w]")
                if s_x and e_x then
                    local s = tonumber(s_x)
                    local ep = tonumber(e_x)
                    local season_ok = (not season or s == season)
                    if season_ok and ep == episode then
                        return "match"
                    end
                    saw_other = true
                else
                    local s_only = name:match("%f[%w][sS](%d%d?)%f[^%w]") or name:match("[sS]eason[%s%.%-_]*(%d%d?)") or name:match("%f[%w][Cc]omplete%f[^%w]")
                    if s_only then
                        local s = tonumber(s_only) or season
                        if not season or s == season then
                            saw_season_only = true
                        else
                            saw_other = true
                        end
                    end
                end
            end
        end
    end

    if saw_season_only then return "pack" end
    if saw_other then return "other" end
    return "unknown"
end

local function pick_files_for_episode(files, season, episode)
    if not files or #files == 0 then return {} end
    if #files == 1 then return {files[1]} end
    if not episode then return {} end
    local matches = {}
    for _, f in ipairs(files) do
        if classify_episode({f.filename}, season, episode) == "match" then
            table.insert(matches, f)
        end
    end
    return matches
end

-- ---------------------------------------------------------------------------
-- HTTP & SubSource API
-- ---------------------------------------------------------------------------

local function url_encode(str)
    if not str then return "" end
    return (tostring(str):gsub("[^%w%-_%.~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function build_query(params)
    local parts = {}
    for k, v in pairs(params) do
        if v ~= nil and v ~= "" then
            table.insert(parts, url_encode(k) .. "=" .. url_encode(v))
        end
    end
    if #parts == 0 then return "" end
    return "?" .. table.concat(parts, "&")
end

local function http_get(path, query_params, cb)
    local key = get_api_key()
    if not key or #key == 0 then
        cb(nil, 401, "No SubSource API key set. Configure in script-opts/subsource.conf or SUBSOURCE_API_KEY")
        return
    end

    local url = opts.base_url .. path .. build_query(query_params)
    dlog("HTTP GET " .. url)

    local args = {
        "curl",
        "-sSL",
        "--ipv4",
        "-w", "\n%{http_code}",
        "--connect-timeout", tostring(opts.timeout or 15),
        "--max-time", tostring(opts.timeout or 20),
        "-H", "X-API-Key: " .. key,
        "-H", "Accept: application/json",
        "-H", "User-Agent: mpv-subsource/" .. PLUGIN_VERSION,
        url
    }

    mp.command_native_async({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = args
    }, function(success, res, err)
        if not success or not res then
            cb(nil, 0, err or "Process execution failed")
            return
        end
        if res.status ~= 0 then
            cb(nil, 0, "curl error (" .. tostring(res.status) .. "): " .. tostring(res.stderr))
            return
        end

        local stdout = res.stdout or ""
        local body, status_str = stdout:match("^(.-)\n(%d%d%d)%s*$")
        local status = tonumber(status_str) or 0
        if not body then
            body = stdout
        end

        local data = utils.parse_json(body)

        if status >= 200 and status < 300 then
            if data and data.success == false then
                cb(nil, status, data.message or data.error or "Request failed", data)
            else
                cb(data, status, nil)
            end
        elseif status == 401 or status == 403 then
            cb(nil, status, "Invalid or inactive SubSource API key", data)
        elseif status == 429 then
            cb(nil, status, "Rate limit exceeded (60 req/min). Please wait a moment.", data)
        elseif status == 404 then
            cb(nil, status, "Not found", data)
        else
            local s_msg = (data and (data.message or data.error)) or ("HTTP " .. tostring(status))
            cb(nil, status, s_msg, data)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- File & Directory Utilities
-- ---------------------------------------------------------------------------

local function get_temp_dir()
    local tmp = os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
    local subsource_tmp = utils.join_path(tmp, "mpv-subsource")
    mp.command_native({name = "subprocess", playback_only = false, args = {"mkdir", "-p", subsource_tmp}})
    return subsource_tmp
end

local function file_is_zip(path)
    local f = io.open(path, "rb")
    if not f then return false end
    local head = f:read(4)
    f:close()
    return head and head:sub(1, 2) == "PK"
end

local function find_subtitle_files(dir)
    local entries = utils.readdir(dir, "files") or {}
    local out = {}
    for _, name in ipairs(entries) do
        local ext = name:match("%.([%w%d]+)$")
        if ext and SUB_EXTS[ext:lower()] then
            table.insert(out, {
                filename = name,
                path = utils.join_path(dir, name)
            })
        end
    end
    table.sort(out, function(a, b) return a.filename < b.filename end)
    return out
end

local function copy_file(src, dst)
    local inf = io.open(src, "rb")
    if not inf then return false end
    local outf = io.open(dst, "wb")
    if not outf then
        inf:close()
        return false
    end
    local chunk_size = 64 * 1024
    while true do
        local chunk = inf:read(chunk_size)
        if not chunk then break end
        outf:write(chunk)
    end
    inf:close()
    outf:close()
    return true
end

-- ---------------------------------------------------------------------------
-- UI & Notifications
-- ---------------------------------------------------------------------------

local osd_overlay = nil
local active_menu = nil
local menu_keys_bound = false

local function show_osd(text, duration_ms)
    mp.osd_message(text, (duration_ms or 3000) / 1000)
end

local function is_uosc_available()
    if opts.uosc == "yes" then return true end
    if opts.uosc == "no" then return false end
    -- Check if uosc script exists or is loaded
    local path = mp.find_config_file("scripts/uosc") or mp.find_config_file("scripts/uosc.lua")
    return path ~= nil
end

-- ---------------------------------------------------------------------------
-- Native ASS OSD Menu Fallback
-- ---------------------------------------------------------------------------

local function close_osd_menu()
    if active_menu then
        active_menu = nil
    end
    if osd_overlay then
        osd_overlay.data = ""
        osd_overlay:update()
    end
    if menu_keys_bound then
        mp.remove_key_binding("subsource_up")
        mp.remove_key_binding("subsource_down")
        mp.remove_key_binding("subsource_k")
        mp.remove_key_binding("subsource_j")
        mp.remove_key_binding("subsource_left")
        mp.remove_key_binding("subsource_right")
        mp.remove_key_binding("subsource_h")
        mp.remove_key_binding("subsource_l")
        mp.remove_key_binding("subsource_enter")
        mp.remove_key_binding("subsource_esc")
        mp.remove_key_binding("subsource_q")
        menu_keys_bound = false
    end
end

local function render_osd_menu()
    if not active_menu then
        close_osd_menu()
        return
    end

    if not osd_overlay then
        osd_overlay = mp.create_osd_overlay("ass-events")
    end

    local PAGE_SIZE = 10
    local total_items = #active_menu.items
    if total_items == 0 then
        osd_overlay.data = "{\\an7\\fs20\\b1\\c&H00D7FF&}SubSource: " .. (active_menu.title or "") ..
                           "\n\\fs16\\b0\\c&HFFFFFF&No items found.\n\\fs14\\c&H888888&[Esc] Close"
        osd_overlay:update()
        return
    end

    local current_page = math.floor((active_menu.selected - 1) / PAGE_SIZE) + 1
    local total_pages = math.ceil(total_items / PAGE_SIZE)
    local start_idx = (current_page - 1) * PAGE_SIZE + 1
    local end_idx = math.min(start_idx + PAGE_SIZE - 1, total_items)

    local ass = {}
    table.insert(ass, "{\\an7\\fs22\\b1\\c&H00E0FF&}SubSource: " .. (active_menu.title or "Menu") .. "{\\r}\n")
    table.insert(ass, "{\\fs14\\c&H888888&}Page " .. current_page .. "/" .. total_pages .. " (Total: " .. total_items .. ")\n\n")

    for i = start_idx, end_idx do
        local item = active_menu.items[i]
        local is_selected = (i == active_menu.selected)
        if is_selected then
            table.insert(ass, "{\\fs18\\b1\\c&H00D7FF&}> {\\c&HFFFFFF&}" .. item.title)
        else
            table.insert(ass, "{\\fs18\\b0\\c&HCCCCCC&}   " .. item.title)
        end
        if item.hint and #item.hint > 0 then
            table.insert(ass, " {\\fs14\\c&H888888&}[" .. item.hint .. "]")
        end
        table.insert(ass, "{\\r}\n")
    end

    table.insert(ass, "\n{\\fs14\\c&H777777&}[↑/↓/k/j] Navigate   [Enter] Select   [←/→] Page   [Esc/q] Close")

    osd_overlay.data = table.concat(ass, "")
    osd_overlay:update()
end

local function open_osd_menu(title, items, on_select)
    active_menu = {
        title = title,
        items = items,
        selected = 1,
        on_select = on_select
    }

    if not menu_keys_bound then
        mp.add_forced_key_binding("UP", "subsource_up", function()
            if active_menu and active_menu.selected > 1 then
                active_menu.selected = active_menu.selected - 1
                render_osd_menu()
            end
        end, {repeatable = true})
        mp.add_forced_key_binding("DOWN", "subsource_down", function()
            if active_menu and active_menu.selected < #active_menu.items then
                active_menu.selected = active_menu.selected + 1
                render_osd_menu()
            end
        end, {repeatable = true})
        mp.add_forced_key_binding("k", "subsource_k", function()
            if active_menu and active_menu.selected > 1 then
                active_menu.selected = active_menu.selected - 1
                render_osd_menu()
            end
        end, {repeatable = true})
        mp.add_forced_key_binding("j", "subsource_j", function()
            if active_menu and active_menu.selected < #active_menu.items then
                active_menu.selected = active_menu.selected + 1
                render_osd_menu()
            end
        end, {repeatable = true})
        mp.add_forced_key_binding("LEFT", "subsource_left", function()
            if active_menu then
                active_menu.selected = math.max(1, active_menu.selected - 10)
                render_osd_menu()
            end
        end)
        mp.add_forced_key_binding("RIGHT", "subsource_right", function()
            if active_menu then
                active_menu.selected = math.min(#active_menu.items, active_menu.selected + 10)
                render_osd_menu()
            end
        end)
        mp.add_forced_key_binding("h", "subsource_h", function()
            if active_menu then
                active_menu.selected = math.max(1, active_menu.selected - 10)
                render_osd_menu()
            end
        end)
        mp.add_forced_key_binding("l", "subsource_l", function()
            if active_menu then
                active_menu.selected = math.min(#active_menu.items, active_menu.selected + 10)
                render_osd_menu()
            end
        end)
        mp.add_forced_key_binding("ENTER", "subsource_enter", function()
            if active_menu and active_menu.items[active_menu.selected] then
                local chosen = active_menu.items[active_menu.selected]
                local cb = active_menu.on_select
                close_osd_menu()
                if cb then cb(chosen) end
            end
        end)
        mp.add_forced_key_binding("ESC", "subsource_esc", close_osd_menu)
        mp.add_forced_key_binding("q", "subsource_q", close_osd_menu)
        menu_keys_bound = true
    end

    render_osd_menu()
end

-- ---------------------------------------------------------------------------
-- Unified Menu Presenter (uosc + fallback)
-- ---------------------------------------------------------------------------

local function show_menu(title, items, on_select)
    if is_uosc_available() then
        local uosc_items = {}
        for _, it in ipairs(items) do
            local val = it.value
            if not val and it.action then
                -- Generate a transient script message
                val = {"script-message", "subsource-action", tostring(it.id or it.title)}
            end
            table.insert(uosc_items, {
                title = it.title,
                hint = it.hint or "",
                value = val,
                icon = it.icon,
                muted = it.muted,
                italic = it.italic,
            })
        end

        local menu_data = {
            type = "subsource",
            title = "SubSource: " .. title,
            items = uosc_items
        }

        mp.commandv("script-message-to", "uosc", "open-menu", utils.format_json(menu_data))
    else
        open_osd_menu(title, items, on_select)
    end
end

-- ---------------------------------------------------------------------------
-- Subtitle Downloader & Track Loader
-- ---------------------------------------------------------------------------

local current_context = {
    title = "",
    year = nil,
    season = nil,
    episode = nil,
    is_series = false,
    movie_id = nil,
    movie_title = "",
}

local function load_subtitle_into_player(sub_file, lang_slug)
    local target_path = sub_file.path

    if opts.save_to_disk or (opts.sub_dir and #opts.sub_dir > 0) then
        local video_path = mp.get_property("path")
        local dest_dir = nil
        local base_name = nil

        if opts.sub_dir and #opts.sub_dir > 0 then
            dest_dir = mp.command_native({"expand-path", opts.sub_dir})
            mp.command_native({name = "subprocess", playback_only = false, args = {"mkdir", "-p", dest_dir}})
            local _, v_filename = utils.split_path(video_path or "video")
            base_name = v_filename:match("^(.-)%.[%w%d]+$") or v_filename
        elseif video_path and not video_path:find("^https?://") then
            local v_dir, v_filename = utils.split_path(video_path)
            dest_dir = v_dir
            base_name = v_filename:match("^(.-)%.[%w%d]+$") or v_filename
        end

        if dest_dir and base_name then
            local ext = sub_file.filename:match("%.([%w%d]+)$") or "srt"
            local lang_suffix = (lang_slug and lang_slug ~= "all") and ("." .. lang_slug) or ""
            local dest_filename = base_name .. lang_suffix .. "." .. ext
            local dest_path = utils.join_path(dest_dir, dest_filename)

            if copy_file(sub_file.path, dest_path) then
                target_path = dest_path
                dlog("Saved subtitle to disk: " .. dest_path)
            end
        end
    end

    dlog("Loading subtitle track: " .. target_path)
    mp.commandv("sub-add", target_path, "select")
    show_osd("SubSource: Loaded " .. sub_file.filename, 4000)
end

local function download_subtitle_by_id(subtitle_id, release_name, lang_slug)
    local key = get_api_key()
    local id = tostring(subtitle_id):gsub("%D", "")
    if #id == 0 then
        show_osd("SubSource: Invalid subtitle ID", 3000)
        return
    end

    local tmp_dir = get_temp_dir()
    local zip_file = utils.join_path(tmp_dir, "subsource-" .. id .. ".zip")
    local extract_dir = utils.join_path(tmp_dir, "subsource-" .. id)
    local url = opts.base_url .. "/subtitles/" .. id .. "/download"

    mp.command_native({name = "subprocess", playback_only = false, args = {"mkdir", "-p", extract_dir}})

    show_osd("SubSource: Downloading subtitle...", 3000)
    dlog("Downloading: " .. url)

    local args = {
        "curl",
        "-sSL",
        "--ipv4",
        "-w", "%{http_code}",
        "--connect-timeout", tostring(opts.timeout or 15),
        "--max-time", "60",
        "-H", "X-API-Key: " .. key,
        "-H", "User-Agent: mpv-subsource/" .. PLUGIN_VERSION,
        "-o", zip_file,
        url
    }

    mp.command_native_async({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = args
    }, function(success, res, err)
        if not success or res.status ~= 0 then
            show_osd("SubSource: Download failed!", 4000)
            msg.error("Download failed: " .. tostring(res and res.stderr or err))
            return
        end

        local status = tonumber(res.stdout:match("(%d%d%d)")) or 0
        if status ~= 200 then
            os.remove(zip_file)
            local emsg = (status == 401 or status == 403) and "API key rejected"
                      or (status == 429) and "Rate limit exceeded"
                      or ("HTTP error " .. tostring(status))
            show_osd("SubSource: " .. emsg, 4000)
            return
        end

        if file_is_zip(zip_file) then
            mp.command_native_async({
                name = "subprocess",
                playback_only = false,
                args = {"unzip", "-o", "-q", zip_file, "-d", extract_dir}
            }, function(unzip_success, unzip_res, unzip_err)
                local files = find_subtitle_files(extract_dir)
                if #files == 0 then
                    show_osd("SubSource: No subtitle files found in archive", 4000)
                    return
                end

                local episode = current_context.episode
                local season = current_context.season
                local picked = pick_files_for_episode(files, season, episode)

                if #picked == 1 then
                    load_subtitle_into_player(picked[1], lang_slug)
                else
                    -- Multiple files or season pack: prompt user to pick the file
                    local menu_items = {}
                    for _, f in ipairs(files) do
                        table.insert(menu_items, {
                            title = f.filename,
                            hint = "Subtitle file",
                            value = {"script-message", "subsource-load-file", f.path, lang_slug or ""},
                            path = f.path
                        })
                    end

                    show_menu("Choose Subtitle File", menu_items, function(chosen)
                        load_subtitle_into_player({filename = chosen.title, path = chosen.path}, lang_slug)
                    end)
                end
            end)
        else
            -- Plain subtitle file
            local raw_file = utils.join_path(extract_dir, (release_name or "subtitle-" .. id) .. ".srt")
            os.rename(zip_file, raw_file)
            load_subtitle_into_player({filename = release_name or ("subtitle-" .. id .. ".srt"), path = raw_file}, lang_slug)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- SubSource Search Flow
-- ---------------------------------------------------------------------------

local function fetch_subtitles_for_movie(movie_id, movie_title, auto_pick)
    current_context.movie_id = movie_id
    current_context.movie_title = movie_title

    show_osd("SubSource: Fetching subtitles...", 2500)

    local langs = get_configured_languages()
    local lang_param = table.concat(langs, ",")
    if lang_param == "all" then lang_param = nil end

    local query_params = {
        movieId = movie_id,
        language = lang_param,
        sort = opts.sort or "popular",
        limit = opts.max_results or 50,
        page = 1,
    }

    if opts.hearing_impaired == "only" then
        query_params.hearingImpaired = true
    elseif opts.hearing_impaired == "exclude" then
        query_params.hearingImpaired = false
    end

    http_get("/subtitles", query_params, function(res, status, err)
        if err or not res then
            show_osd("SubSource: " .. (err or "Failed to list subtitles"), 4000)
            return
        end

        local subs = res.data or {}
        if #subs == 0 then
            show_osd("SubSource: No subtitles found for " .. movie_title, 4000)
            return
        end

        local filtered_subs = {}
        local ep = current_context.episode
        local season = current_context.season

        for _, s in ipairs(subs) do
            local keep = true
            if opts.episode_filter and ep and current_context.is_series then
                local cls = classify_episode(s.releaseInfo or s.releaseName or "", season, ep)
                if cls == "other" then
                    keep = false
                end
            end
            if keep then
                table.insert(filtered_subs, s)
            end
        end

        if #filtered_subs == 0 then
            filtered_subs = subs -- Fallback to all if episode filter removed everything
        end

        local function get_release_name(s)
            if type(s) == "table" then
                if type(s.releaseInfo) == "table" and #s.releaseInfo > 0 then
                    return tostring(s.releaseInfo[1])
                elseif type(s.releaseInfo) == "string" and #s.releaseInfo > 0 then
                    return s.releaseInfo
                elseif type(s.releaseName) == "string" and #s.releaseName > 0 then
                    return s.releaseName
                end
                return "Subtitle #" .. tostring(s.subtitleId or s.id or "0")
            end
            return tostring(s or "Subtitle")
        end

        local function get_rating_str(s)
            if type(s) == "table" then
                if type(s.rating) == "number" and s.rating > 0 then
                    return string.format("★%.1f", s.rating)
                elseif type(s.rating) == "table" and s.rating.total and s.rating.total > 0 then
                    local r = (s.rating.good or 0) / s.rating.total * 5
                    return string.format("★%.1f", r)
                end
            end
            return nil
        end

        local function get_downloads_str(s)
            if type(s) == "table" then
                local dl = tonumber(s.downloads or s.downloadCount or 0)
                if dl and dl > 0 then
                    return "↓" .. tostring(dl)
                end
            end
            return nil
        end

        if auto_pick and #filtered_subs > 0 then
            local top = filtered_subs[1]
            local sid = top.subtitleId or top.id
            local top_rel = get_release_name(top)
            download_subtitle_by_id(sid, top_rel, top.language)
            return
        end

        local menu_items = {}
        for _, s in ipairs(filtered_subs) do
            local sid = s.subtitleId or s.id
            local rel = get_release_name(s)
            local lang_name = language_display_name(s.language)
            local dl_str = get_downloads_str(s)
            local r_str = get_rating_str(s)
            local hi = s.hearingImpaired and "HI" or nil

            local hint_parts = {lang_name}
            if r_str then table.insert(hint_parts, r_str) end
            if dl_str then table.insert(hint_parts, dl_str) end
            if hi then table.insert(hint_parts, hi) end

            table.insert(menu_items, {
                id = sid,
                title = rel,
                hint = table.concat(hint_parts, " | "),
                icon = "subtitles",
                value = {"script-message", "subsource-download", tostring(sid), rel, s.language or ""},
                lang = s.language,
                release = rel
            })
        end

        show_menu(movie_title, menu_items, function(chosen)
            download_subtitle_by_id(chosen.id, chosen.release, chosen.lang)
        end)
    end)
end

local function search_movies_query(query_str, year, season, is_series, auto_load)
    show_osd("SubSource: Searching for '" .. query_str .. "'...", 2500)
    dlog("Search titles: query=" .. query_str)

    local params = {
        searchType = "text",
        q = query_str,
    }
    if year then params.year = year end
    if is_series then params.type = "series" end
    if season then params.season = season end

    http_get("/movies/search", params, function(res, status, err)
        if err or not res then
            show_osd("SubSource: " .. (err or "Search failed"), 4000)
            return
        end

        local results = res.data or {}
        if #results == 0 then
            -- If searched with year, try again without year
            if params.year then
                params.year = nil
                http_get("/movies/search", params, function(res2, status2, err2)
                    local results2 = res2 and res2.data or {}
                    if #results2 == 0 then
                        show_osd("SubSource: No matches found for '" .. query_str .. "'", 3500)
                    else
                        handle_movie_search_results(results2, query_str, auto_load)
                    end
                end)
                return
            end
            show_osd("SubSource: No matches found for '" .. query_str .. "'", 3500)
            return
        end

        handle_movie_search_results(results, query_str, auto_load)
    end)
end

function handle_movie_search_results(results, query_str, auto_load)
    -- Compute similarity scores to sort best match first
    for _, m in ipairs(results) do
        local sim = similarity(query_str, m.title or "")
        if current_context.season and m.season and tonumber(m.season) == tonumber(current_context.season) then
            sim = sim + 1.0
        end
        m._score = sim
    end
    table.sort(results, function(a, b) return (a._score or 0) > (b._score or 0) end)

    -- If auto_load or only 1 match with high confidence (> 0.85)
    if #results == 1 or (auto_load and results[1]._score and results[1]._score >= 0.7) then
        local top = results[1]
        local title_str = top.title .. (top.releaseYear and (" (" .. top.releaseYear .. ")") or "")
        fetch_subtitles_for_movie(top.movieId or top.id, title_str, auto_load)
        return
    end

    local menu_items = {}
    for _, m in ipairs(results) do
        local mid = m.movieId or m.id
        local mtitle = m.title or "Unknown"
        local year_str = m.releaseYear and (" (" .. m.releaseYear .. ")") or ""
        local type_str = m.type or ""
        local sub_cnt = m.subtitleCount and (tostring(m.subtitleCount) .. " subs") or ""
        local hint = table.concat({type_str, sub_cnt}, " | ")

        local full_title = mtitle .. year_str
        table.insert(menu_items, {
            id = mid,
            title = full_title,
            hint = hint,
            icon = "movie",
            value = {"script-message", "subsource-select-movie", tostring(mid), full_title},
            movie_title = full_title
        })
    end

    show_menu("Select Title", menu_items, function(chosen)
        fetch_subtitles_for_movie(chosen.id, chosen.movie_title, false)
    end)
end

-- ---------------------------------------------------------------------------
-- Main Search Trigger
-- ---------------------------------------------------------------------------

local function start_search(custom_query, auto_load)
    local key = get_api_key()
    if not key or #key == 0 then
        show_osd("SubSource: No API key set! Set it in script-opts/subsource.conf or SUBSOURCE_API_KEY", 6000)
        msg.warn("No SubSource API key found. Get a free key at https://subsource.net/profile")
        return
    end

    local filename = mp.get_property("filename") or ""
    local media_title = mp.get_property("media-title") or ""

    if custom_query and #custom_query > 0 then
        current_context = {
            title = custom_query,
            year = nil,
            season = nil,
            episode = nil,
            is_series = false,
        }
        search_movies_query(custom_query, nil, nil, false, auto_load)
        return
    end

    local parsed = parse_filename(filename)
    if not parsed.title or #parsed.title == 0 then
        parsed = parse_filename(media_title)
    end

    if not parsed.title or #parsed.title == 0 then
        show_osd("SubSource: Could not parse video title from filename", 3500)
        return
    end

    current_context = {
        title = parsed.title,
        year = parsed.year,
        season = parsed.season,
        episode = parsed.episode,
        is_series = parsed.isSeries,
    }

    dlog(string.format("Parsed: title='%s', year=%s, season=%s, ep=%s, series=%s",
        parsed.title, tostring(parsed.year), tostring(parsed.season), tostring(parsed.episode), tostring(parsed.isSeries)))

    search_movies_query(parsed.title, parsed.year, parsed.season, parsed.isSeries, auto_load)
end

-- ---------------------------------------------------------------------------
-- Script Messages & Key Bindings
-- ---------------------------------------------------------------------------

mp.register_script_message("subsource-search", function(query)
    start_search(query, false)
end)

mp.register_script_message("subsource-download-top", function()
    start_search(nil, true)
end)

mp.register_script_message("subsource-select-movie", function(movie_id, title)
    fetch_subtitles_for_movie(movie_id, title, false)
end)

mp.register_script_message("subsource-download", function(sub_id, release_name, lang)
    download_subtitle_by_id(sub_id, release_name, lang)
end)

mp.register_script_message("subsource-load-file", function(path, lang)
    local _, name = utils.split_path(path)
    load_subtitle_into_player({filename = name, path = path}, lang)
end)

mp.register_script_message("subsource-set-key", function(key)
    if not key or #key == 0 then
        show_osd("SubSource: API key cannot be empty", 3000)
        return
    end
    opts.api_key = key
    show_osd("SubSource: API key updated!", 3000)
end)

-- uosc search callback
mp.register_script_message("subsource-query", function(query)
    if query and #query > 0 then
        start_search(query, false)
    end
end)

-- Script bindings for mpv input.conf
mp.add_key_binding(nil, "search", function() start_search(nil, false) end)
mp.add_key_binding(nil, "download-top", function() start_search(nil, true) end)
mp.add_key_binding(nil, "manual-search", function()
    -- Prompt user for input if possible or trigger search
    if is_uosc_available() then
        -- Open a uosc menu in search palette mode
        local menu_data = {
            type = "subsource_search",
            title = "SubSource: Type title to search...",
            search_style = "palette",
            on_search = {"script-message", "subsource-query"},
            items = {}
        }
        mp.commandv("script-message-to", "uosc", "open-menu", utils.format_json(menu_data))
    else
        show_osd("SubSource: Use 'script-message subsource-search <title>' in console", 4000)
    end
end)

-- Default binding 'b' for searching SubSource subtitles
mp.add_key_binding("b", "subsource-menu", function()
    start_search(nil, opts.auto_load)
end)

-- Auto-search on video loaded if configured
mp.register_event("file-loaded", function()
    if opts.auto_search or opts.auto_load then
        start_search(nil, opts.auto_load)
    end
end)

dlog("SubSource plugin v" .. PLUGIN_VERSION .. " loaded")

return {
    version = PLUGIN_VERSION,
    parse_filename = parse_filename,
    similarity = similarity,
    classify_episode = classify_episode,
    pick_files_for_episode = pick_files_for_episode,
    normalize_language = normalize_language,
    language_display_name = language_display_name,
}


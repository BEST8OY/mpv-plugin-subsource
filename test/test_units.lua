-- Unit tests for subsource.lua

-- Mock the mpv environment for standalone headless execution
package.preload["mp"] = function()
    return {
        register_script_message = function() end,
        add_key_binding = function() end,
        register_event = function() end,
        commandv = function() end,
        get_property = function() return "" end,
    }
end

package.preload["mp.utils"] = function()
    return {
        format_json = function() return "{}" end,
        parse_json = function() return {} end,
    }
end

package.preload["mp.options"] = function()
    return {
        read_options = function(opts) end,
    }
end

package.preload["mp.msg"] = function()
    return {
        info = function() end,
        warn = function() end,
        error = function() end,
        debug = function() end,
    }
end

-- Resolve path to subsource.lua
local script_source = debug.getinfo(1, "S").source
local dir = script_source:match("^@?(.*[/\\])") or "./"
local subsource_path = dir .. "../subsource.lua"

local loader = loadfile or load
local subsource, err = loader(subsource_path)
if not subsource then
    io.stderr:write("Failed to load subsource.lua: " .. tostring(err) .. "\n")
    os.exit(1)
end
local m = subsource()

local passed = 0
local failed = 0

local function test(name, fn)
    local ok, test_err = pcall(fn)
    if ok then
        passed = passed + 1
        print(string.format("  ✔ %s", name))
    else
        failed = failed + 1
        io.stderr:write(string.format("  ✖ %s: %s\n", name, tostring(test_err)))
    end
end

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected '%s', got '%s'", message or "Assertion failed", tostring(expected), tostring(actual)))
    end
end

print("Running SubSource Lua Unit Tests...")

-- 1. parse_filename test suite
local cases = {
    {"Inception.2010.1080p.BluRay.x264-SPARKS.mkv", { title = "Inception", year = 2010, isSeries = false }},
    {"Inception (2010) [1080p] [YTS.MX].mp4", { title = "Inception", year = 2010, isSeries = false }},
    {"Severance.S02E10.Cold.Harbor.1080p.ATVP.WEB-DL.DDP5.1.H.264-FLUX.mkv", { title = "Severance", season = 2, episode = 10, isSeries = true }},
    {"The Bear - 3x05 - Children.mkv", { title = "The Bear", season = 3, episode = 5, isSeries = true }},
    {"Some Show Season 1 Episode 2.mp4", { title = "Some Show", season = 1, episode = 2, isSeries = true }},
    {"Blade.Runner.2049.2017.2160p.UHD.BluRay.x265-TERMiNAL.mkv", { title = "Blade Runner 2049", year = 2017, isSeries = false }},
    {"1917.2019.720p.WEBRip.x264.mkv", { title = "1917", year = 2019, isSeries = false }},
    {"Dune Part Two", { title = "Dune Part Two", isSeries = false }},
    {"Severance.S01.1080p.WEB.H264-PACK", { title = "Severance", season = 1, isSeries = true }},
    {"Oppenheimer.2023.IMAX.1080p.WEB.h264-ETHEL", { title = "Oppenheimer", year = 2023, isSeries = false }},
}

for _, tc in ipairs(cases) do
    local input, exp = tc[1], tc[2]
    test(string.format("parse_filename: %s", input), function()
        local r = m.parse_filename(input)
        for k, v in pairs(exp) do
            assert_eq(r[k], v, string.format("Field '%s' in %s", k, input))
        end
    end)
end

-- 2. classify_episode test suite
test("classify_episode matching", function()
    assert_eq(m.classify_episode({"Severance.S02E10.Cold.Harbor.1080p"}, 2, 10), "match")
    assert_eq(m.classify_episode({"Severance.S02E09.1080p"}, 2, 10), "other")
    assert_eq(m.classify_episode({"Severance.S02.1080p.ATVP.WEB-DL"}, 2, 10), "pack")
    assert_eq(m.classify_episode({"Severance.S01.Complete"}, 2, 10), "other")
    assert_eq(m.classify_episode({"Severance S02E01-E10 WEB"}, 2, 3), "match")
    assert_eq(m.classify_episode({"Some random release name"}, 2, 3), "unknown")
    assert_eq(m.classify_episode({"Severance.S02E10"}, nil, 10), "match")
    assert_eq(m.classify_episode({"Show.2x03.HDTV"}, 2, 3), "match")
    assert_eq(m.classify_episode({"anything"}, 2, nil), "unknown")
end)

-- 3. similarity test suite
test("similarity calculation", function()
    assert_eq(m.similarity("Inception", "Inception"), 1)
    if m.similarity("The Bear", "Bear") <= 0.9 then error("The Bear vs Bear similarity too low") end
    if m.similarity("Inception", "Cruel Intentions") >= 0.5 then error("Inception vs Cruel Intentions similarity too high") end
    if m.similarity("Blade Runner 2049", "Blade Runner") <= 0.6 then error("Blade Runner similarity too low") end
end)

-- 4. pick_files_for_episode test suite
test("pick_files_for_episode archive picking", function()
    local files = {
        { filename = "Severance.S02E01.srt", path = "/tmp/1" },
        { filename = "Severance.S02E10.srt", path = "/tmp/10" },
    }
    local p1 = m.pick_files_for_episode(files, 2, 10)
    assert_eq(#p1, 1, "Expected 1 file matched for S02E10")
    assert_eq(p1[1].path, "/tmp/10", "Matched path")

    local p2 = m.pick_files_for_episode(files, 2, nil)
    assert_eq(#p2, 0, "Expected 0 files when episode is nil")

    local p3 = m.pick_files_for_episode({files[1]}, nil, nil)
    assert_eq(#p3, 1, "Single file fallback")
    assert_eq(p3[1].path, "/tmp/1", "Single file fallback path")
end)

-- 5. normalize_language test suite
test("normalize_language code mapping", function()
    assert_eq(m.normalize_language("en"), "english")
    assert_eq(m.normalize_language("fa"), "farsi_persian")
    assert_eq(m.normalize_language("english"), "english")
    assert_eq(m.normalize_language("farsi_persian"), "farsi_persian")
    assert_eq(m.normalize_language("es"), "spanish")
    assert_eq(m.normalize_language("fr"), "french")
    assert_eq(m.normalize_language("de"), "german")
    assert_eq(m.normalize_language("all"), "all")
end)

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end

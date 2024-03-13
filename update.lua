#!/usr/bin/env lua5.4

if package == nil or package.config == nil or package.config:sub(1,2) ~= "/\n" then
    io.stderr:write[[
You are probably running this script either in a Lua interpreter built for
a native Windows environment, or with some other extra funky Lua environment.

This script can only run in ordinary UNIX-ish Lua environments.

You are welcome to run this script on Windows using some kind of compatibility
layer (e.g. MinGW, Git Bash, Cygwin, or WSL).
]]
    os.exit(1)
end

local DEPS<const> = {
    {module="cjson", package="lua-cjson2"},
    {module="lfs", package="luafilesystem"},
    {module="http.request", package="http"},
    {module="base64", package="base64"},
}

local failed_deps = {}
for _,dep in ipairs(DEPS) do
    if not pcall(require, dep.module) then
        failed_deps[#failed_deps+1] = dep
    end
end

if #failed_deps == 1 then
    local dep = failed_deps[1]
    io.stderr:write([[
We require the Lua "]]..dep.module..[[" module.
If you use LuaRocks, you can install it with:

  luarocks install ]]..dep.package.."\n\n")
    os.exit(1)
elseif #failed_deps > 1 then
    io.stderr:write("We require the Lua ")
    for i,dep in ipairs(failed_deps) do
        if i == #failed_deps then
            io.stderr:write("and ")
        end
        io.stderr:write("\"", dep.module, "\"")
        if i ~= #failed_deps then
            io.stderr:write(", ")
        end
    end
    io.stderr:write[[ modules.
If you use LuaRocks, you can install them with:

]]
    for _,dep in ipairs(failed_deps) do
        io.stderr:write("  luarocks install ", dep.package, "\n")
    end
    io.stderr:write("\n")
    os.exit(1)
end

local p = io.popen("unzip --help", "r")
if not p or not p:read("*a"):match("Usage") then
    io.stderr:write[[
We need the "unzip" utility in order to unpack the artifacts.

Please install it.
]]
    os.exit(1)
end

local p = io.popen("git", "r")
if not p or not p:read("*a"):match("git help") then
    io.stderr:write[[
We need the "git" utility in order to get components of the repository.

Please install it.
]]
    os.exit(1)
end

local cjson, lfs, http_request, base64
    = require "cjson", require "lfs", require "http.request", require "base64"

if _VERSION ~= "Lua 5.4" then
    io.stderr:write("Warning! This script was made for Lua 5.4, not "..tostring(_VERSION)..".\n(We'll try to run anyway.)\n")
end

local debuggy = false

if arg[0] and arg[0]:match("/") then
    if not lfs.chdir(arg[0]:gsub("[^/]*$","")) then
        io.stderr:write("Unable to change to the directory containing this script. Giving up.\n")
        os.exit(1)
    end
else
    io.stderr:write("We don't know where we're being run from. Please run us using an absolute or relative path (e.g. \"./update.lua\")\n")
    os.exit(1)
end

local token = os.getenv("GITHUB_TOKEN")
local authorization
if token then
    authorization = "Basic "..base64.encode("fake:"..token)
end

local run_url = arg[1]
local repo, run_id
if run_url then
    repo, run_id = run_url:match("^https://github%.com/(.+)/actions/run/([0-9]+)/?$")
end
if not repo or not token then
    io.stderr:write("Usage: GITHUB_TOKEN=<token> ", arg[0], " https://github.com/<repo>/actions/run/<run_id>\n")
    os.exit(1)
end
local repo_url = "https://github.com/"..repo

local function set_request_headers(request)
    request.headers:append("accept", "application/vnd.github+json")
    request.headers:append("x-github-api-version", "2022-11-28")
    if authorization then
        request.headers:append("authorization", authorization)
    end
end

local function perform_request(url, expected_status, no_headers)
    expected_status = expected_status or "200"
    if debuggy then
        io.stderr:write("\x1b[2mURL: ",url,"\x1b[0m\n")
    end
    local request = http_request.new_from_uri(url)
    request.follow_redirects = false
    request.headers:upsert("user-agent", "Mozilla/3.01Gold (Macintosh; I; 68K)")
    if not no_headers then
        set_request_headers(request)
    end
    local headers,stream = request:go()
    if not headers then
        io.stderr:write("Error performing request! ", tostring(stream), "\n");
        os.exit(1)
    end
    local status = headers:get ":status"
    if status ~= expected_status then
        if status == "404" then
            io.stderr:write("Got a 404 response from the server. The artifact may have expired out from under us!\n")
        else
            io.stderr:write("Expected status ",expected_status,", got status ", status, "!\n")
            local body = stream:get_body_as_string()
            if body then
                io.stderr:write(body)
            end
        end
        os.exit(1)
    end
    return headers,stream
end

local function perform_json_request(url)
    local headers,stream = perform_request(url)
    local body = stream:get_body_as_string()
    if not body then
        io.stderr:write("Error reading response body!\n");
        os.exit(1)
    end
    local json = cjson.decode(body)
    if not json then
        io.stderr:write("Got invalid JSON from the server!\n");
        os.exit(1)
    end
    return json
end

local function escape_for_shell(foo)
    return "'"..foo:gsub("'","'\"'\"'").."'"
end

-- note: if we ever get more than 30 artifacts, we're frelled
local artifacts = perform_json_request("https://api.github.com/repos/"..repo.."/actions/runs/"..run_id.."/artifacts").artifacts
if #artifacts <= 1 then
    io.stderr:write("There are improbably few artifacts. Something must have gone wrong. Giving up!\n")
    os.exit(1)
end

-- Clean up, clean up...
local function recursive_delete(path)
    if lfs.symlinkattributes(path, "mode") == "directory" then
        for ent in lfs.dir(path) do
            if ent ~= "." and ent ~= ".." then
                recursive_delete(path.."/"..ent)
            end
        end
        if debuggy then
            io.stderr:write("\x1b[2;33mrm\x1b[0;2m ",path," (dir)\x1b[0m\n")
        end
        assert(lfs.rmdir(path))
    else
        if debuggy then
            io.stderr:write("\x1b[2;33mrm\x1b[0;2m ",path,"\x1b[0m\n")
        end
        assert(os.remove(path))
    end
end

print("Cleaning up previous artifacts...")
for ent in lfs.dir(".") do
    if ent:sub(1,1) ~= "." and ent ~= "update.lua" and ent ~= "README.md" then
        recursive_delete(ent)
    end
end
print("Creating metadata files...")
local function echo_into(file, wat)
    if wat then
        local f = assert(io.open(file, "wb"))
        assert(f:write(wat,"\n"))
        f:close()
    end
end
echo_into("SOURCE_RUN", run_url)
echo_into("SOURCE_REPOSITORY", repo_url)
-- casually assume all artifacts from this run will be based on the same commit
echo_into("SOURCE_COMMIT", artifacts[1].workflow_run.head_sha)
echo_into("SOURCE_BRANCH", artifacts[1].workflow_run.head_branch)

-- For each artifact...
for _,artifact in ipairs(artifacts) do
    -- ...download the zipfile...
    assert(artifact.archive_download_url:sub(-4,-1) == "/zip",
        "The artifact isn't being presented as a zipfile. Are we doomed?")
    print("Downloading artifact \""..artifact.name.."\"...")
    local headers,stream = perform_request(artifact.archive_download_url, "302")
    local real_url = headers:get "location"
    if not real_url then
        io.stderr:write("Expected a Location header in the response from the server, but didn't get one!\n")
        os.exit(1)
    end
    local headers,stream = perform_request(real_url, "200", true)
    local f = assert(io.open("temp.zip", "wb"))
    for chunk in stream:each_chunk() do
        io.stderr:write(".")
        assert(f:write(chunk))
    end
    io.stderr:write("done.\n")
    f:close()
    local trimmed_name = artifact.name:gsub("^csms%-","")
    assert(lfs.mkdir(trimmed_name))
    assert(os.execute("cd "..escape_for_shell(trimmed_name).."/ && unzip -q ../temp.zip"), "Unable to unzip the artifact.")
    os.remove("temp.zip")
end

print("Downloading repository (for headers)...")
assert(os.execute("git clone -q --single-branch -b "..escape_for_shell(artifacts[1].workflow_run.head_branch).." "..escape_for_shell(repo_url).." temp.git && cd temp.git && git checkout -q "..escape_for_shell(artifacts[1].workflow_run.head_sha)), "Unable to check out the repository.")
assert(os.execute("cd temp.git && mv -v c-second-music-system/include .."), "Unable to extract the `include` directory.")
function update_readme()
    local f = io.open("README.md", "rb")
    if not f then
        print("WARNING: We don't have a README.md? Not updating it...")
        return
    end
    local original = assert(f:read("*a"), "unable to read the README")
    f:close()
    f = io.open("temp.git/README.md", "rb")
    if not f then
        print("WARNING: Unable to open the README.md from the source repository. Not updating ours.")
        return
    end
    local source = assert(f:read("*a"), "unable to read the other README")
    f:close()
    local source_legalese = source:match("(# Legalese[^#]+)")
    if not source_legalese then
        print("WARNING: The source repository lacks a Legalese section. Not updating ours.")
        return
    end
    local new = original:gsub("# Legalese[^#]+",source_legalese)
    if new == original then
        -- Nothing to update.
        return
    end
    print("Updating legalese in readme...")
    f = assert(io.open("README.md~", "wb"))
    assert(f:write(new))
    f:close()
    assert(os.rename("README.md~", "README.md"))
end
update_readme()
recursive_delete("temp.git")
print("All set!")

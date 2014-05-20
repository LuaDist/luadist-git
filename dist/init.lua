-- main API of LuaDist

module ("dist", package.seeall)

local cfg = require "dist.config"
local depends = require "dist.depends"
local git = require "dist.git"
local sys = require "dist.sys"
local package = require "dist.package"
local mf = require "dist.manifest"
local utils = require "dist.utils"

-- Return the deployment directory.
function get_deploy_dir()
    return sys.abs_path(cfg.root_dir)
end

-- Return packages deployed in 'deploy_dir' also with their provides.
function get_deployed(deploy_dir)
    deploy_dir = deploy_dir or cfg.root_dir
    assert(type(deploy_dir) == "string", "dist.get_deployed: Argument 'deploy_dir' is not a string.")
    deploy_dir = sys.abs_path(deploy_dir)

    local deployed = depends.get_installed(deploy_dir)
    local provided = {}

    for _, pkg in pairs(deployed) do
        for _, provided_pkg in pairs(depends.get_provides(pkg)) do
            provided_pkg.provided_by = pkg.name .. "-" .. pkg.version
            table.insert(provided, provided_pkg)
        end
    end

    for _, provided_pkg in pairs(provided) do
        table.insert(deployed, provided_pkg)
    end

    deployed = depends.sort_by_names(deployed)
    return deployed
end

-- Download new 'manifest_file' from repository and returns it.
-- Return nil and error message on error.
function update_manifest(deploy_dir)
    deploy_dir = deploy_dir or cfg.root_dir
    assert(type(deploy_dir) == "string", "dist.update_manifest: Argument 'deploy_dir' is not a string.")
    deploy_dir = sys.abs_path(deploy_dir)

    -- TODO: use 'deploy_dir' argument in manifest functions

    -- retrieve the new manifest (forcing no cache use)
    local manifest, err = mf.get_manifest(nil, true)

    if manifest then
        return manifest
    else
        return nil, err
    end
end

-- Install 'package_names' to 'deploy_dir', using optional CMake 'variables'.
function install(package_names, deploy_dir, variables)
    if not package_names then return true end
    deploy_dir = deploy_dir or cfg.root_dir
    if type(package_names) == "string" then package_names = {package_names} end

    assert(type(package_names) == "table", "dist.install: Argument 'package_names' is not a table or string.")
    assert(type(deploy_dir) == "string", "dist.install: Argument 'deploy_dir' is not a string.")
    deploy_dir = sys.abs_path(deploy_dir)

    -- find installed packages
    local installed = depends.get_installed(deploy_dir)

    -- get manifest
    local manifest, err = mf.get_manifest()
    if not manifest then return nil, "Error getting manifest: " .. err end

    -- resolve dependencies
    local dependencies, err = depends.get_depends(package_names, installed, manifest, false, false, deploy_dir)
    if err then return nil, err end
    if #dependencies == 0 then return nil, "No packages to install." end

    -- fetch the packages from repository
    local dirs, err = package.fetch_pkgs(dependencies, sys.make_path(deploy_dir, cfg.temp_dir))
    if not dirs then return nil, err end

    -- install fetched packages
    for _, dir in pairs(dirs) do
        ok, err = package.install_pkg(dir, deploy_dir, variables, false)
        if not ok then return nil, err end
    end

    return true
end

-- Update functionality BETA
function update(package_names, deploy_dir, variables)
    if not package_names then return true end
    deploy_dir = deploy_dir or cfg.root_dir

     if type(package_names) == "string" then package_names = {package_names} end

    assert(type(package_names) == "table", "dist.install: Argument 'package_names' is not a table or string.")
    assert(type(deploy_dir) == "string", "dist.install: Argument 'deploy_dir' is not a string.")
    deploy_dir = sys.abs_path(deploy_dir)

    -- find installed packages
    
    local installed = depends.get_installed(deploy_dir)

    -- get manifest
    local manifest, err = mf.get_manifest()
    if not manifest then return nil, "Error getting manifest: " .. err end

    -- resolve dependencies
    local dependencies, err = depends.get_depends_1(package_names, installed, manifest, false, false, deploy_dir)
    if err then return nil, err end
    if #dependencies == 0 then return nil, "No packages to update."
    else
        pkgs_to_remove = depends.find_packages(package_names, installed)
        -- delete installed packages
        for _, pkg in pairs(pkgs_to_remove) do
            local pkg_distinfo_dir = sys.make_path(cfg.distinfos_dir, pkg.name .. "-" .. pkg.version)
            local ok, err = package.remove_pkg(pkg_distinfo_dir, deploy_dir)
            if not ok then return nil, err end
        end
    end

    -- fetch the packages from repository
    local dirs, err = package.fetch_pkgs(dependencies, sys.make_path(deploy_dir, cfg.temp_dir))
    if not dirs then return nil, err end

    -- install fetched packages
    for _, dir in pairs(dirs) do
        ok, err = package.install_pkg(dir, deploy_dir, variables, false)
        if not ok then return nil, err end
    end

    return true

end

-- Manually deploy packages from 'package_paths' to 'deploy_dir', using optional
-- CMake 'variables'. The 'package_paths' are preserved (will not be deleted).
function make(deploy_dir, package_paths, variables)
    deploy_dir = deploy_dir or cfg.root_dir
    package_paths = package_paths or {}

    assert(type(deploy_dir) == "string", "dist.make: Argument 'deploy_dir' is not a string.")
    assert(type(package_paths) == "table", "dist.make: Argument 'package_paths' is not a table.")
    deploy_dir = sys.abs_path(deploy_dir)

    local ok, err
    for _, path in pairs(package_paths) do
        ok, err = package.install_pkg(sys.abs_path(path), deploy_dir, variables, true)
        if not ok then return nil, err end
    end
    return ok
end

-- Remove 'package_names' from 'deploy_dir' and return the number of removed
-- packages.
function remove(package_names, deploy_dir)
    deploy_dir = deploy_dir or cfg.root_dir
    if type(package_names) == "string" then package_names = {package_names} end

    assert(type(package_names) == "table", "dist.remove: Argument 'package_names' is not a string or table.")
    assert(type(deploy_dir) == "string", "dist.remove: Argument 'deploy_dir' is not a string.")
    deploy_dir = sys.abs_path(deploy_dir)

    local pkgs_to_remove = {}
    local installed = depends.get_installed(deploy_dir)

    -- find packages to remove
    if #package_names == 0 then
        pkgs_to_remove = installed
    else
        pkgs_to_remove = depends.find_packages(package_names, installed)
    end

    if #package_names == 0 then
        print("Are you sure that you want to remove ALL modules (y/n)?")
    else
        print("Are you sure that you want to remove these modules (y/n)?")
    end

    for i, pkg_name in pairs(package_names) do
            io.write(pkg_name)
            if i == #pkg_name then 
                io.write(', ')
            end
    end
    print()
    repeat
        --io.write("continue with this operation (y/n)? ")
        io.flush()
        answer=io.read()
    until answer=="y" or answer=="n"

    if answer == "n" then
        return 0
    end

    -- remove them
    for _, pkg in pairs(pkgs_to_remove) do
        local pkg_distinfo_dir = sys.make_path(cfg.distinfos_dir, pkg.name .. "-" .. pkg.version)
        local ok, err = package.remove_pkg(pkg_distinfo_dir, deploy_dir)
        if not ok then return nil, err end
    end

    return #pkgs_to_remove
end

-- Download 'pkg_names' to 'fetch_dir'.
function fetch(pkg_names, fetch_dir)
    fetch_dir = fetch_dir or sys.current_dir()
    assert(type(pkg_names) == "table", "dist.fetch: Argument 'pkg_names' is not a string or table.")
    assert(type(fetch_dir) == "string", "dist.fetch: Argument 'fetch_dir' is not a string.")
    fetch_dir = sys.abs_path(fetch_dir)

    local manifest = mf.get_manifest()

    local pkgs_to_fetch = {}

    for _, pkg_name in pairs(pkg_names) do

        -- retrieve available versions
        local versions, err = package.retrieve_versions(pkg_name, manifest)
        if not versions then return nil, err end
        for _, version in pairs(versions) do
            table.insert(manifest, version)
        end

        local packages = depends.find_packages(pkg_name, manifest)
        if #packages == 0 then return nil, "No packages found for '" .. pkg_name .. "'." end

        packages = depends.sort_by_versions(packages)
        table.insert(pkgs_to_fetch, packages[1])
    end

    local ok, err = package.fetch_pkgs(pkgs_to_fetch, fetch_dir)

    if not ok then
        return nil, err
    else
        return ok
    end
end

-- Upload binary version of given modules installed in the specified
-- 'deploy_dir' to the repository specified by provided base url.
-- Return the number of uploaded packages.
--
-- Organization of uploaded modules and their repositories is subject
-- to the following conventions:
--   - destination repository is: 'DEST_GIT_BASE_URL/MODULE_NAME'
--   - module will be uploaded to the branch: 'ARCH-TYPE' according
--     to the arch and type of the user's machine
--   - the module will be tagged as: 'VERSION-ARCH-TYPE' (if the tag already
--     exists, it will be overwritten)
--
-- E.g. assume that the module 'lua-5.1.4' is installed on the 32bit Linux
-- system (Linux-i686). When this function is called with the module name
-- 'lua' and base url 'git@github.com:LuaDist', then the binary version
-- of the module 'lua', that is installed on the machine, will be uploaded
-- to the branch 'Linux-i686' of the repository 'git@github.com:LuaDist/lua.git'
-- and tagged as '5.1.4-Linux-i686'.
function upload_modules(deploy_dir, module_names, dest_git_base_url)
    deploy_dir = deploy_dir or cfg.root_dir
    if type(module_names) == "string" then module_names = {module_names} end
    assert(type(deploy_dir) == "string", "dist.upload_module: Argument 'deploy_dir' is not a string.")
    assert(type(module_names) == "table", "dist.upload_module: Argument 'module_name' is not a string or table.")
    assert(type(dest_git_base_url) == "string", "dist.upload_module: Argument 'dest_git_base_url' is not a string.")
    deploy_dir = sys.abs_path(deploy_dir)

    local modules_to_upload = {}
    local installed = depends.get_installed(deploy_dir)

    -- find modules to upload
    if #module_names == 0 then
        modules_to_upload = installed
    else
        modules_to_upload = depends.find_packages(module_names, installed)
    end

    for _, installed_module in pairs(modules_to_upload) do

        -- set names
        local branch_name = cfg.arch .. "-" .. cfg.type
        local tag_name = installed_module.version .. "-" .. branch_name
        local full_name = installed_module.name .. "-" .. tag_name
        local tmp_dir = sys.make_path(deploy_dir, cfg.temp_dir, full_name .. "-to-upload")
        local dest_git_url = dest_git_base_url .. "/" .. installed_module.name .. ".git"
        local distinfo_file = sys.make_path(deploy_dir, cfg.distinfos_dir, installed_module.name .. "-" .. installed_module.version, "dist.info")

        -- create temporary directory (delete previous if already exists)
        if sys.exists(tmp_dir) then sys.delete(tmp_dir) end
        local ok, err = sys.make_dir(tmp_dir)
        if not ok then return nil, err end

        -- copy the module files for all enabled components
        for _, component in ipairs(cfg.components) do
            if installed_module.files[component] then
                for _, file in ipairs(installed_module.files[component]) do
                    local file_path = sys.make_path(deploy_dir, file)
                    local dest_dir = sys.parent_dir(sys.make_path(tmp_dir, file))
                    if sys.is_file(file_path) then
                        sys.make_dir(dest_dir)
                        sys.copy(file_path, dest_dir)
                    end
                end
            end
        end

        -- add module's dist.info file
        sys.copy(distinfo_file, tmp_dir)

        -- create git repo
        ok, err = git.init(tmp_dir)
        if not ok then return nil, "Error initializing empty git repository in '" .. tmp_dir .. "': " .. err end

        -- add all files
        ok, err = git.add_all(tmp_dir)
        if not ok then return nil, "Error adding all files to the git index in '" .. tmp_dir .. "': " .. err end

        -- create commit
        ok, err = git.commit("[luadist-git] add " .. full_name .. " [ci skip]", tmp_dir)
        if not ok then return nil, "Error commiting changes in '" .. tmp_dir .. "': " .. err end

        -- rename branch
        ok, err = git.rename_branch("master", branch_name, tmp_dir)
        if not ok then return nil, "Error renaming branch 'master' to '" .. branch_name .. "' in '" .. tmp_dir .. "': " .. err  end

        -- create tag
        ok, err = git.create_tag(tmp_dir, tag_name)
        if not ok then return nil, "Error creating tag '" .. tag_name .. "' in '" .. tmp_dir .. "': " .. err end

        print("Uploading " .. full_name .. " to " .. dest_git_url .. "...")

        -- push to the repository
        ok, err = git.push_ref(tmp_dir, branch_name, dest_git_url, true)
        if not ok then return nil, "Error when pushing branch '" .. branch_name .. "' and tag '" .. tag_name .. "' to '" .. dest_git_url .. "': " .. err end

        -- delete temporary directory (if not in debug mode)
        if not cfg.debug then sys.delete(tmp_dir) end
    end

    return #modules_to_upload
end

-- Returns table with information about module's dependencies, using the cache.
function dependency_info(module, cache_file)
    cache_file = cache_file or sys.abs_path(sys.make_path(cfg.root_dir, cfg.dep_cache_file))
    assert(type(module) == "string", "dist.dep_info: Argument 'module' is not a string.")
    assert(type(cache_file) == "string", "dist.dep_info: Argument 'cache_file' is not a string.")

    local dep_cache, err = {}
    if sys.exists(cache_file) then
        -- TODO: use current 'deploy_dir' for cache file, or 'root_dir'?
        dep_cache, err = mf.load_manifest(cache_file)
        if not dep_cache then return nil, err end
    end

    -- get dependency information and updated cache
    local dep_manifest = {}
    dep_manifest, dep_cache_or_err = depends.dependency_manifest(module, dep_manifest, dep_cache)
    if not dep_manifest then return nil, dep_cache_or_err end
    dep_cache = dep_cache_or_err

    -- save updated cache
    local ok, err = mf.save_manifest(dep_cache, cache_file)
    if not ok then return nil, err end

    return dep_manifest
end

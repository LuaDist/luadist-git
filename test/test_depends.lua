-- Tests of LuaDist's dependency resolving

local dist = require "dist"
local cfg = require "dist.config"
local depends = require "dist.depends"

-- Return string describing packages and versions in 'pkgs' table, separated by space.
-- e.g.: "luadist-1.2 coxpcall-0.4 luafilesystem 0.3"
-- If 'pkgs' is nil, return nil.
local function describe_packages(pkgs)

    if not pkgs then return nil end

    assert(type(pkgs) == "table", "depends.get_packages_to_install: Argument 'pkgs' is not a table.")

    local str = ""

    for k,v in ipairs(pkgs) do
        if k == 1 then
            str = str .. v.name .. "-" .. v.version
        else
            str = str .. " " .. v.name .. "-" .. v.version
        end
    end

    return str
end

-- Return test fail message.
local function pkgs_fail_msg(pkgs, err)
    if not pkgs then
        return "TEST FAILED!!! - Returned packages were: 'nil' \n    Error was: \"" .. (tostring(err) or "nil") .. "\""
    else
        return "TEST FAILED!!! - Returned packages were: '" .. describe_packages(pkgs) .. "' \n    Error was: \"" .. (tostring(err) or "nil") .. "\""
    end
end

-- Run all the 'tests' and display results.
local function run_tests(tests)
    local passed = 0
    local failed = 0

    for name, test in pairs(tests) do
        local ok, err = pcall(test)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("In '" .. name .. "()': " .. err)
        end
    end
    if failed > 0 then print("----------------------------------") end
    print("Passed " .. passed .. "/" .. passed + failed .. " tests (" .. failed .. " failed).")
end


-- Test suite.
local tests = {}


--- ========== DEPENDENCY RESOLVING TESTS ==========

--- === DEPENDS ===

--- normal dependencies

-- a depends b, install a
tests.depends_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm",}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-scm a-scm", pkgs_fail_msg(pkgs, err))
end

-- a depends b, b depends c, install a
tests.depends_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm",}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "c-scm b-scm a-scm", pkgs_fail_msg(pkgs, err))
end

-- a depends b, a depends c, a depends d, c depends f, c depends g, d depends c,
-- d depends e, d depends j, e depends h, e depends i, g depends l, j depends k,
-- install a
tests.depends_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b", "c", "d"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm",}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", depends={"f", "g"}}
    manifest.d = {name="d", arch="Universal", type="all", version="scm", depends={"c", "e", "j"}}
    manifest.e = {name="e", arch="Universal", type="all", version="scm", depends={"h", "i"}}
    manifest.f = {name="f", arch="Universal", type="all", version="scm",}
    manifest.g = {name="g", arch="Universal", type="all", version="scm", depends={"l"}}
    manifest.h = {name="h", arch="Universal", type="all", version="scm",}
    manifest.i = {name="i", arch="Universal", type="all", version="scm",}
    manifest.j = {name="j", arch="Universal", type="all", version="scm", depends={"k"}}
    manifest.k = {name="k", arch="Universal", type="all", version="scm",}
    manifest.l = {name="l", arch="Universal", type="all", version="scm",}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-scm f-scm l-scm g-scm c-scm h-scm i-scm e-scm k-scm j-scm d-scm a-scm", pkgs_fail_msg(pkgs, err))
end


--- circular dependencies

-- a depends b, b depends a, install a
tests.depends_circular_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"a-scm"}}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("circular"), pkgs_fail_msg(pkgs, err))
end

-- a depends b, b depends a, install a + b
tests.depends_circular_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"a"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("circular"), pkgs_fail_msg(pkgs, err))
end

-- a depends b, b depends c, c depends a, install a
tests.depends_circular_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", depends={"a"}}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("circular"), pkgs_fail_msg(pkgs, err))
end

-- a depends b, b depends c, c depends d, d depends e, e depends b, install a
tests.depends_circular_4 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", depends={"d"}}
    manifest.d = {name="d", arch="Universal", type="all", version="scm", depends={"e"}}
    manifest.e = {name="e", arch="Universal", type="all", version="scm", depends={"b"}}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("circular"), pkgs_fail_msg(pkgs, err))
end


--- === CONFLICTS ===

--- conflicts with installed  package

-- a installed, a conflicts b, install b
tests.conflicts_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", conflicts={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end

-- a installed, b conflicts a, install b
tests.conflicts_with_installed_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm",}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", conflicts={"a"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end

-- a installed, b conflicts a, a conflicts b, install b
tests.conflicts_with_installed_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", conflicts={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", conflicts={"a"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end


--- conflicts with another package to install

-- a conflicts b, install a + b
tests.conflicts_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", conflicts={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end

-- b conflicts a, install a + b
tests.conflicts_with_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm",}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", conflicts={"a"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end

-- b conflicts a, a conflicts b, install a + b
tests.conflicts_with_to_install_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", conflicts={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", conflicts={"a"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end


--- === CONFLICTS + DEPENDS ===

--- conflicts of dependencies with installed package

-- a installed, b depends c, a conflicts c, install b
tests.conflicts_and_depends_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", conflicts={"c"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end

-- a installed, b depends c, c conflicts a, install b
tests.conflicts_and_depends_with_installed_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm",}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", conflicts={"a"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end


--- conflicts of dependencies with another package to install

-- a depends b, b conflicts c, install a + c
tests.conflicts_and_depends_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", conflicts={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end

-- a depends b, c conflicts b, install a + c
tests.conflicts_and_depends_with_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm",}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", conflicts={"b"}}

    local pkgs, err = depends.get_depends({'a', 'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end


--- === PROVIDES ===

--- direct provides with installed package

-- a installed, a provides b, install b
tests.provides_direct_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"b-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "", pkgs_fail_msg(pkgs, err))
end

-- a installed, b provides a, install b
tests.provides_direct_with_installed_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm",}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", provides={"a-scm"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("already installed"), pkgs_fail_msg(pkgs, err))
end


--- direct provides with package to install

-- TODO: When dealing with this situation, luadist-git finds that a can be installed
--       so it adds 'a' to the packages to install an then when checking the 'b' package,
--       it treats 'a' as being installed, so it simply skips the 'b' package.
--       Implement this in such a way that the user will be warned that he was
--       trying to install two incompatible packages?
-- a provides b, install a + b
--[[
tests.provides_direct_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"b-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("already selected"), pkgs_fail_msg(pkgs, err))
end
--]]

-- b provides a, install a + b
tests.provides_direct_with_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm",}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", provides={"a-scm"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("already selected"), pkgs_fail_msg(pkgs, err))
end


--- the same provides with installed package

-- a installed, a provides c, b provides c, install b
tests.provides_same_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"c-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", provides={"c-scm"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("already installed"), pkgs_fail_msg(pkgs, err))
end

--- the same provides with package to install

-- a provides c, b provides c, install a + b
tests.provides_same_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"c-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", provides={"c-scm"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("already selected"), pkgs_fail_msg(pkgs, err))
end


--- === PROVIDES + DEPENDS ===

--- direct provides with dependencies and installed package

-- a installed, a provides c, b depends c, install b
tests.provides_direct_and_depends_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"c-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-scm", pkgs_fail_msg(pkgs, err))
end

-- a installed, b depends c, c provides a, install b
tests.provides_direct_and_depends_with_installed_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm",}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", provides={"a-scm"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("already installed"), pkgs_fail_msg(pkgs, err))
end


--- direct provides with dependencies and package to install

-- a provides c, b depends c, install a + b
tests.provides_direct_and_depends_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"c-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-scm b-scm", pkgs_fail_msg(pkgs, err))
end

-- TODO: To make luadist-git find the solution in this situation, it would have
--       to try all possible permutations of packages to install (e.g. reversed)
--       or use some logic engine. Implement it?
-- a depends c, b provides c, install a + b
--[[
tests.provides_direct_and_depends_with_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", provides={"c-scm"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    print(err)
    assert(describe_packages(pkgs) == "b-scm a-scm", pkgs_fail_msg(pkgs, err))
end
--]]


--- the same provides with dependencies and installed package

-- a installed, a provides d, b depends c, c provides d, install b
tests.provides_same_and_depends_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"d-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", provides={"d-scm"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("already installed"), pkgs_fail_msg(pkgs, err))
end


--- the same provides with dependencies and package to install

-- a depends b, b provides d, c provides d, install a + c
tests.provides_same_and_depends_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", provides={"d-scm"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", provides={"d-scm"}}

    local pkgs, err = depends.get_depends({'a', 'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("already selected"), pkgs_fail_msg(pkgs, err))
end

-- a provides d, b depends c, c provides d, install a + b
tests.provides_same_and_depends_with_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"d-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", provides={"d-scm"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("already selected"), pkgs_fail_msg(pkgs, err))
end

-- a depends b, b provides e, c depends d, d provides e, install a + c
tests.provides_same_and_depends_with_to_install_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", provides={"e-scm"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", depends={"d"}}
    manifest.d = {name="d", arch="Universal", type="all", version="scm", provides={"e-scm"}}

    local pkgs, err = depends.get_depends({'a', 'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("already selected"), pkgs_fail_msg(pkgs, err))
end


--- === PROVIDES + CONFLICTS ===

--- direct provides with conflicts and package to install

-- a provides b, b conflicts c, install a + c
tests.provides_direct_and_conflicts_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"b-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", conflicts={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-scm c-scm", pkgs_fail_msg(pkgs, err))
end

-- a provides b, b conflicts c, install c + a
tests.provides_direct_and_conflicts_with_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"b-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", conflicts={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm",}

    local pkgs, err = depends.get_depends({'c', 'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "c-scm a-scm", pkgs_fail_msg(pkgs, err))
end

-- a provides b, c conflicts b, install a + c
tests.provides_direct_and_conflicts_with_to_install_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"b-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm",}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", conflicts={"b"}}

    local pkgs, err = depends.get_depends({'a', 'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end

-- a provides b, c conflicts b, install c + a
tests.provides_direct_and_conflicts_with_to_install_4 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"b-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm",}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", conflicts={"b"}}

    local pkgs, err = depends.get_depends({'c', 'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end


--- direct provides with conflicts and installed package

-- a installed, a provides b, b conflicts c, install c
tests.provides_direct_and_conflicts_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"b-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", conflicts={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "c-scm", pkgs_fail_msg(pkgs, err))
end

-- a installed, a provides b, c conflicts b, install c
tests.provides_direct_and_conflicts_with_installed_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"b-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm",}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", conflicts={"b"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end


--- === PROVIDES + DEPENDS + CONFLICTS ===

--- direct provides with dependencies + conflicts and installed package

-- a installed, a provides d, b depends c, c conflicts d, install b
tests.provides_direct_depends_and_conflicts_with_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"d-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", conflicts={"d"}}
    manifest.d = {name="d", arch="Universal", type="all", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end

-- a installed, a conflicts d, b depends c, c provides d, install b
tests.provides_direct_depends_and_conflicts_with_installed_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", conflicts={"d"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", provides={"d-scm"}}
    manifest.d = {name="d", arch="Universal", type="all", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end

-- a installed, a provides c, b depends c, c depends d, d conflicts a, install b
tests.provides_direct_depends_and_conflicts_with_installed_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"c-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", depends={"d"}}
    manifest.d = {name="d", arch="Universal", type="all", version="scm", conflicts={"a"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-scm", pkgs_fail_msg(pkgs, err))
end

-- a installed, a provides c, a conflicts d, b depends c, c depends d, install b
tests.provides_direct_depends_and_conflicts_with_installed_4 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"c-scm"}, conflicts={"d"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", depends={"d"}}
    manifest.d = {name="d", arch="Universal", type="all", version="scm",}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-scm", pkgs_fail_msg(pkgs, err))
end

-- a installed, a provides b, b depends c, d conflicts c, install c
tests.provides_direct_depends_and_conflicts_with_installed_5 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"b-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm",}
    manifest.d = {name="d", arch="Universal", type="all", version="scm", conflicts={"c"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "c-scm", pkgs_fail_msg(pkgs, err))
end

--- direct provides with dependencies + conflicts and package to install

-- a provides c, b depends c, c depends d, d conflicts a, install a + b
tests.provides_direct_depends_and_conflicts_with_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"c-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", depends={"d"}}
    manifest.d = {name="d", arch="Universal", type="all", version="scm", conflicts={"a"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-scm b-scm", pkgs_fail_msg(pkgs, err))
end

-- a provides c, a conflicts d, b depends c, c depends d, install a + b
tests.provides_direct_depends_and_conflicts_with_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", provides={"c-scm"}, conflicts={"d"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", depends={"d"}}
    manifest.d = {name="d", arch="Universal", type="all", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-scm b-scm", pkgs_fail_msg(pkgs, err))
end


-- TODO: Non-standard situation so luadist-git cannot find the solution. Implement it?
-- b provides c, a depends c, c depends d, d conflicts a, install a + b
--[[
tests.provides_direct_depends_and_conflicts_with_to_install_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", provides={"c-scm"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", depends={"d"}}
    manifest.d = {name="d", arch="Universal", type="all", version="scm", conflicts={"a"}}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-scm a-scm", pkgs_fail_msg(pkgs, err))
end
--]]

-- TODO: Non-standard situation so luadist-git cannot find the solution. Implement it?
-- b provides c, a depends c, c depends d, a conflicts d, install a + b
--[[
tests.provides_direct_depends_and_conflicts_with_to_install_4 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"c"}, conflicts={"a"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", provides={"c-scm"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", depends={"d"}}
    manifest.d = {name="d", arch="Universal", type="all", version="scm"}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-scm a-scm", pkgs_fail_msg(pkgs, err))
end
--]]

-- a depends b, b provides e, c depends d, d conflicts e, install a + c
tests.provides_direct_depends_and_conflicts_with_to_install_5 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", provides={"e-scm"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", depends={"d"}}
    manifest.d = {name="d", arch="Universal", type="all", version="scm", conflicts={"e"}}

    local pkgs, err = depends.get_depends({'a', 'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end

-- a depends b, b provides c, d depends e, e provides f, f conflicts c, install a + d
tests.provides_direct_depends_and_conflicts_with_to_install_6 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", provides={"c-scm"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm",}
    manifest.d = {name="d", arch="Universal", type="all", version="scm", depends={"e"}}
    manifest.e = {name="e", arch="Universal", type="all", version="scm", provides={"f-scm"}}
    manifest.f = {name="f", arch="Universal", type="all", version="scm", conflicts={"c"}}

    local pkgs, err = depends.get_depends({'a', 'd'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-scm a-scm e-scm d-scm", pkgs_fail_msg(pkgs, err))
end

-- a depends b, b provides c, c conflicts f, d depends e, e provides f, install a + d
tests.provides_direct_depends_and_conflicts_with_to_install_7 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", provides={"c-scm"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", conflicts={"f"}}
    manifest.d = {name="d", arch="Universal", type="all", version="scm", depends={"e"}}
    manifest.e = {name="e", arch="Universal", type="all", version="scm", provides={"f-scm"}}
    manifest.f = {name="f", arch="Universal", type="all", version="scm",}

    local pkgs, err = depends.get_depends({'a', 'd'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-scm a-scm e-scm d-scm", pkgs_fail_msg(pkgs, err))
end

--- === REPLACES ===

-- 'replaces' relationship hasn't been implemented in luadist-git yet


--- ========== VERSION RESOLVING TESTS  ============================================

--- check if the newest package version is chosen to install

-- a.1 & a.2 avalable, install a, check if the newest 'a' version is chosen
tests.version_install_newest_1 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1"}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2"}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-2", pkgs_fail_msg(pkgs, err))
end

-- a depends b, b.1 & b.2 avalable, install a, check if the newest 'b' version is chosen
tests.version_install_newest_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="scm", depends={"b"}}
    manifest.b1 = {name="b", arch="Universal", type="all", version="1"}
    manifest.b2 = {name="b", arch="Universal", type="all", version="2"}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-2 a-scm", pkgs_fail_msg(pkgs, err))
end

-- provide more version types and check if the newest one is chosen to install
tests.version_install_newest_3 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="scm", depends={"b"}}
    manifest.a2 = {name="a", arch="Universal", type="all", version="1", depends={"b"}}

    manifest.b1 = {name="b", arch="Universal", type="all", version="1.99", depends={"c"}}
    manifest.b2 = {name="b", arch="Universal", type="all", version="2.0", depends={"c"}}

    manifest.c1 = {name="c", arch="Universal", type="all", version="2alpha", depends={"d"}}
    manifest.c2 = {name="c", arch="Universal", type="all", version="2beta", depends={"d"}}

    manifest.d1 = {name="d", arch="Universal", type="all", version="1rc2", depends={"e"}}
    manifest.d2 = {name="d", arch="Universal", type="all", version="1rc3", depends={"e"}}

    manifest.e1 = {name="e", arch="Universal", type="all", version="3.1beta", depends={"f"}}
    manifest.e2 = {name="e", arch="Universal", type="all", version="3.1pre", depends={"f"}}

    manifest.f1 = {name="f", arch="Universal", type="all", version="3.1pre", depends={"g"}}
    manifest.f2 = {name="f", arch="Universal", type="all", version="3.1rc", depends={"g"}}

    manifest.g1 = {name="g", arch="Universal", type="all", version="1rc", depends={"h"}}
    manifest.g2 = {name="g", arch="Universal", type="all", version="1scm", depends={"h"}}

    manifest.h1 = {name="h", arch="Universal", type="all", version="1alpha2",}
    manifest.h2 = {name="h", arch="Universal", type="all", version="1work2",}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "h-1alpha2 g-1scm f-3.1rc e-3.1pre d-1rc3 c-2beta b-2.0 a-1", pkgs_fail_msg(pkgs, err))
end

-- provide more version types and check if the newest one is chosen to install
tests.version_install_newest_4 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.1", depends={"b"}}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2alpha", depends={"b"}}

    manifest.b1 = {name="b", arch="Universal", type="all", version="1.2", depends={"c"}}
    manifest.b2 = {name="b", arch="Universal", type="all", version="1.2beta", depends={"c"}}

    manifest.c1 = {name="c", arch="Universal", type="all", version="1rc3", depends={"d"}}
    manifest.c2 = {name="c", arch="Universal", type="all", version="1.1rc2", depends={"d"}}

    manifest.d1 = {name="d", arch="Universal", type="all", version="2.1beta3",}
    manifest.d2 = {name="d", arch="Universal", type="all", version="2.2alpha2",}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "d-2.2alpha2 c-1.1rc2 b-1.2 a-2alpha", pkgs_fail_msg(pkgs, err))
end


--- check if version in depends is correctly used

tests.version_of_depends_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="1.0", depends={"b<=1"}}

    manifest.b1 = {name="b", arch="Universal", type="all", version="1.0", depends={"c>=2"}}
    manifest.b2 = {name="b", arch="Universal", type="all", version="2.0", depends={"c>=2"}}

    manifest.c1 = {name="c", arch="Universal", type="all", version="1.9", depends={"d~>3.3"}}
    manifest.c2 = {name="c", arch="Universal", type="all", version="2.0", depends={"d~>3.3"}}
    manifest.c3 = {name="c", arch="Universal", type="all", version="2.1", depends={"d~>3.3"}}

    manifest.d1 = {name="d", arch="Universal", type="all", version="3.2",}
    manifest.d2 = {name="d", arch="Universal", type="all", version="3.3",}
    manifest.d3 = {name="d", arch="Universal", type="all", version="3.3.1",}
    manifest.d4 = {name="d", arch="Universal", type="all", version="3.3.2",}
    manifest.d5 = {name="d", arch="Universal", type="all", version="3.4",}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "d-3.3.2 c-2.1 b-1.0 a-1.0", pkgs_fail_msg(pkgs, err))
end

tests.version_of_depends_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="1.0", depends={"b~=1.0"}}

    manifest.b1 = {name="b", arch="Universal", type="all", version="1.0", depends={"c<2.1"}}
    manifest.b2 = {name="b", arch="Universal", type="all", version="0.9", depends={"c<2.1"}}

    manifest.c1 = {name="c", arch="Universal", type="all", version="2.0.9", depends={"d==4.4alpha"}}
    manifest.c2 = {name="c", arch="Universal", type="all", version="2.1.0", depends={"d==4.4alpha"}}
    manifest.c3 = {name="c", arch="Universal", type="all", version="2.1.1", depends={"d==4.4alpha"}}

    manifest.d1 = {name="d", arch="Universal", type="all", version="4.0",}
    manifest.d2 = {name="d", arch="Universal", type="all", version="4.5",}
    manifest.d3 = {name="d", arch="Universal", type="all", version="4.4beta",}
    manifest.d4 = {name="d", arch="Universal", type="all", version="4.4alpha",}
    manifest.d5 = {name="d", arch="Universal", type="all", version="4.4",}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "d-4.4alpha c-2.0.9 b-0.9 a-1.0", pkgs_fail_msg(pkgs, err))
end

tests.version_of_depends_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="1.0", depends={"b>1.2"}}

    manifest.b1 = {name="b", arch="Universal", type="all", version="1.2", depends={"c~=2.1.1"}}
    manifest.b2 = {name="b", arch="Universal", type="all", version="1.2alpha", depends={"c~=2.1.1"}}
    manifest.b3 = {name="b", arch="Universal", type="all", version="1.2beta", depends={"c~=2.1.1"}}
    manifest.b5 = {name="b", arch="Universal", type="all", version="1.3rc", depends={"c~=2.1.1"}}
    manifest.b4 = {name="b", arch="Universal", type="all", version="1.3", depends={"c~=2.1.1"}}

    manifest.c1 = {name="c", arch="Universal", type="all", version="2.0.9"}
    manifest.c3 = {name="c", arch="Universal", type="all", version="2.1.1"}
    manifest.c2 = {name="c", arch="Universal", type="all", version="2.1.0"}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "c-2.1.0 b-1.3 a-1.0", pkgs_fail_msg(pkgs, err))
end

tests.version_of_depends_4 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0"}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0"}

    manifest.b1 = {name="b", arch="Universal", type="all", version="1.0", depends={"a>=1.0"}}
    manifest.b2 = {name="b", arch="Universal", type="all", version="2.0", depends={"a>=2.0"}}

    manifest.c = {name="c", arch="Universal", type="all", version="1.0", depends={"a~>1.0","b>=1.0"}}

    local pkgs, err = depends.get_depends({'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-1.0 b-1.0 c-1.0", pkgs_fail_msg(pkgs, err))
end

tests.version_of_depends_5 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0"}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0", depends={"x"}}

    manifest.b = {name="b", arch="Universal", type="all", version="1.0", depends={"a==1.0"}}

    manifest.c = {name="c", arch="Universal", type="all", version="1.0", depends={"a>=1.0","b>=1.0"}}

    local pkgs, err = depends.get_depends({'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-1.0 b-1.0 c-1.0", pkgs_fail_msg(pkgs, err))
end

-- TODO: Without trying all possible permutations of packages to install
-- LuaDist probably can't find a solution to this.
--[[
tests.version_of_depends_6 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0"}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0"}

    manifest.b = {name="b", arch="Universal", type="all", version="1.0", depends={"a==1.0"}}

    manifest.c = {name="c", arch="Universal", type="all", version="1.0", depends={"a>=1.0","b>=1.0"}}

    local pkgs, err = depends.get_depends({'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-1.0 b-1.0 c-1.0", pkgs_fail_msg(pkgs, err))
end
--]]

-- TODO: Without trying all possible permutations of packages to install
-- LuaDist probably can't find a solution to this.
--[[
tests.version_of_depends_7 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0"}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0", depends={"d==1.0"}}

    manifest.d1 = {name="d", arch="Universal", type="all", version="1.0"}
    manifest.d2 = {name="d", arch="Universal", type="all", version="2.0"}

    manifest.b = {name="b", arch="Universal", type="all", version="1.0", depends={"a==1.0"}}

    manifest.c = {name="c", arch="Universal", type="all", version="1.0", depends={"a>=1.0","b>=1.0"}}

    local pkgs, err = depends.get_depends({'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-1.0 b-1.0 c-1.0", pkgs_fail_msg(pkgs, err))
end
--]]

--- check if the installed package is in needed version

-- a-1.2 installed, b depends a>=1.2, install b
tests.version_of_installed_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="1.2",}
    manifest.b = {name="b", arch="Universal", type="all", version="1.0", depends={"a>=1.2"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-1.0", pkgs_fail_msg(pkgs, err))
end

-- a-1.2 installed, a-1.3 also available, b depends a>=1.2, install b
tests.version_of_installed_2 = function()
    local manifest, installed = {}, {}
    manifest.a12 = {name="a", arch="Universal", type="all", version="1.2",}
    manifest.a13 = {name="a", arch="Universal", type="all", version="1.3",}
    manifest.b = {name="b", arch="Universal", type="all", version="1.0", depends={"a>=1.2"}}
    installed.a12 = manifest.a12

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-1.0", pkgs_fail_msg(pkgs, err))
end

-- a-1.2 installed, b depends a>=1.4, install b
tests.version_of_installed_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="1.2",}
    manifest.b = {name="b", arch="Universal", type="all", version="1.0", depends={"a>=1.4"}}
    installed.a = manifest.a

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("but installed at version"), pkgs_fail_msg(pkgs, err))
end

-- a-1.2 installed, a-1.3 also available, b depends a>=1.3, install b
tests.version_of_installed_4 = function()
    local manifest, installed = {}, {}
    manifest.a12 = {name="a", arch="Universal", type="all", version="1.2",}
    manifest.a13 = {name="a", arch="Universal", type="all", version="1.3",}
    manifest.b = {name="b", arch="Universal", type="all", version="1.0", depends={"a>=1.3"}}
    installed.a12 = manifest.a12

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("but installed at version"), pkgs_fail_msg(pkgs, err))
end


--- check if the package provided by another installed package is in needed version

-- a-1.2 provided, b depends a>=1.2, install b
tests.version_of_provided_1 = function()
    local manifest, installed = {}, {}
    manifest.x = {name="x", arch="Universal", type="all", version="scm", provides={"a-1.2"}}
    manifest.b = {name="b", arch="Universal", type="all", version="1.0", depends={"a>=1.2"}}
    installed.x = manifest.x

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-1.0", pkgs_fail_msg(pkgs, err))
end

-- a-1.2 provided, a-1.3 also available, b depends a>=1.2, install b
tests.version_of_provided_2 = function()
    local manifest, installed = {}, {}
    manifest.x = {name="x", arch="Universal", type="all", version="scm", provides={"a-1.2"}}
    manifest.a = {name="a", arch="Universal", type="all", version="1.3",}
    manifest.b = {name="b", arch="Universal", type="all", version="1.0", depends={"a>=1.2"}}
    installed.x = manifest.x

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-1.0", pkgs_fail_msg(pkgs, err))
end

-- a-1.2 provided, b depends a>=1.4, install b
tests.version_of_provided_3 = function()
    local manifest, installed = {}, {}
    manifest.x = {name="x", arch="Universal", type="all", version="scm", provides={"a-1.2"}}
    manifest.b = {name="b", arch="Universal", type="all", version="1.0", depends={"a>=1.4"}}
    installed.x = manifest.x

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("but installed at version"), pkgs_fail_msg(pkgs, err))
end

-- a-1.2 provided, a-1.3 also available, b depends a>=1.3, install b
tests.version_of_provided_4 = function()
    local manifest, installed = {}, {}
    manifest.x = {name="x", arch="Universal", type="all", version="scm", provides={"a-1.2"}}
    manifest.a = {name="a", arch="Universal", type="all", version="1.3",}
    manifest.b = {name="b", arch="Universal", type="all", version="1.0", depends={"a>=1.3"}}
    installed.x = manifest.x

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("but installed at version"), pkgs_fail_msg(pkgs, err))
end

--- ========== OTHER EXCEPTIONAL STATES  =====================================

--- states when no packages to install are found

-- when no such package exists
tests.no_packages_to_install_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="1.0",}

    local pkgs, err = depends.get_depends({'x'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("No suitable candidate"), pkgs_fail_msg(pkgs, err))
end

-- when no such dependency exists
tests.no_packages_to_install_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="1.0", depends={"x"}}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("No suitable candidate"), pkgs_fail_msg(pkgs, err))
end

-- when no such dependency version exists
tests.no_packages_to_install_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="1.0", depends={"b>1.0"}}
    manifest.b = {name="b", arch="Universal", type="all", version="0.9",}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("No suitable candidate"), pkgs_fail_msg(pkgs, err))
end

-- when all required packages are installed
tests.no_packages_to_install_4 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="1.0",}
    manifest.b = {name="b", arch="Universal", type="all", version="0.9",}
    installed.a = manifest.a
    installed.b = manifest.b

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "", pkgs_fail_msg(pkgs, err))
end

--- states when installed pkg is not in manifest

-- normal installed package
tests.installed_not_in_manifest_1 = function()
    local manifest, installed = {}, {}
    manifest.b = {name="b", arch="Universal", type="all", version="0.9", depends={"a"}}
    installed.a = {name="a", arch="Universal", type="all", version="1.0",}

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-0.9", pkgs_fail_msg(pkgs, err))
end

-- provided package
tests.installed_not_in_manifest_2 = function()
    local manifest, installed = {}, {}
    manifest.b = {name="b", arch="Universal", type="all", version="0.9", depends={"a"}}
    installed.x = {name="x", arch="Universal", type="all", version="1.0", provides={"a-1.0"}}

    local pkgs, err = depends.get_depends({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-0.9", pkgs_fail_msg(pkgs, err))
end


--- ========== ARCH & TYPE CHECKS  =====================================

-- no package of required arch
tests.arch_type_checks_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="notUniversal", type="all", version="1.0",}
    manifest.b = {name="b", arch="notUniversal", type="all", version="0.9",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("arch and type"), pkgs_fail_msg(pkgs, err))
end

-- no package of required type
tests.arch_type_checks_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="not_all", version="1.0",}
    manifest.b = {name="b", arch="Universal", type="not_all", version="0.9",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("arch and type"), pkgs_fail_msg(pkgs, err))
end

-- only some packages have required arch
tests.arch_type_checks_3 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="notUniversal", type="all", version="1.1",}
    manifest.a2 = {name="a", arch="Universal", type="all", version="1.0",}
    manifest.b1 = {name="b", arch="notUniversal", type="all", version="1.9",}
    manifest.b2 = {name="b", arch="Universal", type="all", version="0.8",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-1.0 b-0.8", pkgs_fail_msg(pkgs, err))
end

-- only some packages have required type
tests.arch_type_checks_4 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="not_all", version="1.1",}
    manifest.a2 = {name="a", arch="Universal", type="all", version="1.0",}
    manifest.b1 = {name="b", arch="Universal", type="not_all", version="1.9",}
    manifest.b2 = {name="b", arch="Universal", type="all", version="0.8",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-1.0 b-0.8", pkgs_fail_msg(pkgs, err))
end

-- only some packages have required arch & type
tests.arch_type_checks_5 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="notUniversal", type="all", version="1.1",}
    manifest.a2 = {name="a", arch="Universal", type="not_all", version="1.0",}
    manifest.a3 = {name="a", arch="notUniversal", type="not_all", version="0.9",}
    manifest.a4 = {name="a", arch="Universal", type="all", version="0.8",}

    manifest.b1 = {name="b", arch="notUniversal", type="all", version="1.9",}
    manifest.b2 = {name="b", arch="Universal", type="not_all", version="1.8",}
    manifest.b3 = {name="b", arch="notUniversal", type="not_all", version="1.7",}
    manifest.b4 = {name="b", arch="Universal", type="source", version="1.5",}

    local pkgs, err = depends.get_depends({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-0.8 b-1.5", pkgs_fail_msg(pkgs, err))
end

--- ========== OS specific dependencies  =====================================

-- only OS specific dependencies
tests.os_specific_depends_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="1.0", depends={[cfg.arch] = {"b", "c"}}}
    manifest.b = {name="b", arch="Universal", type="all", version="0.9",}
    manifest.c = {name="c", arch="Universal", type="all", version="0.9",}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-0.9 c-0.9 a-1.0", pkgs_fail_msg(pkgs, err))
end

-- OS specific dependency of other arch
tests.os_specific_depends_2 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="1.0", depends={['other'] = {"b"}}}
    manifest.b = {name="b", arch="Universal", type="all", version="0.9",}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-1.0", pkgs_fail_msg(pkgs, err))
end

-- normal and OS specific dependencies
tests.os_specific_depends_3 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="1.0", depends={"c", [cfg.arch] = {"b"}, "d"}}
    manifest.b = {name="b", arch="Universal", type="all", version="0.9",}
    manifest.c = {name="c", arch="Universal", type="all", version="0.9",}
    manifest.d = {name="d", arch="Universal", type="all", version="0.9",}

    local pkgs, err = depends.get_depends({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "c-0.9 d-0.9 b-0.9 a-1.0", pkgs_fail_msg(pkgs, err))
end


--- ========== INSTALL SPECIFIC VERSION  =====================================

--- install specific version

-- a-1.0 available, a-2.0 available, install a-1.0
tests.install_specific_version_1 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0",}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0",}

    local pkgs, err = depends.get_depends({'a-1.0'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-1.0", pkgs_fail_msg(pkgs, err))
end

-- a-1.0 available, a-2.0 available, install a<2.0
tests.install_specific_version_2 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0",}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0",}

    local pkgs, err = depends.get_depends({'a<2.0'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-1.0", pkgs_fail_msg(pkgs, err))
end

-- a-1.0 available, a-2.0 available, install a<=2.0
tests.install_specific_version_3 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0",}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0",}

    local pkgs, err = depends.get_depends({'a<=2.0'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-2.0", pkgs_fail_msg(pkgs, err))
end

-- a-1.0 available, a-2.0 available, install a>=3.0
tests.install_specific_version_4 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0",}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0",}

    local pkgs, err = depends.get_depends({'a>=3.0'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("No suitable candidate"), pkgs_fail_msg(pkgs, err))
end

--- install specific version with conflicts

-- b installed, a-1.0 available, a-2.0 available, a-2.5 available, a-2.5 conflicts b, install a>=2.0
tests.install_specific_version_with_conflicts_1 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0",}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0",}
    manifest.a3 = {name="a", arch="Universal", type="all", version="2.5", conflicts={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="1.0",}
    installed.b = manifest.b

    local pkgs, err = depends.get_depends({'a>=2.0'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-2.0" , pkgs_fail_msg(pkgs, err))
end

-- b installed, a-1.0 available, a-2.0 available, a-2.5 available, a-2.5 conflicts b, install a>2.0
tests.install_specific_version_with_conflicts_2 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0",}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0",}
    manifest.a3 = {name="a", arch="Universal", type="all", version="2.5", conflicts={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="1.0",}
    installed.b = manifest.b

    local pkgs, err = depends.get_depends({'a>2.0'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end

--==============================================================
--tests for update functionality
--==============================================================

-- installed a-1.0 b-0.1 c-2.0, a-1.1 a-1.2 available, b-0.2 and 0.3 available, b-0.3 conflicts c, update a + b + c
tests.update_newest_1 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0"}
    manifest.a2 = {name="a", arch="Universal", type="all", version="1.1"}
    manifest.a3 = {name="a", arch="Universal", type="all", version="1.2"}

    manifest.b1 = {name="b", arch="Universal", type="all", version="0.1", depends={"c"}}
    manifest.b2 = {name="b", arch="Universal", type="all", version="0.2", depends={"c"}}
    manifest.b3 = {name="b", arch="Universal", type="all", version="0.3", conflicts={"c"}}

    manifest.c1 = {name="c", arch="Universal", type="all", version="2.0"}
    manifest.c2 = {name="c", arch="Universal", type="all", version="3.0"}

    installed.a = manifest.a1
    installed.b = manifest.b1
    installed.c = manifest.c1

    local pkgs, err = depends.get_depends_1({'a', 'b', 'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-1.2 b-0.2 c-3.0", pkgs_fail_msg(pkgs, err))
end

-- installed a-1.0 b-0.1 c-2.0, a-1.1 a-1.2 available, b-0.2 and 0.3 available, b-0.3 conflicts c, c-3.0 depends d~>1.0, update a + b + c
tests.update_newest_2 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0"}
    manifest.a2 = {name="a", arch="Universal", type="all", version="1.1"}
    manifest.a3 = {name="a", arch="Universal", type="all", version="1.2"}

    manifest.b1 = {name="b", arch="Universal", type="all", version="0.1"}
    manifest.b2 = {name="b", arch="Universal", type="all", version="0.2"}
    manifest.b3 = {name="b", arch="Universal", type="all", version="0.3", conflicts={"c"}}

    manifest.c1 = {name="c", arch="Universal", type="all", version="2.0"}
    manifest.c2 = {name="c", arch="Universal", type="all", version="3.0", depends={"d~>1.0"}}

    manifest.d1 = {name="d", arch="Universal", type="all", version="0.8"}
    manifest.d2 = {name="d", arch="Universal", type="all", version="0.9"}
    manifest.d3 = {name="d", arch="Universal", type="all", version="1.0"}
    manifest.d4 = {name="d", arch="Universal", type="all", version="1.3"}

    installed.a = manifest.a1
    installed.b = manifest.b1
    installed.c = manifest.c1

    local pkgs, err = depends.get_depends_1({'a', 'b', 'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-1.2 b-0.2 d-1.0 c-3.0", pkgs_fail_msg(pkgs, err))
end

-- installed a-1.0, a-1.1 a-1.2 available, a-1.1 depends b, a-1.2 conflicts b, b depends c, update a
tests.depends_u1 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0", depends={"b"}}
    manifest.a2 = {name="a", arch="Universal", type="all", version="1.1", depends={"b"}}
    manifest.a3 = {name="a", arch="Universal", type="all", version="1.2", conflicts={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm",}
    installed.a = manifest.a1
    installed.b = manifest.b
    installed.c = manifest.c

    local pkgs, err = depends.get_depends_1({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-1.1", pkgs_fail_msg(pkgs, err))
end

-- installed a-1.0, a-1.1 a-1.2 available, a-1.1 depends b and c>0.4, a-1.2 conflicts b, b depends c, update a
tests.depends_u2 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0", depends={"b"}}
    manifest.a2 = {name="a", arch="Universal", type="all", version="1.1", depends={"b", "c>0.4"}}
    manifest.a3 = {name="a", arch="Universal", type="all", version="1.2", conflicts={"b"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c1 = {name="c", arch="Universal", type="all", version="0.4",}
    manifest.c2 = {name="c", arch="Universal", type="all", version="0.5",}
    installed.a = manifest.a1

    local pkgs, err = depends.get_depends_1({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "a-1.2", pkgs_fail_msg(pkgs, err))
end

-- installed a-1.0, a-1.1 a-1.2 a-1.3 available, a-1.2 and 1.3 conflicts d, a-1.1 depends b and c>0.4, installed d, update a
tests.depends_u3 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0"}
    manifest.a2 = {name="a", arch="Universal", type="all", version="1.1", depends={"b", "c>0.4"}}
    manifest.a3 = {name="a", arch="Universal", type="all", version="1.2", conflicts={"d"}}
    manifest.a4 = {name="a", arch="Universal", type="all", version="1.3", conflicts={"d"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", depends={"c"}}
    manifest.c1 = {name="c", arch="Universal", type="all", version="0.4"}
    manifest.c2 = {name="c", arch="Universal", type="all", version="0.5"}
    manifest.c3 = {name="c", arch="Universal", type="all", version="0.6"}
    manifest.d = {name="d", arch="Universal", type="all", version="scm",}
    installed.a = manifest.a1
    installed.d = manifest.d

    local pkgs, err = depends.get_depends_1({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "c-0.6 b-scm a-1.1", pkgs_fail_msg(pkgs, err))
end

-- installed a-1.0 c-scm, a-2.0 available, a provides b, b conflicts c, update a
tests.provides_direct_and_conflicts_with_to_update_1 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0"}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0", provides={"b-scm"}}
    manifest.b = {name="b", arch="Universal", type="all", version="scm", conflicts={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="0.1"}
    installed.a = manifest.a1
    installed.c = manifest.c

    local pkgs, err = depends.get_depends_1({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == 'a-2.0', pkgs_fail_msg(pkgs, err))
end

-- installed a-1.0 c-scm, a-2.0 and 2.5 and 3.0 available, a-3.0 conflicts c, a provides b, b conflicts c, update a
tests.provides_direct_and_conflicts_with_to_update_2 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0"}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0", provides={"b-1.0"}}
    manifest.a3 = {name="a", arch="Universal", type="all", version="2.5", provides={"b-scm"}}
    manifest.a4 = {name="a", arch="Universal", type="all", version="3.0", conflicts={"c"}}

    manifest.b1 = {name="b", arch="Universal", type="all", version="1.0", conflicts={"c"}}
    manifest.b2 = {name="b", arch="Universal", type="all", version="1.1", conflicts={"c"}}
    manifest.b3 = {name="b", arch="Universal", type="all", version="1.2"}

    manifest.c = {name="c", arch="Universal", type="all", version="0.1"}
    installed.a = manifest.a1
    installed.c = manifest.c

    local pkgs, err = depends.get_depends_1({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == 'a-2.5', pkgs_fail_msg(pkgs, err))
end

-- installed a-1.2 b-1.0, x-1.2 provided, b-1.0 depends a>=1.2, b-1.1 depends a>=1.3, update b
tests.version_of_provided_update_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="1.2", provides={"x-1.2"}}
    manifest.b1 = {name="b", arch="Universal", type="all", version="1.0", depends={"a>=1.2"}}
    manifest.b2 = {name="b", arch="Universal", type="all", version="1.1", depends={"a>=1.3"}}
    installed.a = manifest.a
    installed.b = manifest.b1

    local pkgs, err = depends.get_depends_1({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs, err))
end

-- installed x-scm b-1.0, a-1.2 provided, a-1.3 also available, b-1.1 depends a>=1.3, update b
tests.version_of_provided_update_2 = function()
    local manifest, installed = {}, {}
    manifest.x = {name="x", arch="Universal", type="all", version="scm", provides={"a-1.2"}}
    manifest.a = {name="a", arch="Universal", type="all", version="1.3",}
    manifest.b1 = {name="b", arch="Universal", type="all", version="1.0"}
    manifest.b2 = {name="b", arch="Universal", type="all", version="1.1", depends={"a>=1.3"}}
    installed.x = manifest.x
    installed.b = manifest.b1

    local pkgs, err = depends.get_depends_1({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("but installed at version"), pkgs_fail_msg(pkgs, err))
end

-- installed x-scm b-1.0, a-1.2 provided, a-1.3 also available, b-1.0.8 depends a-1.2, b-1.1 depends a>=1.3, update b
tests.version_of_provided_update_3 = function()
    local manifest, installed = {}, {}
    manifest.x = {name="x", arch="Universal", type="all", version="scm", provides={"a-1.2"}}
    manifest.a = {name="a", arch="Universal", type="all", version="1.3",}
    manifest.b1 = {name="b", arch="Universal", type="all", version="1.0"}
    manifest.b2 = {name="b", arch="Universal", type="all", version="1.0.8", depends={"a-1.2"}}
    manifest.b3 = {name="b", arch="Universal", type="all", version="1.1", depends={"a>=1.3"}}
    installed.x = manifest.x
    installed.b = manifest.b1

    local pkgs, err = depends.get_depends_1({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == 'b-1.0.8', pkgs_fail_msg(pkgs, err))
end

-- installed a-1.0 b-1.0, b-2.0 depends c>=2.0, c-1.9 and 2.0 and 2.1 depends d~>3.3, d from 3.2 to 3.4 available, update a + b
tests.version_of_depends_update_1 = function()
    local manifest, installed = {}, {}
    manifest.a = {name="a", arch="Universal", type="all", version="1.0", depends={"b<=1.0"}}

    manifest.b1 = {name="b", arch="Universal", type="all", version="1.0"}
    manifest.b2 = {name="b", arch="Universal", type="all", version="2.0", depends={"c>=2.0"}}

    manifest.c1 = {name="c", arch="Universal", type="all", version="1.9", depends={"d~>3.3"}}
    manifest.c2 = {name="c", arch="Universal", type="all", version="2.0", depends={"d~>3.3"}}
    manifest.c3 = {name="c", arch="Universal", type="all", version="2.1", depends={"d~>3.3"}}

    manifest.d1 = {name="d", arch="Universal", type="all", version="3.2",}
    manifest.d2 = {name="d", arch="Universal", type="all", version="3.3",}
    manifest.d3 = {name="d", arch="Universal", type="all", version="3.3.1",}
    manifest.d4 = {name="d", arch="Universal", type="all", version="3.3.2",}
    manifest.d5 = {name="d", arch="Universal", type="all", version="3.4",}

    installed.a = manifest.a
    installed.b = manifest.b1

    local pkgs, err = depends.get_depends_1({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "d-3.3.2 c-2.1 b-2.0", pkgs_fail_msg(pkgs, err))
end

-- installed b-1.0 c-1.0, a-2.0 depends x, c-1.0 depends b>=1.0, c-2.0 depends a>=2.0 and b>=1.0, update c
tests.version_of_depends_update_2 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0"}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0", depends={"x"}}

    manifest.b = {name="b", arch="Universal", type="all", version="1.0"}

    manifest.c1 = {name="c", arch="Universal", type="all", version="1.0", depends={"b>=1.0"}}
    manifest.c2 = {name="c", arch="Universal", type="all", version="2.0", depends={"a>=2.0","b>=1.0"}}

    manifest.x = {name="x", arch="Universal", type="all", version="1.0"}

    installed.b = manifest.b
    installed.c = manifest.c1

    local pkgs, err = depends.get_depends_1({'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "x-1.0 a-2.0 c-2.0", pkgs_fail_msg(pkgs, err))
end

-- installed a-1.0, a-2.0 depends b==1.0, b-1.0 depends c, c depends a>=1.0, update a
tests.depends_circular_update_1 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0"}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0", depends={"b==1.0"}}
    manifest.b = {name="b", arch="Universal", type="all", version="1.0", depends={"c"}}
    manifest.c = {name="c", arch="Universal", type="all", version="scm", depends={"a>=1.0"}}
    installed.a = manifest.a1

    local pkgs, err = depends.get_depends_1({'a'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("circular"), pkgs_fail_msg(pkgs, err))
end

-- installed a-1.0 c-1.0, a-2.0 depends b and c, b-1.0 conflicts c, b-2.0 available, update a + c
tests.conflicts_and_depends_with_to_update_1 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0", depends={"b"}}
    manifest.a2 = {name="a", arch="Universal", type="all", version="2.0", depends={"b", "c"}}
    manifest.b1 = {name="b", arch="Universal", type="all", version="1.0", conflicts={"c"}}
    manifest.b2 = {name="b", arch="Universal", type="all", version="2.0"}
    manifest.c = {name="c", arch="Universal", type="all", version="1.0"}
    installed.a = manifest.a1
    installed.c = manifest.c

    local pkgs, err = depends.get_depends_1({'a', 'c'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-2.0 a-2.0", pkgs_fail_msg(pkgs, err))
end

-- installed x-1.0 b-0.9, a-1.0 provided, b-1.0 depends a==1.0, b-1.1 depends a>1.0, update b
tests.installed_not_in_manifest_update_1 = function()
    local manifest, installed = {}, {}
    manifest.b1 = {name="b", arch="Universal", type="all", version="0.9"}
    manifest.b2 = {name="b", arch="Universal", type="all", version="1.0", depends={"a==1.0"}}
    manifest.b3 = {name="b", arch="Universal", type="all", version="1.1", depends={"a>1.0"}}
    installed.x = {name="x", arch="Universal", type="all", version="1.0", provides={"a-1.0"}}
    installed.b = manifest.b1

    local pkgs, err = depends.get_depends_1({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == "b-1.0", pkgs_fail_msg(pkgs, err))
end

-- installed x-1.0 b-1.0, a-1.0 provided, b-1.1 depends a>1.0, update b
tests.installed_not_in_manifest_update_2 = function()
    local manifest, installed = {}, {}
    manifest.b1 = {name="b", arch="Universal", type="all", version="0.9"}
    manifest.b2 = {name="b", arch="Universal", type="all", version="1.0", depends={"a==1.0"}}
    manifest.b3 = {name="b", arch="Universal", type="all", version="1.1", depends={"a>1.0"}}
    installed.x = {name="x", arch="Universal", type="all", version="1.0", provides={"a-1.0"}}
    installed.b = manifest.b2

    local pkgs, err = depends.get_depends_1({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs, err))
end

-- installed x-1.0 b-1.0, a-1.0 provided, b-1.1 depends a>1.0, update b
tests.installed_not_in_manifest_update_3 = function()
    local manifest, installed = {}, {}
    manifest.b1 = {name="b", arch="Universal", type="all", version="1.0", depends={"a==1.0"}}
    manifest.b2 = {name="b", arch="Universal", type="all", version="1.1", depends={"a>1.0"}}
    manifest.c1 = {name="c", arch="Universal", type="all", version="1.0", depends={"a"}}
    manifest.c2 = {name="c", arch="Universal", type="all", version="1.1", depends={"b"}}
    manifest.c3 = {name="c", arch="Universal", type="all", version="1.2", depends={"b>1.0"}}
    installed.x = {name="x", arch="Universal", type="all", version="1.0", provides={"a-1.0"}}
    installed.b = manifest.b1
    installed.c = manifest.c1

    local pkgs, err = depends.get_depends_1({'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil, pkgs_fail_msg(pkgs, err))
end

-- installed a-1.0 b-1.0, b (all new versions) conflicts a, a (all new versions) conflicts b, update a + b
tests.conflicts_with_to_update_1 = function()
    local manifest, installed = {}, {}
    manifest.a1 = {name="a", arch="Universal", type="all", version="1.0"}
    manifest.a2 = {name="a", arch="Universal", type="all", version="1.1", conflicts={"b"}}
    manifest.a3 = {name="a", arch="Universal", type="all", version="1.2", conflicts={"b"}}
    manifest.b1 = {name="b", arch="Universal", type="all", version="1.0"}
    manifest.b2 = {name="b", arch="Universal", type="all", version="2.0", conflicts={"a"}} 
    manifest.b3 = {name="b", arch="Universal", type="all", version="3.0", conflicts={"a", "x"}}
    installed.a = manifest.a1
    installed.b = manifest.b1

    local pkgs, err = depends.get_depends_1({'a', 'b'}, installed, manifest, true, true)
    assert(describe_packages(pkgs) == nil and err:find("conflicts"), pkgs_fail_msg(pkgs, err))
end

-- actually run the test suite
run_tests(tests)

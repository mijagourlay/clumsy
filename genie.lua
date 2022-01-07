-- genie, https://github.com/bkaradzic/GENie
-- known working version
-- https://github.com/bkaradzic/bx/blob/51f25ba638b9cb35eb2ac078f842a4bed0746d56/tools/bin/windows/genie.exe

MINGW_ACTION = 'gmake'

if _ACTION == 'clean' then
    os.rmdir('./build')
    os.rmdir('./bin')
    os.rmdir('./obj_vs')
    os.rmdir('./obj_' .. MINGW_ACTION)
end

if _ACTION == MINGW_ACTION then
    -- need a msys2 with clang
    premake.gcc.cc   = 'clang'
    premake.gcc.cxx  = 'clang++'
    premake.gcc.ar   = 'llvm-ar'
    premake.llvm = true
end

local LIB_DIVERT_VC11 = 'external/WinDivert-2.2.0-A'
local LIB_DIVERT_MINGW = 'external/WinDivert-2.2.0-A'
local LIB_IUP_WIN32_VC11 = 'external/iup-3.30_Win32_dll16_lib'
local LIB_IUP_WIN64_VC11 = 'external/iup-3.30_Win64_dll16_lib'
local LIB_IUP_WIN32_MINGW = 'external/iup-3.30_Win32_mingw6_lib'
local LIB_IUP_WIN64_MINGW = 'external/iup-3.30_Win64_mingw6_lib'
local LIB_ZMQ = 'external/libzmq'

local ROOT = os.getcwd()
print(ROOT)

solution('clumsy')
    location("./build")
    configurations({'Debug', 'Release'})
    platforms({'x32', 'x64'})

    project('clumsy')
        language("C")
        files({'src/**.c', 'src/**.h'})
        links({'WinDivert', 'iup', 'libzmq-v142-mt-4_3_5', 'comctl32', 'Winmm', 'ws2_32'}) 
        if string.match(_ACTION, '^vs') then -- only vs can include rc file in solution
            files({'./etc/clumsy.rc'})
        elseif _ACTION == MINGW_ACTION then
            files({'./etc/clumsy.rc'})
        end

        configuration('Debug')
			flags({'ExtraWarnings', 'Symbols'})
            defines({'_DEBUG'})
            kind("ConsoleApp")

        configuration('Release')
			flags({"Optimize"})            
			flags({'Symbols'}) -- keep the debug symbols for development
            defines({'NDEBUG'})
            kind("WindowedApp")

        configuration(MINGW_ACTION)
            links({'kernel32', 'gdi32', 'comdlg32', 'uuid', 'ole32'}) -- additional libs
            buildoptions({
                '-Wno-missing-braces',
                '-Wno-missing-field-initializers',
                '--std=c99'
            }) 
            objdir('obj_'..MINGW_ACTION)

        configuration("vs*")
            defines({"_CRT_SECURE_NO_WARNINGS"})
            flags({'NoManifest'})
            kind("WindowedApp") -- We don't need the console window in VS as we use OutputDebugString().
            buildoptions({'/wd"4214"'})
			linkoptions({'/ENTRY:"mainCRTStartup" /SAFESEH:NO'})
			-- characterset("MBCS")
            includedirs({LIB_DIVERT_VC11 .. '/include'})
            includedirs({LIB_ZMQ .. '/include'})
            objdir('obj_vs')

        configuration({'x32', 'vs*'})
            -- defines would be passed to resource compiler for whatever reason
            -- and ONLY can be put here not under 'configuration('x32')' or it won't work
            defines({'X32'})
            includedirs({LIB_IUP_WIN32_VC11 .. '/include'})
            libdirs({
                LIB_DIVERT_VC11 .. '/x86',
                LIB_IUP_WIN32_VC11 .. '',
				LIB_ZMQ .. '/lib'
                })

        configuration({'x64', 'vs*'})
            defines({'X64'})
            includedirs({LIB_IUP_WIN64_VC11 .. '/include'})
            libdirs({
                LIB_DIVERT_VC11 .. '/x64',
                LIB_IUP_WIN64_VC11 .. '',
				LIB_ZMQ .. '/lib'
                })

        configuration({'x32', MINGW_ACTION})
            defines({'X32'}) -- defines would be passed to resource compiler for whatever reason
            includedirs({LIB_DIVERT_MINGW .. '/include',
                LIB_IUP_WIN32_MINGW .. '/include',
				LIB_ZMQ .. '/include'})
            libdirs({
                LIB_DIVERT_MINGW .. '/x86',
                LIB_IUP_WIN32_MINGW .. '',
				LIB_ZMQ .. '/lib'
                })
            resoptions({'-O coff', '-F pe-i386'}) -- mingw64 defaults to x64

        configuration({'x64', MINGW_ACTION})
            defines({'X64'})
            includedirs({LIB_DIVERT_MINGW .. '/include',
                LIB_IUP_WIN64_MINGW .. '/include',
				LIB_ZMQ .. '/include'})
            libdirs({
                LIB_DIVERT_MINGW .. '/x64',
                LIB_IUP_WIN64_MINGW .. '',
				LIB_ZMQ .. '/lib'
                })

        local function set_bin(platform, config, arch)
            local platform_str
            if platform == 'vs*' then
                platform_str = 'vs'
            else
                platform_str = platform
            end
            local subdir = ROOT .. '/bin/' .. platform_str .. '/' .. config .. '/' .. arch
            local divert_lib, iup_lib, zmq_lib
            if platform == 'vs*' then 
                if arch == 'x64' then
                    divert_lib = ROOT .. '/' .. LIB_DIVERT_VC11  .. '/x64/'
                    iup_lib = ROOT .. '/' .. LIB_IUP_WIN64_VC11 .. ''
                    zmq_lib = ROOT .. '/' .. LIB_ZMQ .. '/lib'
                else
                    divert_lib = ROOT ..'/' .. LIB_DIVERT_VC11 .. '/x86/'
                    iup_lib = ROOT ..'/' .. LIB_IUP_WIN32_VC11 .. ''
                    zmq_lib = ROOT .. '/' .. LIB_ZMQ .. '/lib'
                end
            elseif platform == MINGW_ACTION then
                if arch == 'x64' then
                    divert_lib = ROOT .. '/' .. LIB_DIVERT_MINGW .. '/x64/'
                    iup_lib = ROOT .. '/' .. LIB_IUP_WIN64_MINGW .. ''
                    zmq_lib = ROOT .. '/' .. LIB_ZMQ .. '/lib'
                else
                    divert_lib = ROOT .. '/' .. LIB_DIVERT_MINGW .. '/x86/'
                    iup_lib = ROOT .. '/' .. LIB_IUP_WIN32_MINGW .. ''
                    zmq_lib = ROOT .. '/' .. LIB_ZMQ .. '/lib'
                end
            end
            configuration({platform, config, arch})
                targetdir(subdir)
                debugdir(subdir)
                if platform == 'vs*' then
                    postbuildcommands({
                        "robocopy " .. divert_lib .." " .. subdir .. '  *.dll *.sys >> robolog.txt',
                        "robocopy " .. iup_lib .. " "  .. subdir .. ' iup.dll >> robolog.txt',
                        "robocopy " .. zmq_lib .. " "  .. subdir .. ' libzmq-*.dll >> robolog.txt',
                        "robocopy " .. ROOT .. "/etc/ "   .. subdir .. ' config.txt >> robolog.txt',
                        "exit /B 0"
                    })
                elseif platform == MINGW_ACTION then 
                    postbuildcommands({
                        -- robocopy returns non 0 will fail make
                        'cp ' .. divert_lib .. "WinDivert* " .. subdir,
                        'cp ' .. zmq_lib .. "/libzmq* " .. subdir,
                        'cp ' .. ROOT .. "/etc/config.txt " .. subdir,
                    })
                end
        end

        set_bin('vs*', 'Debug', "x32")
        set_bin('vs*', 'Debug', "x64")
        set_bin('vs*', 'Release', "x32")
        set_bin('vs*', 'Release', "x64")
        set_bin(MINGW_ACTION, 'Debug', "x32")
        set_bin(MINGW_ACTION, 'Debug', "x64")
        set_bin(MINGW_ACTION, 'Release', "x32")
        set_bin(MINGW_ACTION, 'Release', "x64")


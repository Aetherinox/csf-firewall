:: # #
:: #   @app                        ConfigServer Firewall (csf)
:: #   @author                     Copyright (C) 2025 Aetherinox
:: #   @license                    GPLv3
:: #   @repo_primary               https://github.com/Aetherinox/csf-firewall
:: #   @repo_legacy                https://github.com/waytotheweb/scripts
:: #   @updates                    09.10.25
:: #   
:: #   This program is free software; you can redistribute it and/or modify it under
:: #   the terms of the GNU General Public License as published by the Free Software
:: #   Foundation; either version 3 of the License, or (at your option) any later
:: #   version.
:: #   
:: #   This program is distributed in the hope that it will be useful, but WITHOUT
:: #   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
:: #   FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
:: #   details.
:: #   
:: #   You should have received a copy of the GNU General Public License along with
:: #   this program; if not, see <https://www.gnu.org/licenses>.
:: # #

@cd 	    /d "%~dp0"
@echo 	    OFF
title       Mkdocs Startup
setlocal 	enableextensions enabledelayedexpansion
mode        con:cols=125 lines=120
mode        125,40
GOTO        comment_end

    @usage              Starts up mkdocs from a windows system.
                        Ensure you have defined `GH_TOKEN` or the git-committers plugin will rate limit you.

                            setx /m GH_TOKEN "github_pat_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

                        If using a Github Workflow, create a new secret in the repo settings named `GH_TOKEN`
                        and give it your Github fine-grained personal access token.

                        The token variable is defined in mkdocs.yml

                        Must be ran in the folder where the mkdocs source files are
                        Example run folders:
                            - H:\Repos\github\aetherinox\proteus-apt-repo\docs

                        Once mkdocs server is up and running, open browser and go to
                            - http://127.0.0.1:8000/

    @update             use the following commands to update mkdocs and the mkdocs-material theme:
                            pip install --upgrade mkdocs
                            pip install --upgrade --force-reinstall mkdocs-material

    @error              if mkdocs will not re-build, downgrade click
                            pip install --force-reinstall click==8.2.1

:comment_end

echo.

:: #
::  @define         directories
:: #

set dir_home=%~dp0

:: #
::  @define         env variable
:: #

echo  ------------------------------------------------------------------------------------------------
echo    Mkdocs Launcher
echo  ------------------------------------------------------------------------------------------------

IF "!GH_TOKEN!"=="" (
    echo    GH_TOKEN not defined.
    echo        Open %0%
    echo    Create a new one at:
    echo        https://github.com/settings/personal-access-tokens
    echo  ------------------------------------------------------------------------------------------------
    set /p TOKEN=" Enter Github Personal Access Token (fine-grained): "
)

echo    GH_TOKEN: !GH_TOKEN!
echo.
echo.

echo Creating environment variable GH_TOKEN
setx GH_TOKEN "!GH_TOKEN!"

timeout 2 > NUL

:: #
::  start mkdocs
:: #

echo Starting mkdocs ...
start cmd /k "mkdocs serve --clean"

timeout 5 > NUL

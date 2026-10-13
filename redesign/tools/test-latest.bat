@echo off
setlocal EnableExtensions
rem Test VLC Redesign: downloads the newest successful build of the redesign branch from
rem GitHub Actions and starts it in portable mode (its own settings, never the installed VLC's).
rem Builds are kept in "<TEST_MEDIA_DIR>\builds\<run number>"; a run that is
rem already there is not downloaded again, and its settings stay between runs.
title Test VLC Redesign

set "REPO=Pyr0zen/vlc"
set "BRANCH=redesign"
set "ARTIFACT=vlc-redesign-win64"
set "BUILDS=<TEST_MEDIA_DIR>\builds"

where gh >nul 2>nul
if errorlevel 1 (
    echo The GitHub command line tool "gh" was not found.
    echo Install it from https://cli.github.com and run "gh auth login" once.
    goto :fail
)

gh auth status >nul 2>nul
if errorlevel 1 (
    echo You are not logged in to GitHub in the command line tool.
    echo Open a terminal, run:  gh auth login   and then start this again.
    goto :fail
)

echo Looking for the newest successful build of the %BRANCH% branch...
set "RUN="
for /f "usebackq delims=" %%i in (`gh run list -R %REPO% -b %BRANCH% -w build-windows -s success -L 1 --json databaseId --jq ".[0].databaseId"`) do set "RUN=%%i"
if not defined RUN (
    echo No finished successful build was found yet.
    echo A build takes about 50 minutes after a push; try again later.
    echo Builds: https://github.com/%REPO%/actions
    goto :fail
)
echo Newest successful build: run %RUN%

set "DEST=%BUILDS%\%RUN%"
set "VLCDIR=%DEST%\vlc-4.0.0-dev"

if exist "%VLCDIR%\vlc.exe" (
    echo This build is already downloaded.
) else (
    echo Downloading build %RUN% ^(about 90 MB, a few minutes^)...
    if not exist "%DEST%" mkdir "%DEST%"
    gh run download %RUN% -R %REPO% -n %ARTIFACT% -D "%DEST%"
    if errorlevel 1 (
        echo The download failed. The build may be too old ^(builds are kept 14 days^)
        echo or the network is down. Details are above.
        goto :fail
    )
    if not exist "%VLCDIR%\vlc.exe" (
        echo The download finished but vlc.exe was not found in "%VLCDIR%".
        goto :fail
    )
)

rem portable mode: a "portable" folder next to vlc.exe keeps vlcrc, the interface settings and
rem the media library inside this build folder
if not exist "%VLCDIR%\portable" mkdir "%VLCDIR%\portable"

echo Starting VLC Redesign build %RUN%...
start "" /D "%VLCDIR%" "%VLCDIR%\vlc.exe" --no-qt-privacy-ask --no-qt-updates-notif
exit /b 0

:fail
echo.
pause
exit /b 1

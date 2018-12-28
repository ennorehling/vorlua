@ECHO OFF

REM vorlua.exe filter.lua test.cr filter.cr

REM IF NOT EXIST merge.cr GOTO NODEL
REM DEL /S merge.cr
REM :NODEL
REM vorlua.exe merge.lua merge.cr ufo 1 1

vorlua.exe merge.lua ufo.cr ufo 992
copy ufo.cr enno.cr
vorlua.exe merge.lua enno.cr enno 1101

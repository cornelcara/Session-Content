@echo off
if "%1"=="" goto msg
wmic cpu get %1 /format:textvaluelist.xsl | findstr "="
 goto end
:msg
 echo you must specify at least
    one computer name.
:end

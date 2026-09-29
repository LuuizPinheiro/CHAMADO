@echo off
:: =====================================================================
:: CHAMADO - Central de Suporte Tecnico
:: Desenvolvido por Pinea Code
:: Inicializador BAT com elevacao de privilegios (Admin)
:: =====================================================================

title CHAMADO - Central de Suporte Tecnico

:: Verifica se esta executando como Administrador
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo =======================================================
    echo  Solicitando privilegios de Administrador...
    echo  O CHAMADO precisa de acesso avancado para rodar reparos.
    echo =======================================================
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    set params= %*
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0"" %params%", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"

:: Configura o terminal para UTF-8
chcp 65001 >nul 2>&1

:: Configura tamanho da janela
mode con: cols=100 lines=40

:: Executa o script PowerShell principal
PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CHAMADO.ps1"

:: Pausa final caso o script termine
pause

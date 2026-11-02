@echo off
echo ========================================================
echo  Starting PetCare & Services Marketplace - Spring Boot Backend
echo ========================================================
echo.
cd /d "%~dp0backend"
if exist "C:\Program Files\Java\jdk-25" (
    set "JAVA_HOME=C:\Program Files\Java\jdk-25"
    set "PATH=C:\Program Files\Java\jdk-25\bin;%PATH%"
)
mvn spring-boot:run
pause

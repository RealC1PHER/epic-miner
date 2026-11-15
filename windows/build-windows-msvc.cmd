@echo off
rem Native Windows x86-64 build of epic-miner with the MSVC toolchain (x86_64-pc-windows-msvc).
rem
rem Use this one, not build-windows.sh: the MinGW cross-build (fz4) crashed in the RandomX JIT on
rem the first job. The upstream 2.3.1-1 Windows exe is an MSVC build as well.
rem
rem Needs: Visual Studio (or Build Tools) with the C++ x64 tools and a Windows SDK, CMake,
rem        rustup with the stable-x86_64-pc-windows-msvc toolchain, LLVM (libclang for bindgen),
rem        Strawberry Perl (the vendored OpenSSL build cannot use Git's MSYS perl).
rem
rem Usage (from the repo root):  windows\build-windows-msvc.cmd
rem Output: target\release\epic-miner.exe, then windows\package-windows.ps1 makes the zip.
setlocal

rem Visual Studio 2022 (17.x): the 2019-era cmake crate (0.1.42) rejects VS 2026 ("version 18.0").
for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -version [17.0^,18.0^) -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSDIR=%%i"
if not defined VSDIR (echo Visual Studio C++ tools not found & exit /b 1)
call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1

rem Strawberry Perl first, so OpenSSL's Configure never picks up Git's perl.
set "PATH=C:\Strawberry\perl\bin;C:\Strawberry\c\bin;%USERPROFILE%\.cargo\bin;%PATH%"
if not defined LIBCLANG_PATH set "LIBCLANG_PATH=C:\Program Files\LLVM\bin"
rem 2019-era crates deny lints that newer rustc trips over (same as hiveos/build-linux.sh).
set "RUSTFLAGS=%RUSTFLAGS% --cap-lints warn"
rem The old `built` crate pastes the rustc/rustdoc path into Rust source unescaped; a full Windows
rem path ("C:\Users\...") breaks the build, so name them through PATH instead.
set "RUSTC=rustc"
set "RUSTDOC=rustdoc"

cd /d "%~dp0.."
cargo build --release --target x86_64-pc-windows-msvc --bin epic-miner || exit /b 1
echo == built target\x86_64-pc-windows-msvc\release\epic-miner.exe

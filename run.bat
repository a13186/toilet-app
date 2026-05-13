@echo off

set SUPABASE_URL=https://srdkxmiakrpxggumguzc.supabase.co
set SUPABASE_ANON_KEY=sb_publishable_wzt_skaBck9370ifCl5ceQ__y5SdWWF

if "%1"=="web" (
  flutter run -d chrome --web-port 8080 ^
    --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
    --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%
) else (
  flutter run -d windows ^
    --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
    --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%
)

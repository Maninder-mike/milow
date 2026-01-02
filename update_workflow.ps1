$path = ".github\workflows\android_play_store.yml"
$content = Get-Content $path -Raw
$find = "      # Run tests (optional, can be disabled)"
$replace = @"
      # Build signed APK
      - name: Build signed APK
        run: |
          echo "🏗️ Building signed APK..."
          cd apps/driver
          flutter build apk --release

      # Run tests (optional, can be disabled)
"@
$content = $content.Replace($find, $replace)
Set-Content $path $content -NoNewline
Write-Host "File updated successfully"

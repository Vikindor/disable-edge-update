# Disable Microsoft Edge auto-updates

**Description:** Scripts to disable (or restore) Microsoft Edge auto-updates, including WebView2 runtime.

This toolkit provides two portable scripts for managing Microsoft Edge auto-update services, scheduled tasks, and folders — **disable** (to block automatic updates) and **restore** (to re-enable them if needed). Designed for setups where Edge isn’t used but the WebView2 runtime is required by other apps, or where full control over Edge updates is desired.

---

**Requirements:** Windows 10/11, PowerShell 5.1+ или PowerShell 7+, Admin rights.

---

## Files

| File | Description |
|------|-------------|
| `disable_edgeupdate.ps1` | Disables Edge update services, terminates updater process, deletes scheduled tasks (GUID-safe), sets update policies, and blocks update folders via ACLs. |
| `RUN_disable_edgeupdate.bat` | Portable batch wrapper that auto-elevates and runs the PowerShell script (prefers PowerShell 7 `pwsh`, falls back to Windows PowerShell). |
| `restore_edgeupdate.ps1` | Removes folder ACL restrictions, clears policies, sets services to Manual, and starts them back. |
| `RUN_restore_edgeupdate.bat` | Portable batch wrapper for the restore script (auto-elevates, picks `pwsh`/`powershell`). |

> Place all files in the same folder. The `.bat` wrappers run the corresponding `.ps1` from that folder, so you can move the folder anywhere.

---

## Usage

### 1) Disable auto-updates
Run:
```bat
RUN_disable_edgeupdate.bat
```
The script will:
- Stop and disable `edgeupdate` and `edgeupdatem` services.
- Terminate `MicrosoftEdgeUpdate.exe` if present.
- Remove scheduled tasks whose names start with `MicrosoftEdgeUpdateTask` (handles GUID suffixes).
- Create update-blocking policies.
- Remove and recreate `EdgeUpdate` folders with ACLs that deny write/execute for Everyone (admins keep full control).

### 2) Restore auto-updates
Run:
```bat
RUN_restore_edgeupdate.bat
```
The script will:
- Remove ACL restrictions from the `EdgeUpdate` folders.
- Delete update-blocking policies.
- Set `edgeupdate` and `edgeupdatem` services to **Manual** and start them.
- (Scheduled tasks will be recreated by Edge/WebView2 during the next update or by the Evergreen installer.)

---

## Notes

- **32‑bit PowerShell warning:** Running a 32‑bit PowerShell on a 64‑bit OS can break registry/service access. Prefer a 64‑bit host (PowerShell 7 x64 `pwsh` or Windows PowerShell x64).
- **Manual updates:** After disabling, you can still update WebView2 manually using Microsoft’s **Evergreen Standalone Installer**: <https://developer.microsoft.com/en-us/microsoft-edge/webview2/#download-section>
- **Scope:** Edge browser and WebView2 share the same updater infrastructure (`edgeupdate`/`edgeupdatem` + scheduled tasks). Disabling affects **both**.
- **Portability:** The wrappers resolve the `.ps1` next to the `.bat`, so the folder can be moved without breaking paths.
- **Logging:** Scripts print `OK`, `SKIP/INFO`, or `ERROR` for each step; failures won’t silently pass.

---

## Troubleshooting

**Q:** I see `SKIP/INFO: stop edgeupdate (Cannot find any service with service name 'edgeupdate'.)`  
**A:** The service is missing (already removed or never installed). Informational only.

**Q:** `ERROR: Access is denied` while changing services or registry.  
**A:** Not elevated. Run via the `.bat` wrappers — they request admin rights automatically.

**Q:** After disabling, a WebView2-based app won’t start.  
**A:** Some apps rely on the updater during component installation. Run `RUN_restore_edgeupdate.bat`, install/update WebView2 (Evergreen), then disable again if desired.

**Q:** Tasks reappear in Task Scheduler later.  
**A:** Edge/WebView2 may recreate them when a WebView2 app launches. Re-run the disable script; folder ACLs help prevent persistence.

---

## License

MIT (or your preferred license).

#!/bin/bash
TARGET="$1"
shift

if [ -z "$TARGET" ] || [ $# -eq 0 ]; then
    notify-send "LocalSend" "Usage: localsend_send.sh <ip> <file1>..." -i dialog-error; exit 1
fi

PORT=53317
FINGERPRINT_FILE="$HOME/.cache/qs_localsend_fp"
[ -f "$FINGERPRINT_FILE" ] || openssl rand -hex 16 > "$FINGERPRINT_FILE"
FINGERPRINT=$(cat "$FINGERPRINT_FILE")

# Generate JSON payload for all files using Python
PAYLOAD=$(python3 - "$FINGERPRINT" "$@" << 'EOF'
import json, sys, os, uuid, mimetypes
fp = sys.argv[1]
files_args = sys.argv[2:]

files_map = {}
for f in files_args:
    if os.path.isfile(f):
        fid = f"qs_{uuid.uuid4().hex[:8]}"
        files_map[fid] = {
            "path": f,
            "meta": {
                "id": fid,
                "fileName": os.path.basename(f),
                "size": os.path.getsize(f),
                "fileType": mimetypes.guess_type(f)[0] or "application/octet-stream",
                "sha256": None, "preview": None, "metadata": None
            }
        }

payload = {
    "info": {"alias": "QuickShell Stash", "version": "2.1", "deviceModel": None, "deviceType": "headless", "fingerprint": fp, "port": 53317, "protocol": "https", "download": False},
    "files": {k: v["meta"] for k, v in files_map.items()}
}
print(json.dumps({"payload": payload, "map": files_map}))
EOF
)

JSON_PAYLOAD=$(echo "$PAYLOAD" | python3 -c "import sys,json; print(json.dumps(json.loads(sys.stdin.read())['payload']))")

RESP=$(curl -sk --max-time 30 -X POST "https://$TARGET:$PORT/api/localsend/v2/prepare-upload" -H "Content-Type: application/json" -d "$JSON_PAYLOAD")

SESSION=$(echo "$RESP" | python3 -c "import sys,json; raw=sys.stdin.read().strip(); d=json.loads(raw) if raw else {}; print(d.get('sessionId',''))" 2>/dev/null)

if [ -z "$SESSION" ]; then
    echo "REJECTED"
    notify-send "LocalSend" "Rejected or timed out" -i dialog-error
    exit 1
fi

# Now upload each file using python http.client for progress reporting
python3 - "$PAYLOAD" "$RESP" "$TARGET" "$SESSION" << 'EOF'
import sys, json, os, subprocess
import http.client
import ssl

try:
    payload_data = json.loads(sys.argv[1])
    resp_data = json.loads(sys.argv[2])
    target = sys.argv[3]
    session = sys.argv[4]
    
    files_map = payload_data["map"]
    accepted_files = resp_data.get("files", {})
    
    success_count = 0
    fail_count = 0
    
    total_size = 0
    accepted_fids = []
    for fid, token in accepted_files.items():
        if token and fid in files_map:
            total_size += files_map[fid]["meta"]["size"]
            accepted_fids.append((fid, token))
            
    if not accepted_fids:
        print("REJECTED", flush=True)
        sys.exit(1)

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    uploaded_total = 0

    for fid, token in accepted_fids:
        f_info = files_map[fid]
        path = f_info["path"]
        mime = f_info["meta"]["fileType"]
        f_size = f_info["meta"]["size"]
        
        try:
            conn = http.client.HTTPSConnection(target, 53317, context=ctx, timeout=30)
            conn.putrequest("POST", f"/api/localsend/v2/upload?sessionId={session}&fileId={fid}&token={token}")
            conn.putheader("Content-Type", mime)
            conn.putheader("Content-Length", str(f_size))
            conn.endheaders()
            
            with open(path, "rb") as f:
                while True:
                    chunk = f.read(262144) # 256KB chunks
                    if not chunk: break
                    conn.send(chunk)
                    uploaded_total += len(chunk)
                    if total_size > 0:
                        prog = (uploaded_total / total_size) * 100
                        print(f"PROGRESS:{prog:.2f}", flush=True)
            
            resp = conn.getresponse()
            if resp.status == 200:
                success_count += 1
            else:
                fail_count += 1
        except Exception as e:
            print("CANCELLED", flush=True)
            fail_count += 1
            break

    total = len(accepted_fids)
    if total == 1:
        fname = os.path.basename(files_map[accepted_fids[0][0]]["path"])
        if success_count == 1:
            os.system(f'notify-send "LocalSend" "Sent: {fname}" -i emblem-ok-symbolic')
        else:
            os.system(f'notify-send "LocalSend" "Failed to send: {fname}" -i dialog-error')
            sys.exit(1)
    elif total > 1:
        if fail_count == 0:
            os.system(f'notify-send "LocalSend" "Sent {success_count} files" -i emblem-ok-symbolic')
        else:
            os.system(f'notify-send "LocalSend" "Sent {success_count} files ({fail_count} failed)" -i dialog-error')
            sys.exit(1)

except Exception as e:
    print("CANCELLED", flush=True)
    os.system('notify-send "LocalSend" "Upload error" -i dialog-error')
    sys.exit(1)
EOF

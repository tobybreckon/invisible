#!/usr/bin/env bash
set -u

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <accounts_file> <command>"
  echo "Example: $0 accounts.txt 'whoami && id'"
  exit 1
fi

ACCOUNTS_FILE="$1"
shift
RUN_CMD="$*"

if ! command -v expect >/dev/null 2>&1; then
  echo "Error: expect is required."
  exit 1
fi

while IFS=':' read -r USERNAME PASSWORD; do
  [[ -z "${USERNAME:-}" ]] && continue
  [[ "$USERNAME" =~ ^# ]] && continue

  echo "===== Running as $USERNAME ====="

  expect <<EOF
set timeout 30

spawn su - "$USERNAME" -c "$RUN_CMD"

expect {
    -nocase "password:" {
        send -- "$PASSWORD\r"
        exp_continue
    }

    -nocase "authentication failure" {
        exit 3
    }

    -nocase "su: sorry" {
        exit 4
    }

    timeout {
        puts "Timed out waiting for su"
        exit 124
    }

    eof {
        catch wait result
        set exit_code [lindex \$result 3]
        exit \$exit_code
    }
}
EOF

  RC=$?

  if [[ $RC -eq 0 ]]; then
    echo "Success for $USERNAME"
  else
    echo "Failed for $USERNAME, exit code: $RC"
  fi

  echo

done < "$ACCOUNTS_FILE"
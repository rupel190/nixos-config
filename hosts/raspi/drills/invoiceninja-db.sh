#!/usr/bin/env bash
# Restore drill, part 1 (data): last night's InvoiceNinja dump, as pulled to amanita, into a throwaway
# MySQL 8.4.5 (same digest as the Pi) with no network, then the same questions to it and to the live
# database on the Pi. Prints counts, the newest invoice, sums and table checksums; never a password.
set -euo pipefail
dump=$(ls -t /mnt/backup/current/invoiceninja_rpi/invoiceninja/db-*.sql.gz | head -1)
name=drill-ninja-mysql
image=mysql@sha256:32cdfd01c2996419a2ff4ced7234c06af60a63e714e182e3cc5966182b67034c
echo "dump: $(basename "$dump") ($(du -h "$dump" | cut -f1))"

docker rm -f "$name" >/dev/null 2>&1 || true
pw=$(openssl rand -hex 16)
docker run -d --name "$name" --network none -e MYSQL_ROOT_PASSWORD="$pw" -e MYSQL_DATABASE=ninja "$image" >/dev/null
for _ in $(seq 1 90); do
  docker exec -e MYSQL_PWD="$pw" "$name" mysql -uroot -e 'select 1' ninja >/dev/null 2>&1 && break
  sleep 2
done
echo "drill mysql: $(docker exec "$name" mysql --version | grep -o 'Ver [0-9.]*')"
gunzip -c "$dump" | docker exec -i -e MYSQL_PWD="$pw" "$name" mysql -uroot ninja
echo "import: done"

queries=$(cat <<'SQL'
SELECT 'clients', COUNT(*) FROM clients
UNION ALL SELECT 'invoices', COUNT(*) FROM invoices
UNION ALL SELECT 'invoices not deleted', COUNT(*) FROM invoices WHERE is_deleted = 0
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'recurring invoices', COUNT(*) FROM recurring_invoices
UNION ALL SELECT 'quotes', COUNT(*) FROM quotes
UNION ALL SELECT 'credits', COUNT(*) FROM credits
UNION ALL SELECT 'expenses', COUNT(*) FROM expenses
UNION ALL SELECT 'documents', COUNT(*) FROM documents
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'tables', COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE()
UNION ALL SELECT 'newest invoice', CONCAT(number, ' · ', date, ' · ', amount) FROM (SELECT number, date, amount FROM invoices WHERE is_deleted = 0 ORDER BY id DESC LIMIT 1) n
UNION ALL SELECT 'sum of invoice amounts', SUM(amount) FROM invoices WHERE is_deleted = 0
UNION ALL SELECT 'sum of payments', SUM(amount) FROM payments WHERE is_deleted = 0
UNION ALL SELECT 'invoices last changed', MAX(updated_at) FROM invoices;
CHECKSUM TABLE clients, invoices, invoice_items, payments, paymentables, recurring_invoices, documents;
SQL
)
S=$(mktemp -d)
trap 'rm -rf "$S"' EXIT
docker exec -i -e MYSQL_PWD="$pw" "$name" mysql -uroot -N ninja <<<"$queries" | sed -E 's/^[a-z_]+\./checksum /' > "$S/drill-restored.tsv"
ssh raspi "docker exec -i invoiceninja_mysql_1 sh -c 'MYSQL_PWD=\"\$MYSQL_PASSWORD\" mysql -u\"\$MYSQL_USER\" -N \"\$MYSQL_DATABASE\"'" <<<"$queries" | sed -E 's/^[a-z_]+\./checksum /' > "$S/drill-live.tsv"
printf '%-30s %-38s %-38s\n' "" "restored on amanita" "live on the Pi"
paste "$S/drill-restored.tsv" "$S/drill-live.tsv" | awk -F'\t' '{ printf "%-30s %-38s %-38s %s\n", $1, $2, $4, ($1 == $3 && $2 == $4) ? "=" : "≠" }'
rm -f "$S/drill-restored.tsv" "$S/drill-live.tsv"
docker rm -f "$name" >/dev/null
echo "drill container removed"

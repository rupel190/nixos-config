{ pkgs, lib, ... }:
let
  apps = "/mnt/usbhdd/apps";
  images = "/mnt/usbhdd/images";
  backups = "/mnt/usbhdd/backups";

  # Each app keeps the docker-compose.yml and .env it had on Debian, in its folder on the USB disk.
  # `--pull never`: only the images loaded from /mnt/usbhdd/images run, so nothing upgrades by accident.
  app = name: extra: {
    description = "${name}, from ${apps}/${name}/docker-compose.yml";
    after = [ "docker-images.service" ];
    requires = [ "docker-images.service" ];
    unitConfig.RequiresMountsFor = "${apps}/${name}";
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.docker
      pkgs.gnugrep
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "${apps}/${name}";
      TimeoutStartSec = "10min";
    };
    script = "docker compose ${extra} up -d --pull never --remove-orphans";
    preStop = "docker compose stop";
  };

  # cron replacements: the backup scripts that live next to their apps, run as before
  timer = when: { timerConfig = { OnCalendar = when; Persistent = true; }; wantedBy = [ "timers.target" ]; };
  backupPath = with pkgs; [ bash docker coreutils findutils gnutar gzip gnugrep gnused gawk ];

  # was /usr/local/bin/invoiceninja-backup.sh on Debian; asks MySQL by its compose service name,
  # since compose v2 names the containers invoiceninja-mysql-1 where v1 said invoiceninja_mysql_1
  invoiceninjaBackup = pkgs.writeShellApplication {
    name = "invoiceninja-backup";
    runtimeInputs = backupPath;
    text = ''
      app=${apps}/invoiceninja
      dir=${backups}/invoiceninja
      date=$(date +%Y%m%d-%H%M%S)
      mkdir -p "$dir"
      cd "$app"
      echo "=== InvoiceNinja backup $date"
      if ! docker compose exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" exec mysqldump -u"$MYSQL_USER" "$MYSQL_DATABASE" --single-transaction --quick --lock-tables=false --no-tablespaces' \
        | gzip >"$dir/db-$date.sql.gz"; then
        rm -f "$dir/db-$date.sql.gz"
        echo "ERROR: mysqldump failed, no DB dump written"
        exit 1
      fi
      tar -czf "$dir/files-$date.tar.gz" -C "$app/volumes" storage public
      printf 'Backup Date: %s\nDatabase Size: %s\nFiles Size: %s\n' "$(date)" \
        "$(du -h "$dir/db-$date.sql.gz" | cut -f1)" "$(du -h "$dir/files-$date.tar.gz" | cut -f1)" >"$dir/manifest-$date.txt"

      # tiers by the date in the file name: every daily for 14 days, Sundays for 60, the 1st of each month for a year
      now=$(date +%s)
      for f in "$dir"/*-????????-??????.*; do
        [ -e "$f" ] || continue
        d=$(basename "$f" | grep -oE '[0-9]{8}' | head -1)
        age=$(( (now - $(date -d "$d" +%s)) / 86400 ))
        if [ "$age" -le 14 ]; then continue; fi
        if [ "$age" -le 60 ] && [ "$(date -d "$d" +%u)" = 7 ]; then continue; fi
        if [ "$age" -le 365 ] && [ "$(date -d "$d" +%d)" = 01 ]; then continue; fi
        rm -f "$f"
      done
      echo "=== done: $(find "$dir" -name 'db-*.sql.gz' | wc -l) dumps, $(du -sh "$dir" | cut -f1)"
    '';
  };

  # was /usr/local/bin/config-backup.sh: each app's compose, .env and conf, now also SplitPro's and
  # Paperless' (Debian's never saved those); the system itself lives in this repo
  configBackup = pkgs.writeShellApplication {
    name = "config-backup";
    runtimeInputs = backupPath;
    text = ''
      dir=${backups}/configs
      date=$(date +%Y%m%d-%H%M%S)
      mkdir -p "$dir"
      save() { # app, files...
        local a=$1; shift
        tar -czf "$dir/$a-config-$date.tar.gz" -C "${apps}/$a" "$@"
        echo "$a: $(du -h "$dir/$a-config-$date.tar.gz" | cut -f1)"
      }
      save invoiceninja docker-compose.yml .env nginx php scripts supervisor Dockerfile
      save pihole docker-compose.yml .env update.fish
      save splitpro docker-compose.yml .env backup.sh
      save paperless docker-compose.yml .env gpt.env backup.sh
    '';
  };
in
{
  # The apps' images, saved from Debian by digest: loaded once, so compose finds them and never pulls
  systemd.services.docker-images = {
    description = "Load the saved app images that are not loaded yet";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    unitConfig.RequiresMountsFor = images;
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "30min";
    };
    # manifest.txt: "<image:tag>  id=...  digest  size", one line per tarball named after the tag
    script = ''
      while read -r ref _; do
        if docker image inspect "$ref" >/dev/null 2>&1; then continue; fi
        echo "loading $ref"
        docker load -i "${images}/$(echo "$ref" | tr '/:' '__').tar"
      done <${images}/manifest.txt
    '';
  };

  systemd.services = {
    pihole = app "pihole" "";
    invoiceninja = app "invoiceninja" "";
    splitpro = app "splitpro" "";
    # paperless-gpt (profile gpt) only once gpt.env holds its token; without one it would restart forever
    paperless = app "paperless" "$(grep -q '^PAPERLESS_API_TOKEN=.' gpt.env && echo --profile gpt)";

    invoiceninja-backup = {
      description = "Nightly InvoiceNinja dump and files into ${backups}/invoiceninja";
      serviceConfig.ExecStart = lib.getExe invoiceninjaBackup;
      unitConfig.RequiresMountsFor = backups;
    };
    config-backup = {
      description = "Weekly copy of every app's compose, .env and conf into ${backups}/configs";
      serviceConfig.ExecStart = lib.getExe configBackup;
      unitConfig.RequiresMountsFor = backups;
    };
    splitpro-backup = {
      description = "Nightly SplitPro dump (${apps}/splitpro/backup.sh)";
      path = backupPath;
      serviceConfig = {
        User = "rupel";
        ExecStart = "${pkgs.bash}/bin/bash ${apps}/splitpro/backup.sh";
      };
      unitConfig.RequiresMountsFor = backups;
    };
    paperless-backup = {
      description = "Nightly Paperless export (${apps}/paperless/backup.sh)";
      path = backupPath;
      serviceConfig = {
        User = "rupel";
        ExecStart = "${pkgs.bash}/bin/bash ${apps}/paperless/backup.sh";
      };
      unitConfig.RequiresMountsFor = backups;
    };
  };

  # same times as the crontabs on Debian; amanita pulls at 03:45
  systemd.timers = {
    invoiceninja-backup = timer "*-*-* 02:00:00";
    splitpro-backup = timer "*-*-* 02:15:00";
    paperless-backup = timer "*-*-* 02:30:00";
    config-backup = timer "Sun *-*-* 03:00:00";
  };
}

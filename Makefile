EXTRACTDIR=-D lib -D themes/default/templates
POT=themes/default/lib/Lutim/I18N/lutim.pot
XGETTEXT=carton exec local/bin/xgettext.pl -u
CARTON=carton exec
LUTIM=script/lutim
REAL_LUTIM=script/application

locales:
	$(XGETTEXT) $(EXTRACTDIR) -o $(POT) 2>/dev/null

push-locales: locales
	zanata-cli -q -B push

pull-locales:
	zanata-cli -q -B pull

stats-locales:
	zanata-cli -q stats

podcheck:
	podchecker lib/Lutim/DB/Image.pm

test-sqlite:
	$(CARTON) $(REAL_LUTIM) test

test-pg:
	$(CARTON) $(REAL_LUTIM) test

test: podcheck test-sqlite test-pg

clean:
	rm -rf lutim.db files/

dev:
	$(CARTON) morbo $(LUTIM) --listen http://0.0.0.0:3000 --watch lib/ --watch script/ --watch themes/ --watch lutim.conf

devlog:
	multitail log/development.log

prod:
	$(CARTON) hypnotoad -f $(LUTIM)

prodlog:
	multitail log/production.log

minion:
	$(CARTON) $(REAL_LUTIM) minion worker

create-pg-test-db:
	 sudo -u postgres psql -f t/create-pg-testdb.sql

stats:
	$(CARTON) $(LUTIM) cron stats -m production

watch:
	$(CARTON) $(LUTIM) cron watch -m production

cleanfiles:
	$(CARTON) $(LUTIM) cron cleanfiles -m production

cleanbdd:
	$(CARTON) $(LUTIM) cron cleanbdd -m production

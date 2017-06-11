EXTRACTDIR=-D lib -D themes/default/templates
EN=themes/default/lib/Lutim/I18N/en.po
FR=themes/default/lib/Lutim/I18N/fr.po
DE=themes/default/lib/Lutim/I18N/de.po
ES=themes/default/lib/Lutim/I18N/es.po
OC=themes/default/lib/Lutim/I18N/oc.po
XGETTEXT=carton exec local/bin/xgettext.pl
CARTON=carton exec
LUTIM=script/lutim
REAL_LUTIM=script/application

locales:
	$(XGETTEXT) $(EXTRACTDIR) -o $(EN) 2>/dev/null
	$(XGETTEXT) $(EXTRACTDIR) -o $(FR) 2>/dev/null
	$(XGETTEXT) $(EXTRACTDIR) -o $(DE) 2>/dev/null
	$(XGETTEXT) $(EXTRACTDIR) -o $(ES) 2>/dev/null
	$(XGETTEXT) $(EXTRACTDIR) -o $(OC) 2>/dev/null

podcheck:
	podchecker lib/Lutim/DB/Image.pm

test-sqlite:
	MOJO_CONFIG=t/sqlite.conf $(CARTON) $(REAL_LUTIM) test

test-pg:
	MOJO_CONFIG=t/postgresql.conf $(CARTON) $(REAL_LUTIM) test

test: podcheck test-sqlite test-pg

clean:
	rm -rf lutim.db files/

rmassets:
	rm -rf themes/default/public/packed/*

dev: rmassets
	$(CARTON) morbo $(LUTIM) --listen http://0.0.0.0:3000 --watch lib/ --watch script/ --watch themes/ --watch lutim.conf

devlog:
	multitail log/development.log

prod: rmassets
	$(CARTON) hypnotoad -f $(LUTIM)

prodlog:
	multitail log/production.log

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

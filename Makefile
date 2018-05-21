EXTRACTDIR=-D lib -D themes/default/templates
POT=themes/default/lib/Lutim/I18N/lutim.pot
XGETTEXT=carton exec local/bin/xgettext.pl -u
CARTON=carton exec
LUTIM=script/lutim
REAL_LUTIM=script/application

minify:
	@echo "CSS concatenation"
	@cd ./themes/default/public/css/ && cat bootstrap.min.css fontello.css hennypenny.css lutim.css toastify.css | csso > common.min.css
	@cd ./themes/default/public/css/ && cat animation.css uploader.css markdown.css                              | csso > not_stats.min.css
	@cd ./themes/default/public/css/ && cat photoswipe.css default-skin/default-skin.css                         | csso > gallery.min.css
	@cd ./themes/default/public/css/ && cat twitter.css                                                          | csso > twitter.min.css

locales:
	$(XGETTEXT) $(EXTRACTDIR) -o $(POT) 2>/dev/null

push-locales:
	zanata-cli -q -B push

pull-locales:
	zanata-cli -q -B pull

stats-locales:
	zanata-cli -q stats

podcheck:
	podchecker lib/Lutim/DB/Image.pm

cover:
	PERL5OPT='-Ilib/' HARNESS_PERL_SWITCHES='-MDevel::Cover' $(CARTON) cover --ignore_re '^local'

test-sqlite:
	@MOJO_CONFIG=t/sqlite1.conf PERL5OPT='-Ilib/' HARNESS_PERL_SWITCHES='-MDevel::Cover' $(CARTON) $(REAL_LUTIM) test

test: podcheck test-sqlite

clean:
	rm -rf lutim.db files/

dev: minify
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

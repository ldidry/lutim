EXTRACTDIR=-D lib -D themes/default/templates
POT=themes/default/lib/Lutim/I18N/lutim.pot
ENPO=themes/default/lib/Lutim/I18N/en.po
XGETTEXT=carton exec local/bin/xgettext.pl -u
CARTON=carton exec
LUTIM=script/lutim
REAL_LUTIM=script/application
HARNESS_PERL_SWITCHES=-MDevel::Cover=+ignore,local
HEAD := $(shell git rev-parse --abbrev-ref HEAD)

minify:
	@echo "CSS concatenation"
	@cd ./themes/default/public/css/ && cat bootstrap.min.css fontello.css hennypenny.css lutim.css toastify.css | csso > common.min.css
	@cd ./themes/default/public/css/ && cat animation.css uploader.css markdown.css                              | csso > not_stats.min.css
	@cd ./themes/default/public/css/ && cat photoswipe.css default-skin/default-skin.css                         | csso > gallery.min.css
	@cd ./themes/default/public/css/ && cat twitter.css                                                          | csso > twitter.min.css

locales:
	$(XGETTEXT) $(EXTRACTDIR) -o $(POT) 2>/dev/null
	$(XGETTEXT) $(EXTRACTDIR) -o $(ENPO) 2>/dev/null

stats-locales:
	wlc stats

podcheck:
	podchecker lib/Lutim/DB/Image.pm

check-syntax:
	find lib/ themes/ -name \*.pm -exec $(CARTON) perl -Ilib -c {} \;
	find t/ -name \*.t -exec $(CARTON) perl -Ilib -c {} \;

cover:
	PERL5OPT='-Ilib' $(CARTON) cover --ignore_re '^local'

test:
	@PERL5OPT='-Ilib/' HARNESS_PERL_SWITCHES='$(HARNESS_PERL_SWITCHES)' $(CARTON) -- prove -l --failures

test-junit-output:
	@PERL5OPT='-Ilib/' HARNESS_PERL_SWITCHES='$(HARNESS_PERL_SWITCHES)' $(CARTON) -- prove -l --failures --formatter TAP::Formatter::JUnit > tap.xml

full-test: podcheck just-test

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

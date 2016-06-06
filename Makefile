EXTRACTFILES=utilities/locales_files.txt
EN=lib/Lutim/I18N/en.po
XGETTEXT=carton exec local/bin/xgettext.pl
CARTON=carton exec
LUTIM=script/lutim

locales:
	$(XGETTEXT) -W -f $(EXTRACTFILES) -o $(EN)
	tx push -s

dev:
	rm public/packed/*
	$(CARTON) morbo $(LUTIM) --listen http://0.0.0.0:3000

devlog:
	multitail log/development.log

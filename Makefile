EXTRACTFILES=utilities/locales_files.txt
EN=lib/Lutim/I18N/en.po
FR=lib/Lutim/I18N/fr.po
DE=lib/Lutim/I18N/de.po
ES=lib/Lutim/I18N/es.po
XGETTEXT=carton exec local/bin/xgettext.pl
CARTON=carton exec
LUTIM=script/lutim

locales:
	$(XGETTEXT) -W -f $(EXTRACTFILES) -o $(EN) 2>/dev/null
	$(XGETTEXT) -W -f $(EXTRACTFILES) -o $(FR) 2>/dev/null
	$(XGETTEXT) -W -f $(EXTRACTFILES) -o $(DE) 2>/dev/null
	$(XGETTEXT) -W -f $(EXTRACTFILES) -o $(ES) 2>/dev/null

dev:
	rm public/packed/*
	$(CARTON) morbo $(LUTIM) --listen http://0.0.0.0:3000

devlog:
	multitail log/development.log

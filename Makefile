EXTRACTFILES=utilities/locales_files.txt
EN=themes/default/lib/Lutim/I18N/en.po
FR=themes/default/lib/Lutim/I18N/fr.po
DE=themes/default/lib/Lutim/I18N/de.po
ES=themes/default/lib/Lutim/I18N/es.po
XGETTEXT=carton exec local/bin/xgettext.pl
CARTON=carton exec
LUTIM=script/lutim

locales:
	$(XGETTEXT) -W -f $(EXTRACTFILES) -o $(EN) 2>/dev/null
	$(XGETTEXT) -W -f $(EXTRACTFILES) -o $(FR) 2>/dev/null
	$(XGETTEXT) -W -f $(EXTRACTFILES) -o $(DE) 2>/dev/null
	$(XGETTEXT) -W -f $(EXTRACTFILES) -o $(ES) 2>/dev/null

clean:
	rm -rf lutim.db files/
dev:
	rm -rf themes/default/public/packed/*
	$(CARTON) morbo $(LUTIM) --listen http://0.0.0.0:3000 --watch lib/ --watch script/ --watch themes/ --watch lutim.conf

devlog:
	multitail log/development.log

EXTRACTDIR=-D lib -D themes/default/templates
EN=themes/default/lib/Lutim/I18N/en.po
FR=themes/default/lib/Lutim/I18N/fr.po
DE=themes/default/lib/Lutim/I18N/de.po
ES=themes/default/lib/Lutim/I18N/es.po
OC=themes/default/lib/Lutim/I18N/oc.po
XGETTEXT=carton exec local/bin/xgettext.pl
CARTON=carton exec
LUTIM=script/lutim

locales:
	$(XGETTEXT) $(EXTRACTDIR) -o $(EN) 2>/dev/null
	$(XGETTEXT) $(EXTRACTDIR) -o $(FR) 2>/dev/null
	$(XGETTEXT) $(EXTRACTDIR) -o $(DE) 2>/dev/null
	$(XGETTEXT) $(EXTRACTDIR) -o $(ES) 2>/dev/null
	$(XGETTEXT) $(EXTRACTDIR) -o $(OC) 2>/dev/null

clean:
	rm -rf lutim.db files/

dev:
	rm -rf themes/default/public/packed/*
	$(CARTON) morbo $(LUTIM) --listen http://0.0.0.0:3000 --watch lib/ --watch script/ --watch themes/ --watch lutim.conf

devlog:
	multitail log/development.log

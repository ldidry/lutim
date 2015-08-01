EXTRACTFILES=utilities/locales_files.txt
EN=lib/Lutim/I18N/en.po
XGETTEXT=carton exec local/bin/xgettext.pl
CARTON=carton exec
LUTIM=script/lutim

locales:
	$(XGETTEXT) -f $(EXTRACTFILES) -o $(EN)
	tx push -s

dev:
	$(CARTON) morbo $(LUTIM) --listen http://0.0.0.0:3000

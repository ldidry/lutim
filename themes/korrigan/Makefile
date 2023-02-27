EN=lib/Lutim/I18N/en.po
FR=lib/Lutim/I18N/fr.po
DE=lib/Lutim/I18N/de.po
ES=lib/Lutim/I18N/es.po
OC=lib/Lutim/I18N/oc.po
AR=lib/Lutim/I18N/ar.po
SEDOPTS=-e "s@SOME DESCRIPTIVE TITLE@Lutim language file@" \
		-e "s@YEAR THE PACKAGE'S COPYRIGHT HOLDER@2015 Luc Didry@" \
		-e "s@CHARSET@utf8@" \
		-e "s@the PACKAGE package@the Lutim package@" \
		-e '/^\#\. (/{N;/\n\#\. (/{N;/\n.*\.\.\/default\//{s/\#\..*\n.*\#\./\#. (/g}}}' \
		-e '/^\#\. (/{N;/\n.*\.\.\/default\//{s/\n/ /}}' 
SEDOPTS2=-e '/^\#.*\.\.\/default\//,+3d'
XGETTEXT=carton exec ../../local/bin/xgettext.pl
CARTON=carton exec

locales:
		$(XGETTEXT) -D templates -D ../default/templates -o $(EN) 2>/dev/null
		$(XGETTEXT) -D templates -D ../default/templates -o $(FR) 2>/dev/null
		$(XGETTEXT) -D templates -D ../default/templates -o $(DE) 2>/dev/null
		$(XGETTEXT) -D templates -D ../default/templates -o $(ES) 2>/dev/null
		$(XGETTEXT) -D templates -D ../default/templates -o $(OC) 2>/dev/null
		$(XGETTEXT) -D templates -D ../default/templates -o $(AR) 2>/dev/null
		sed $(SEDOPTS) -i $(EN)
		sed $(SEDOPTS2) -i $(EN)
		sed $(SEDOPTS) -i $(FR)
		sed $(SEDOPTS2) -i $(FR)
		sed $(SEDOPTS) -i $(DE)
		sed $(SEDOPTS2) -i $(DE)
		sed $(SEDOPTS) -i $(ES)
		sed $(SEDOPTS2) -i $(ES)
		sed $(SEDOPTS) -i $(OC)
		sed $(SEDOPTS) -i $(OC)
		sed $(SEDOPTS2) -i $(AR)
		sed $(SEDOPTS2) -i $(AR)
